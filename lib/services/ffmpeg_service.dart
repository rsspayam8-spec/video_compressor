import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';
import '../models/compress_models.dart';

/// وضعیت لحظه‌ای پردازش
class CompressProgress {
  final double percent; // 0..100
  final Duration processed;
  final Duration elapsed;
  final Duration? remaining;
  final double speed;
  final String phase;

  const CompressProgress({
    required this.percent,
    required this.processed,
    required this.elapsed,
    this.remaining,
    this.speed = 0,
    this.phase = '',
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
  bool _userCancelled = false;

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
          if (r != null) {
            rotation = (double.tryParse(r.toString()) ?? 0).abs().round();
          }
        }
      } else if (type == 'audio') {
        hasAudio = true;
        audioBitrate = int.tryParse(stream.getBitrate() ?? '0') ?? 0;
      }
    }

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
  // تصویر بندانگشتی
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
  // ساخت آرگومان‌ها
  // ---------------------------------------------------------------------
  List<String> buildArguments({
    required MediaInfo info,
    required CompressOptions options,
    required String outputPath,
    int pass = 0, // 0=تک‌پاس، 1 و 2 = دوپاس
    String? passLogFile,
    int? overrideBitrateKbps,
  }) {
    final dims = Dimensions.compute(info, options.effectiveShortSide);
    final args = <String>['-y', '-i', info.path];

    // --- فیلترها ---
    final filters = <String>[];
    if (dims.width != info.width || dims.height != info.height) {
      filters.add('scale=${dims.width}:${dims.height}:flags=lanczos');
    }
    final fps = options.effectiveFps(info);
    if (fps != null && fps > 0 && fps < info.frameRate) {
      filters.add('fps=${fps.toStringAsFixed(3)}');
    }
    if (filters.isNotEmpty) args.addAll(['-vf', filters.join(',')]);

    // --- کدک ویدئو ---
    final isH265 = options.codec == VideoCodec.h265;
    args.addAll(['-c:v', options.codec.ffmpegName]);
    args.addAll(['-preset', options.speed.preset]);

    if (options.isBitrateMode) {
      final kbps = overrideBitrateKbps ?? options.videoBitrateKbps(info);
      args.addAll(['-b:v', '${kbps}k']);
      // سقف نرم برای جلوگیری از انفجار حجم در صحنه‌های شلوغ
      args.addAll([
        '-maxrate', '${(kbps * 1.5).round()}k',
        '-bufsize', '${(kbps * 2).round()}k',
      ]);
      if (pass > 0 && !isH265) {
        args.addAll(['-pass', '$pass']);
        if (passLogFile != null) args.addAll(['-passlogfile', passLogFile]);
      }
    } else {
      // حالت CRF — بهترین کیفیت به ازای هر بایت
      final crf = isH265 ? (options.crf + 3).clamp(18, 45) : options.crf;
      args.addAll(['-crf', '$crf']);
    }

    if (isH265) {
      args.addAll(['-tag:v', 'hvc1']);
      args.addAll(['-x265-params', 'log-level=error']);
    } else {
      args.addAll(['-profile:v', 'high', '-level', '4.1']);
    }
    args.addAll(['-pix_fmt', 'yuv420p']);
    args.addAll(['-g', '${(info.frameRate * 2).round().clamp(24, 300)}']);

    // --- صدا ---
    final noAudio = options.removeAudio || !info.hasAudio || pass == 1;
    if (noAudio) {
      args.add('-an');
    } else {
      final kbps = options.audioKbps;
      args.addAll(['-c:a', 'aac', '-b:a', '${kbps}k']);
      // زیر ۶۴ کیلوبیت، مونو کیفیت بهتری می‌دهد
      args.addAll(['-ac', kbps < 64 ? '1' : '2']);
    }

    // --- خروجی ---
    args.addAll(['-map_metadata', '0']);
    if (options.format == OutputFormat.mp4 ||
        options.format == OutputFormat.mov) {
      args.addAll(['-movflags', '+faststart']);
    }
    args.addAll(['-threads', '0']);

    if (pass == 1) {
      args.addAll(['-f', 'mp4', '/dev/null']);
    } else {
      args.add(outputPath);
    }
    return args;
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
    _userCancelled = false;
    final stopwatch = Stopwatch()..start();
    final totalMs = info.durationSeconds * 1000;

    void emit(int processedMs,
        {double phaseStart = 0, double phaseWeight = 1, String phase = ''}) {
      final double raw =
          totalMs <= 0 ? 0.0 : (processedMs / totalMs).clamp(0.0, 1.0).toDouble();
      final double percent =
          ((phaseStart + raw * phaseWeight) * 100).clamp(0.0, 99.9).toDouble();
      final elapsed = stopwatch.elapsed;
      Duration? remaining;
      if (percent > 2) {
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
        phase: phase,
      ));
    }

    try {
      // ---------- حالت حجم دلخواه: دوپاس واقعی ----------
      final useTwoPass = options.preset.kind == PresetKind.targetSize &&
          options.codec == VideoCodec.h264;

      if (useTwoPass) {
        final tmpDir = await getTemporaryDirectory();
        final logFile =
            '${tmpDir.path}/vcpass_${DateTime.now().millisecondsSinceEpoch}';
        final kbps = options.videoBitrateKbps(info);

        final p1 = await _run(
          buildArguments(
            info: info,
            options: options,
            outputPath: outputPath,
            pass: 1,
            passLogFile: logFile,
            overrideBitrateKbps: kbps,
          ),
          (ms) => emit(ms,
              phaseStart: 0, phaseWeight: 0.4, phase: 'مرحله ۱ از ۲: تحلیل'),
        );
        if (p1 != _RunState.success) {
          _cleanupPassLogs(logFile);
          return _fail(p1, outputPath);
        }

        final p2 = await _run(
          buildArguments(
            info: info,
            options: options,
            outputPath: outputPath,
            pass: 2,
            passLogFile: logFile,
            overrideBitrateKbps: kbps,
          ),
          (ms) => emit(ms,
              phaseStart: 0.4, phaseWeight: 0.6, phase: 'مرحله ۲ از ۲: انکد'),
        );
        _cleanupPassLogs(logFile);
        if (p2 != _RunState.success) return _fail(p2, outputPath);

        return await _finish(outputPath);
      }

      // ---------- حالت عادی: تک‌پاس ----------
      final state = await _run(
        buildArguments(info: info, options: options, outputPath: outputPath),
        (ms) => emit(ms),
      );
      if (state != _RunState.success) return _fail(state, outputPath);
      return await _finish(outputPath);
    } catch (e) {
      return CompressResult(success: false, errorMessage: e.toString());
    } finally {
      stopwatch.stop();
      _activeSessionId = null;
    }
  }

  CompressResult _fail(_RunState state, String outputPath) {
    _safeDelete(outputPath);
    if (state == _RunState.cancelled || _userCancelled) {
      return const CompressResult(success: false, cancelled: true);
    }
    return const CompressResult(
      success: false,
      errorMessage:
          'پردازش ناموفق بود. اگر کدک H.265 انتخاب شده، H.264 را امتحان کنید.',
    );
  }

  Future<CompressResult> _finish(String outputPath) async {
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
        } else if (ReturnCode.isCancel(rc) || _userCancelled) {
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
    _userCancelled = true;
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
    for (final s in ['-0.log', '-0.log.mbtree', '.log', '.log.mbtree']) {
      _safeDelete('$base$s');
    }
  }

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
}

enum _RunState { success, failed, cancelled }
