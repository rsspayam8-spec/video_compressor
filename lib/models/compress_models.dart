import 'dart:math' as math;

/// اطلاعات ویدئوی ورودی که با FFprobe خوانده می‌شود
class MediaInfo {
  final String path;
  final String fileName;
  final int sizeBytes;
  final int width;
  final int height;
  final double durationSeconds;
  final double frameRate;
  final int bitrate; // bits per second
  final bool hasAudio;
  final int audioBitrate;

  const MediaInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.frameRate,
    required this.bitrate,
    required this.hasAudio,
    required this.audioBitrate,
  });

  int get shortSide => math.min(width, height);
  int get longSide => math.max(width, height);
  bool get isPortrait => height > width;
  Duration get duration =>
      Duration(milliseconds: (durationSeconds * 1000).round());

  String get resolutionLabel => '$width×$height';

  /// بیت‌ریت منبع به کیلوبیت — اگر ناشناخته باشد از حجم و مدت حساب می‌شود
  double get sourceKbps {
    if (bitrate > 0) return bitrate / 1000;
    if (durationSeconds > 0) return sizeBytes * 8 / durationSeconds / 1000;
    return 4000;
  }
}

/// کدک ویدئو — انکودر نرم‌افزاری x264/x265
/// (کیفیت بسیار بهتر از انکودر سخت‌افزاری در بیت‌ریت پایین، و مهم‌تر:
/// بیت‌ریت درخواستی را دقیق رعایت می‌کند)
enum VideoCodec {
  h264('H.264', 'سازگار با همه دستگاه‌ها', 'libx264'),
  h265('H.265 / HEVC', 'حدود ۳۰٪ حجم کمتر، سازگاری کمتر', 'libx265');

  const VideoCodec(this.label, this.hint, this.ffmpegName);
  final String label;
  final String hint;
  final String ffmpegName;
}

/// فرمت خروجی
enum OutputFormat {
  mp4('MP4', 'mp4'),
  mkv('MKV', 'mkv'),
  mov('MOV', 'mov');

  const OutputFormat(this.label, this.ext);
  final String label;
  final String ext;
}

/// سرعت انکد — تعادل بین زمان پردازش و حجم خروجی
enum EncodeSpeed {
  slow('کیفیت بیشتر', 'کندتر، حجم کمتر', 'slow', 0.92),
  medium('متعادل', 'پیشنهاد ما', 'medium', 1.0),
  fast('سریع', 'زمان کمتر', 'faster', 1.10),
  veryfast('خیلی سریع', 'کمترین انتظار', 'veryfast', 1.22);

  const EncodeSpeed(this.label, this.hint, this.preset, this.sizeFactor);
  final String label;
  final String hint;
  final String preset;
  final double sizeFactor;
}

/// نوع پریست فشرده‌سازی
enum PresetKind { quality, recommended, small, tiny, targetSize, custom }

/// یک پریست آماده — بر پایه CRF (کیفیت ثابت) که در هر بیت مصرفی،
/// کیفیت بصری بیشتری نسبت به بیت‌ریت ثابت می‌دهد
class CompressPreset {
  final PresetKind kind;
  final String title;
  final String subtitle;
  final int? maxShortSide;
  final int crf;
  final int audioBitrateKbps;
  final double? maxFps;

  const CompressPreset({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.maxShortSide,
    required this.crf,
    this.audioBitrateKbps = 96,
    this.maxFps,
  });

  static const List<CompressPreset> all = [
    CompressPreset(
      kind: PresetKind.quality,
      title: 'کیفیت اصلی',
      subtitle: 'رزولوشن دست‌نخورده، افت کیفیت نامحسوس',
      maxShortSide: null,
      crf: 23,
      audioBitrateKbps: 128,
    ),
    CompressPreset(
      kind: PresetKind.recommended,
      title: 'پیشنهادی',
      subtitle: 'بهترین تعادل — برای تلگرام و واتساپ',
      maxShortSide: 720,
      crf: 27,
      audioBitrateKbps: 96,
    ),
    CompressPreset(
      kind: PresetKind.small,
      title: 'حجم کم',
      subtitle: 'کاهش چشمگیر حجم با کیفیت قابل قبول',
      maxShortSide: 480,
      crf: 31,
      audioBitrateKbps: 64,
    ),
    CompressPreset(
      kind: PresetKind.tiny,
      title: 'خیلی کم‌حجم',
      subtitle: 'کمترین حجم ممکن — مناسب اینترنت ضعیف',
      maxShortSide: 360,
      crf: 35,
      audioBitrateKbps: 32,
      maxFps: 24,
    ),
    CompressPreset(
      kind: PresetKind.targetSize,
      title: 'حجم دلخواه',
      subtitle: 'حجم خروجی را دقیق تعیین کنید (دوپاس)',
      maxShortSide: null,
      crf: 27,
      audioBitrateKbps: 64,
    ),
    CompressPreset(
      kind: PresetKind.custom,
      title: 'تنظیمات پیشرفته',
      subtitle: 'رزولوشن، بیت‌ریت و فریم‌ریت دلخواه',
      maxShortSide: null,
      crf: 27,
      audioBitrateKbps: 64,
    ),
  ];
}

/// تنظیمات نهایی فشرده‌سازی
class CompressOptions {
  final CompressPreset preset;
  final VideoCodec codec;
  final OutputFormat format;
  final EncodeSpeed speed;
  final bool removeAudio;

  /// حالت «حجم دلخواه» (مگابایت)
  final double targetSizeMb;

  /// حالت «تنظیمات پیشرفته»
  final int? customShortSide;
  final int? customBitrateKbps;
  final double? customFps;
  final int? customAudioKbps;

  final String outputName;

  const CompressOptions({
    required this.preset,
    this.codec = VideoCodec.h264,
    this.format = OutputFormat.mp4,
    this.speed = EncodeSpeed.medium,
    this.removeAudio = false,
    this.targetSizeMb = 10,
    this.customShortSide,
    this.customBitrateKbps,
    this.customFps,
    this.customAudioKbps,
    this.outputName = '',
  });

  CompressOptions copyWith({
    CompressPreset? preset,
    VideoCodec? codec,
    OutputFormat? format,
    EncodeSpeed? speed,
    bool? removeAudio,
    double? targetSizeMb,
    int? customShortSide,
    int? customBitrateKbps,
    double? customFps,
    int? customAudioKbps,
    String? outputName,
  }) {
    return CompressOptions(
      preset: preset ?? this.preset,
      codec: codec ?? this.codec,
      format: format ?? this.format,
      speed: speed ?? this.speed,
      removeAudio: removeAudio ?? this.removeAudio,
      targetSizeMb: targetSizeMb ?? this.targetSizeMb,
      customShortSide: customShortSide ?? this.customShortSide,
      customBitrateKbps: customBitrateKbps ?? this.customBitrateKbps,
      customFps: customFps ?? this.customFps,
      customAudioKbps: customAudioKbps ?? this.customAudioKbps,
      outputName: outputName ?? this.outputName,
    );
  }

  bool get isBitrateMode =>
      preset.kind == PresetKind.custom || preset.kind == PresetKind.targetSize;

  int? get effectiveShortSide {
    if (preset.kind == PresetKind.custom) return customShortSide;
    return preset.maxShortSide;
  }

  int get audioKbps {
    if (removeAudio) return 0;
    if (preset.kind == PresetKind.custom && customAudioKbps != null) {
      return customAudioKbps!;
    }
    return preset.audioBitrateKbps;
  }

  int get crf => preset.crf;

  double? effectiveFps(MediaInfo info) {
    if (preset.kind == PresetKind.custom) return customFps;
    final max = preset.maxFps;
    if (max != null && info.frameRate > max) return max;
    return null;
  }

  /// بیت‌ریت ویدئو برای حالت‌هایی که بیت‌ریت مستقیم استفاده می‌شود
  int videoBitrateKbps(MediaInfo info) {
    if (preset.kind == PresetKind.targetSize) {
      final audio = removeAudio || !info.hasAudio ? 0 : audioKbps;
      // ۱ مگابایت = 8,388,608 بیت. ضریب ۰٫۹۷ برای سربار کانتینر (moov atom و…)
      final totalKbps =
          (targetSizeMb * 8388.608 * 0.97) / math.max(info.durationSeconds, 1);
      return (totalKbps - audio).round().clamp(10, 60000);
    }
    return (customBitrateKbps ?? 1500).clamp(10, 60000);
  }
}

/// محاسبه ابعاد خروجی با حفظ نسبت تصویر و زوج بودن اعداد
class Dimensions {
  final int width;
  final int height;
  const Dimensions(this.width, this.height);

  static Dimensions compute(MediaInfo info, int? maxShortSide) {
    if (maxShortSide == null || info.shortSide <= maxShortSide) {
      return Dimensions(_even(info.width), _even(info.height));
    }
    final scale = maxShortSide / info.shortSide;
    return Dimensions(
      _even((info.width * scale).round()),
      _even((info.height * scale).round()),
    );
  }

  static int _even(int v) => v.isEven ? v : v + 1;

  int get pixels => width * height;

  @override
  String toString() => '$width×$height';
}

/// تخمین حجم خروجی
class SizeEstimator {
  /// حالت‌های بیت‌ریت‌محور: محاسبه دقیق. حالت CRF: مدل تخمینی.
  static int estimate(MediaInfo info, CompressOptions options) {
    if (options.preset.kind == PresetKind.targetSize) {
      // خروجی دقیقاً همان حجم درخواستی است (دوپاس)
      return (options.targetSizeMb * 1024 * 1024).round();
    }

    final audioKbps =
        options.removeAudio || !info.hasAudio ? 0 : options.audioKbps;

    final videoKbps = options.preset.kind == PresetKind.custom
        ? options.videoBitrateKbps(info).toDouble()
        : _crfBitrate(info, options);

    final totalBits = (videoKbps + audioKbps) * 1000 * info.durationSeconds;
    return (totalBits / 8).round();
  }

  /// تخمین بیت‌ریت حاصل از یک CRF مشخص.
  /// دو مدل مستقل حساب می‌شود و کمینه‌شان گرفته می‌شود:
  ///  ۱) نسبت به بیت‌ریت خودِ فایل منبع (دقیق‌تر برای ویدئوهای واقعی)
  ///  ۲) مدل بیت‌بر‌پیکسل (سقف منطقی برای منابع بیش‌ازحد فشرده یا خام)
  static double _crfBitrate(MediaInfo info, CompressOptions options) {
    final dims = Dimensions.compute(info, options.effectiveShortSide);
    final inPixels = math.max(info.width * info.height, 1).toDouble();
    final pixelRatio = dims.pixels / inPixels;

    final targetFps = options.effectiveFps(info) ?? info.frameRate;
    final fpsRatio =
        info.frameRate > 0 ? (targetFps / info.frameRate).clamp(0.3, 1.0) : 1.0;

    // هر ۶ واحد CRF ≈ نصف/دوبرابر شدن بیت‌ریت. منبع را معادل CRF 23 می‌گیریم.
    final crfFactor = math.pow(2, (23 - options.crf) / 6.0).toDouble();

    var fromSource = info.sourceKbps *
        math.pow(pixelRatio, 0.75).toDouble() *
        crfFactor *
        fpsRatio;

    final bpp = 0.055 * math.pow(2, (28 - options.crf) / 6.0).toDouble();
    final fromPixels = dims.pixels * targetFps * bpp / 1000;

    var result = math.min(fromSource, fromPixels * 1.5);
    result *= options.speed.sizeFactor;
    if (options.codec == VideoCodec.h265) result *= 0.7;

    return result.clamp(40.0, 60000.0);
  }
}
