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
}

/// کدک ویدئو
enum VideoCodec {
  h264('H.264 (x264)', 'سازگاری بالا با همه دستگاه‌ها', 'libx264'),
  h265('H.265 (HEVC)', 'حجم کمتر تا ۴۰٪، سازگاری کمتر', 'libx265');

  const VideoCodec(this.label, this.hint, this.ffmpegName);
  final String label;
  final String hint;
  final String ffmpegName;
}

/// فرمت خروجی
enum OutputFormat {
  mp4('MP4', 'mp4'),
  mkv('MKV', 'mkv'),
  mov('MOV', 'mov'),
  avi('AVI', 'avi'),
  webm('WEBM', 'webm');

  const OutputFormat(this.label, this.ext);
  final String label;
  final String ext;
}

/// سرعت انکد (تعادل بین سرعت و کیفیت/حجم)
enum EncodeSpeed {
  quality('کیفیت بیشتر', 'کندتر، حجم کمتر', 'slow', 1.0),
  balanced('متعادل', 'پیشنهاد ما', 'medium', 1.06),
  fast('سریع', 'سریع‌تر، حجم کمی بیشتر', 'faster', 1.15),
  fastest('خیلی سریع', 'کمترین زمان انتظار', 'veryfast', 1.28);

  const EncodeSpeed(this.label, this.hint, this.preset, this.sizeFactor);
  final String label;
  final String hint;
  final String preset;
  final double sizeFactor;
}

/// نوع پریست فشرده‌سازی
enum PresetKind { quality, recommended, small, tiny, targetSize, custom }

/// یک پریست آماده
class CompressPreset {
  final PresetKind kind;
  final String title;
  final String subtitle;
  final int? maxShortSide; // حداکثر ضلع کوچک (مثلاً ۷۲۰) — null یعنی رزولوشن اصلی
  final int crf; // کیفیت (کمتر = بهتر)
  final int audioBitrateKbps;

  const CompressPreset({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.maxShortSide,
    required this.crf,
    this.audioBitrateKbps = 128,
  });

  static const List<CompressPreset> all = [
    CompressPreset(
      kind: PresetKind.quality,
      title: 'کیفیت اصلی',
      subtitle: 'رزولوشن دست‌نخورده، کاهش حجم ملایم',
      maxShortSide: null,
      crf: 20,
      audioBitrateKbps: 160,
    ),
    CompressPreset(
      kind: PresetKind.recommended,
      title: 'پیشنهادی',
      subtitle: 'بهترین تعادل کیفیت و حجم — برای تلگرام و واتساپ',
      maxShortSide: 720,
      crf: 24,
      audioBitrateKbps: 128,
    ),
    CompressPreset(
      kind: PresetKind.small,
      title: 'حجم کم',
      subtitle: 'کاهش زیاد حجم با کیفیت قابل قبول',
      maxShortSide: 540,
      crf: 27,
      audioBitrateKbps: 96,
    ),
    CompressPreset(
      kind: PresetKind.tiny,
      title: 'خیلی کم‌حجم',
      subtitle: 'مناسب ارسال سریع در اینترنت ضعیف',
      maxShortSide: 360,
      crf: 30,
      audioBitrateKbps: 64,
    ),
    CompressPreset(
      kind: PresetKind.targetSize,
      title: 'حجم دلخواه',
      subtitle: 'حجم خروجی را خودتان تعیین کنید',
      maxShortSide: null,
      crf: 24,
    ),
    CompressPreset(
      kind: PresetKind.custom,
      title: 'تنظیمات پیشرفته',
      subtitle: 'رزولوشن، کیفیت و فریم‌ریت دلخواه',
      maxShortSide: null,
      crf: 24,
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

  /// فقط برای حالت «حجم دلخواه» (مگابایت)
  final double targetSizeMb;

  /// فقط برای حالت «تنظیمات پیشرفته»
  final int? customShortSide;
  final int? customCrf;
  final double? customFps;

  final String outputName;

  const CompressOptions({
    required this.preset,
    this.codec = VideoCodec.h264,
    this.format = OutputFormat.mp4,
    this.speed = EncodeSpeed.balanced,
    this.removeAudio = false,
    this.targetSizeMb = 10,
    this.customShortSide,
    this.customCrf,
    this.customFps,
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
    int? customCrf,
    double? customFps,
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
      customCrf: customCrf ?? this.customCrf,
      customFps: customFps ?? this.customFps,
      outputName: outputName ?? this.outputName,
    );
  }

  int get effectiveCrf {
    if (preset.kind == PresetKind.custom && customCrf != null) return customCrf!;
    return preset.crf;
  }

  int? get effectiveShortSide {
    if (preset.kind == PresetKind.custom) return customShortSide;
    return preset.maxShortSide;
  }

  int get audioKbps => preset.audioBitrateKbps;
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

  @override
  String toString() => '$width×$height';
}

/// تخمین حجم خروجی (تقریبی) برای نمایش به کاربر قبل از شروع
class SizeEstimator {
  /// بیت بر پیکسل بر اساس CRF — کالیبره‌شده برای x264
  static double _bitsPerPixel(int crf, VideoCodec codec) {
    final base = 0.045 * math.pow(2, (28 - crf) / 6.0);
    final codecFactor = codec == VideoCodec.h265 ? 0.62 : 1.0;
    return base * codecFactor;
  }

  /// خروجی: حجم تخمینی به بایت
  static int estimate(MediaInfo info, CompressOptions options) {
    if (options.preset.kind == PresetKind.targetSize) {
      return (options.targetSizeMb * 1024 * 1024).round();
    }

    final dims = Dimensions.compute(info, options.effectiveShortSide);
    final fps = options.customFps ?? info.frameRate;
    final effectiveFps = fps <= 0 ? 30.0 : math.min(fps, info.frameRate);

    final bpp = _bitsPerPixel(options.effectiveCrf, options.codec);
    var videoBps = dims.width * dims.height * effectiveFps * bpp;
    videoBps *= options.speed.sizeFactor;

    // سقف منطقی: خروجی نباید از بیت‌ریت منبع بیشتر شود
    if (info.bitrate > 0) {
      videoBps = math.min(videoBps, info.bitrate * 0.98);
    }

    final audioBps =
        options.removeAudio || !info.hasAudio ? 0 : options.audioKbps * 1000;

    final totalBits = (videoBps + audioBps) * info.durationSeconds;
    final bytes = (totalBits / 8).round();

    // خروجی هرگز نباید بزرگ‌تر از ورودی گزارش شود
    return math.min(bytes, info.sizeBytes);
  }
}
