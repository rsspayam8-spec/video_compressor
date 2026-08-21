import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';
import '../models/compress_models.dart';

/// وضعیت لحظه‌ای پردازش
class CompressProgress {
  final double percent; // 0..100
  final Duration processed;
  final Duration elapsed;
  final Duration? remaining;
  final double speed; // ضریب سرعت نسبت به زمان واقعی

  const CompressProgress({
    required this.percent,
    required this.processed,
    required this.elapsed,
    this.remaining,
    this.speed = 0,
  });
}

/// نتیجه پایانی
class CompressResult {
  final bool success;
  final bool cancelled;
  final String? outputPath;
  final int outputBytes;
  final String? errorMessage;

  const CompressResult({
    required this.success,
    this.cancelled = false,
    this.outputPath,
    this.outputBytes = 0,
    this.errorMessage,
  });
}

class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  int? _activeSessionId;

  // ---------------------------------------------------------------------
  // خواندن مشخصات ویدئو
  // ---------------------------------------------------------------------
  Future<MediaInfo?> probe(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) return null;

    int width = 0, height = 0, rotation = 0;
    double fps = 30;
    bool hasAudio = false;
    int audioBitrate = 0;

    for (final stream in info.getStreams()) {
      final type = stream.getType();
      if (type == 'video' && width == 0) {
        width = stream.getWidth() ?? 0;
        height = stream.getHeight() ?? 0;
        fps = _parseFrameRate(
            stream.getAverageFrameRate() ?? stream.getRealFrameRate());
        final props = stream.getAllProperties();
        final tags = props?['tags'];
        if (tags is Map && tags['rotate'] != null) {
          rotation = int.tryParse(tags['rotate'].toString()) ?? 0;
        }
        final sideData = props?['side_data_list'];
        if (sideData is List && sideData.isNotEmpty) {
          final r = sideData.first['rotation'];
          if (r != null) rotation = (double.tryParse(r.toString()) ?? 0).abs().round();
        }
      } else if (type == 'audio') {
        hasAudio = true;
        audioBitrate = int.tryParse(stream.getBitrate() ?? '0') ?? 0;
      }
    }

    // اگر ویدئو چرخیده باشد، عرض و ارتفاع جابه‌جا می‌شوند
    if (rotation == 90 || rotation == 270) {
      final tmp = width;
      width = height;
      height = tmp;
    }

    final duration = double.tryParse(info.getDuration() ?? '0') ?? 0;
    final sizeBytes = await file.length();
    final bitrate = int.tryParse(info.getBitrate() ?? '0') ??
        (duration > 0 ? (sizeBytes * 8 / duration).round() : 0);

    if (width == 0 || height == 0 || duration <= 0) return null;

    return MediaInfo(
      path: path,
      fileName: path.split(Platform.pathSeparator).last,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      durationSeconds: duration,
      frameRate: fps,
      bitrate: bitrate,
      hasAudio: hasAudio,
      audioBitrate: audioBitrate,
    );
  }

  double _parseFrameRate(String? raw) {
    if (raw == null || raw.isEmpty) return 30;
    if (raw.contains('/')) {
      final parts = raw.split('/');
      final n = double.tryParse(parts[0]) ?? 30;
      final d = double.tryParse(parts[1]) ?? 1;
      if (d == 0) return 30;
      final v = n / d;
      return (v <= 0 || v > 240) ? 30 : v;
    }
    final v = double.tryParse(raw) ?? 30;
    return (v <= 0 || v > 240) ? 30 : v;
  }

  // ---------------------------------------------------------------------
  // تولید تصویر بندانگشتی
  // ---------------------------------------------------------------------
  Future<String?> generateThumbnail(MediaInfo info) async {
    try {
      final dir = await getTemporaryDirectory();
      final out =
          '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final seek = math.min(1.0, info.durationSeconds / 3);
      final args = <String>[
        '-y',
        '-ss', seek.toStringAsFixed(2),
        '-i', info.path,
        '-frames:v', '1',
        '-vf', 'scale=480:-2',
        '-q:v', '4',
        out,
      ];
      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc) && await File(out).exists()) return out;
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------
  // ساخت آرگومان‌های بهینه
  // ---------------------------------------------------------------------
  /// نکته کیفیت: از CRF استفاده می‌کنیم نه بیت‌ریت ثابت. CRF کیفیت را ثابت
  /// نگه می‌دارد و بیت‌ریت را روی صحنه‌های ساده پایین می‌آورد؛ نتیجه: حجم
  /// کمتر با کیفیت بصری بالاتر نسبت به بیت‌ریت ثابت.
  List<String> buildArguments({
    required MediaInfo info,
    required CompressOptions options,
    required String outputPath,
    int pass = 0, // 0 = تک‌پاس، 1 و 2 = دوپاس (برای حجم دلخواه)
    String? passLogFile,
    int? targetVideoBitrateKbps,
  }) {
    final dims = Dimensions.compute(info, options.effectiveShortSide);
    final args = <String>['-y', '-i', info.path];

    // --- فیلترها ---
    final filters = <String>[];
    if (dims.width != info.width || dims.height != info.height) {
      filters.add('scale=${dims.width}:${dims.height}:flags=lanczos');
    }
    final targetFps = options.customFps;
    if (targetFps != null && targetFps > 0 && targetFps < info.frameRate) {
      filters.add('fps=${targetFps.toStringAsFixed(3)}');
    }
    if (filters.isNotEmpty) {
      args.addAll(['-vf', filters.join(',')]);
    }

    // --- کدک ویدئو ---
    final isWebm = options.format == OutputFormat.webm;
    final codecName = isWebm ? 'libvpx-vp9' : options.codec.ffmpegName;
    args.addAll(['-c:v', codecName]);

    if (isWebm) {
      args.addAll(['-b:v', '0', '-crf', '${options.effectiveCrf + 6}']);
      args.addAll(['-row-mt', '1', '-deadline', 'good', '-cpu-used', '2']);
    } else {
      args.addAll(['-preset', options.speed.preset]);

      if (targetVideoBitrateKbps != null) {
        // حالت حجم دلخواه: بیت‌ریت هدف با سقف کنترل‌شده
        args.addAll([
          '-b:v', '${targetVideoBitrateKbps}k',
          '-maxrate', '${(targetVideoBitrateKbps * 1.45).round()}k',
          '-bufsize', '${(targetVideoBitrateKbps * 2.4).round()}k',
        ]);
        if (pass > 0) {
          args.addAll(['-pass', '$pass']);
          if (passLogFile != null) args.addAll(['-passlogfile', passLogFile]);
        }
      } else {
        args.addAll(['-crf', '${_crfForCodec(options)}']);
      }

      // تنظیمات کیفیت/سازگاری
      if (options.codec == VideoCodec.h265) {
        args.addAll(['-tag:v', 'hvc1']);
        args.addAll(['-x265-params', 'log-level=error']);
      } else {
        // profile سازگار با گوشی‌های قدیمی
        args.addAll(['-profile:v', 'high', '-level', '4.1']);
      }
      args.addAll(['-pix_fmt', 'yuv420p']);
      // فاصله کی‌فریم منطقی برای seek روان
      args.addAll(['-g', '${(info.frameRate * 2).round().clamp(24, 300)}']);
    }

    // --- صدا ---
    if (options.removeAudio || !info.hasAudio) {
      args.add('-an');
    } else if (pass == 1) {
      args.add('-an'); // پاس اول نیازی به صدا ندارد
    } else {
      if (isWebm) {
        args.addAll(['-c:a', 'libopus', '-b:a', '${options.audioKbps}k']);
      } else if (options.format == OutputFormat.avi) {
        args.addAll(['-c:a', 'libmp3lame', '-b:a', '${options.audioKbps}k']);
      } else {
        args.addAll([
          '-c:a', 'aac',
          '-b:a', '${options.audioKbps}k',
          '-ac', '2',
        ]);
      }
    }

    // --- خروجی ---
    args.addAll(['-map_metadata', '0']);
    if (options.format == OutputFormat.mp4 ||
        options.format == OutputFormat.mov) {
      args.addAll(['-movflags', '+faststart']);
    }
    args.addAll(['-threads', '0']);

    if (pass == 1) {
      args.addAll(['-f', 'null', Platform.isWindows ? 'NUL' : '/dev/null']);
    } else {
      args.add(outputPath);
    }
    return args;
  }

  /// H.265 در CRF یکسان کیفیت بیشتری می‌دهد؛ برای رسیدن به کیفیت مشابه
  /// با حجم کمتر، CRF را کمی بالاتر می‌بریم.
  int _crfForCodec(CompressOptions options) {
    if (options.codec == VideoCodec.h265) {
      return (options.effectiveCrf + 4).clamp(18, 40);
    }
    return options.effectiveCrf.clamp(16, 40);
  }

  // ---------------------------------------------------------------------
  // اجرای فشرده‌سازی
  // ---------------------------------------------------------------------
  Future<CompressResult> compress({
    required MediaInfo info,
    required CompressOptions options,
    required String outputPath,
    required void Function(CompressProgress) onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final totalMs = info.durationSeconds * 1000;

    void emit(int processedMs, {double phaseStart = 0, double phaseWeight = 1}) {
      final double raw =
          totalMs <= 0 ? 0.0 : (processedMs / totalMs).clamp(0.0, 1.0).toDouble();
      final double percent =
          ((phaseStart + raw * phaseWeight) * 100).clamp(0.0, 99.9).toDouble();
      final elapsed = stopwatch.elapsed;
      Duration? remaining;
      if (percent > 1) {
        final total = elapsed.inMilliseconds * 100 / percent;
        remaining =
            Duration(milliseconds: (total - elapsed.inMilliseconds).round());
      }
      final speed = elapsed.inMilliseconds > 0
          ? processedMs / elapsed.inMilliseconds
          : 0.0;
      onProgress(CompressProgress(
        percent: percent,
        processed: Duration(milliseconds: processedMs),
        elapsed: elapsed,
        remaining: remaining,
        speed: speed,
      ));
    }

    try {
      // حالت حجم دلخواه => دوپاس برای دقت بالا
      if (options.preset.kind == PresetKind.targetSize &&
          options.format != OutputFormat.webm) {
        final tmpDir = await getTemporaryDirectory();
        final logFile = '${tmpDir.path}/vc_pass_${DateTime.now().millisecondsSinceEpoch}';

        final audioKbps =
            (options.removeAudio || !info.hasAudio) ? 0 : options.audioKbps;
        final targetBits = options.targetSizeMb * 1024 * 1024 * 8;
        var videoKbps =
            (targetBits / info.durationSeconds / 1000 - audioKbps) * 0.97;
        videoKbps = videoKbps.clamp(80.0, 40000.0);

        final pass1 = await _run(
          buildArguments(
            info: info,
            options: options,
            outputPath: outputPath,
            pass: 1,
            passLogFile: logFile,
            targetVideoBitrateKbps: videoKbps.round(),
          ),
          (ms) => emit(ms, phaseStart: 0, phaseWeight: 0.35),
        );
        if (pass1 == _RunState.cancelled) {
          return const CompressResult(success: false, cancelled: true);
        }
        if (pass1 == _RunState.failed) {
          return const CompressResult(
              success: false, errorMessage: 'خطا در مرحله اول پردازش');
        }

        final pass2 = await _run(
          buildArguments(
            info: info,
            options: options,
            outputPath: outputPath,
            pass: 2,
            passLogFile: logFile,
            targetVideoBitrateKbps: videoKbps.round(),
          ),
          (ms) => emit(ms, phaseStart: 0.35, phaseWeight: 0.65),
        );
        _cleanupPassLogs(logFile);
        return await _finish(pass2, outputPath);
      }

      // حالت عادی: تک‌پاس CRF
      final state = await _run(
        buildArguments(
          info: info,
          options: options,
          outputPath: outputPath,
        ),
        (ms) => emit(ms),
      );
      return await _finish(state, outputPath);
    } catch (e) {
      return CompressResult(success: false, errorMessage: e.toString());
    } finally {
      stopwatch.stop();
      _activeSessionId = null;
    }
  }

  Future<CompressResult> _finish(_RunState state, String outputPath) async {
    if (state == _RunState.cancelled) {
      _safeDelete(outputPath);
      return const CompressResult(success: false, cancelled: true);
    }
    if (state == _RunState.failed) {
      _safeDelete(outputPath);
      return const CompressResult(
        success: false,
        errorMessage: 'پردازش ناموفق بود. لطفاً فرمت یا کدک دیگری را امتحان کنید.',
      );
    }
    final file = File(outputPath);
    if (!await file.exists()) {
      return const CompressResult(
          success: false, errorMessage: 'فایل خروجی ساخته نشد');
    }
    return CompressResult(
      success: true,
      outputPath: outputPath,
      outputBytes: await file.length(),
    );
  }

  Future<_RunState> _run(
    List<String> args,
    void Function(int processedMs) onTime,
  ) async {
    final completer = Completer<_RunState>();

    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          completer.complete(_RunState.success);
        } else if (ReturnCode.isCancel(rc)) {
          completer.complete(_RunState.cancelled);
        } else {
          completer.complete(_RunState.failed);
        }
      },
      (log) {},
      (stats) {
        final num t = stats.getTime() ?? 0;
        if (t > 0) onTime(t.round());
      },
    );

    _activeSessionId = session.getSessionId();
    return completer.future;
  }

  Future<void> cancel() async {
    final id = _activeSessionId;
    if (id != null) {
      await FFmpegKit.cancel(id);
    } else {
      await FFmpegKit.cancel();
    }
  }

  void _safeDelete(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _cleanupPassLogs(String base) {
    for (final suffix in ['-0.log', '-0.log.mbtree', '.log', '.log.mbtree']) {
      _safeDelete('$base$suffix');
    }
  }

  /// مسیر پوشه خروجی داخل حافظه برنامه
  Future<Directory> outputDirectory() async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Compressed');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> buildOutputPath(MediaInfo info, CompressOptions options) async {
    final dir = await outputDirectory();
    final baseName = options.outputName.trim().isEmpty
        ? Fmt.safeName(info.fileName)
        : Fmt.safeName(options.outputName);
    var candidate = '${dir.path}/${baseName}_compressed.${options.format.ext}';
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate =
          '${dir.path}/${baseName}_compressed($counter).${options.format.ext}';
      counter++;
    }
    return candidate;
  }

  Future<void> enableStatistics() async {
    await FFmpegKitConfig.enableRedirection();
  }
}

enum _RunState { success, failed, cancelled }
