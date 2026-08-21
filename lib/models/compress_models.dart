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

/// کدک ویدئو — هر دو با انکودر سخت‌افزاری MediaCodec خود اندروید کار می‌کنند
/// (بدون نیاز به کتابخانه نرم‌افزاری x264/x265، حجم برنامه را بسیار کم می‌کند)
enum VideoCodec {
  h264(
    'H.264 (سخت‌افزاری)',
    'سریع، کم‌مصرف، سازگار با همه گوشی‌ها',
    'h264_mediacodec',
  ),
  h265(
    'H.265 / HEVC (سخت‌افزاری)',
    'حجم کمتر در بیت‌ریت یکسان، نیاز به گوشی نسبتاً جدید',
    'hevc_mediacodec',
  );

  const VideoCodec(this.label, this.hint, this.ffmpegName);
  final String label;
  final String hint;
  final String ffmpegName;
}

/// فرمت خروجی — همه با کدک‌های داخلی (بدون کتابخانه اضافه، حجم نصب کم)
enum OutputFormat {
  mp4('MP4', 'mp4'),
  mkv('MKV', 'mkv'),
  mov('MOV', 'mov');

  const OutputFormat(this.label, this.ext);
  final String label;
  final String ext;
}

/// نوع پریست فشرده‌سازی
enum PresetKind { quality, recommended, small, tiny, targetSize, custom }

/// یک پریست آماده
class CompressPreset {
  final PresetKind kind;
  final String title;
  final String subtitle;
  final int? maxShortSide; // حداکثر ضلع کوچک — null یعنی رزولوشن اصلی
  final int baseBitrateKbps; // بیت‌ریت پایه ویدئو
  final int audioBitrateKbps;

  const CompressPreset({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.maxShortSide,
    required this.baseBitrateKbps,
    this.audioBitrateKbps = 128,
  });

  static const List<CompressPreset> all = [
    CompressPreset(
      kind: PresetKind.quality,
      title: 'کیفیت اصلی',
      subtitle: 'رزولوشن دست‌نخورده، کاهش ملایم حجم',
      maxShortSide: null,
      baseBitrateKbps: 6000,
      audioBitrateKbps: 160,
    ),
    CompressPreset(
      kind: PresetKind.recommended,
      title: 'پیشنهادی',
      subtitle: 'بهترین تعادل کیفیت و حجم — برای تلگرام و واتساپ',
      maxShortSide: 720,
      baseBitrateKbps: 2000,
      audioBitrateKbps: 128,
    ),
    CompressPreset(
      kind: PresetKind.small,
      title: 'حجم کم',
      subtitle: 'کاهش زیاد حجم با کیفیت قابل قبول',
      maxShortSide: 540,
      baseBitrateKbps: 1200,
      audioBitrateKbps: 96,
    ),
    CompressPreset(
      kind: PresetKind.tiny,
      title: 'خیلی کم‌حجم',
      subtitle: 'مناسب ارسال سریع در اینترنت ضعیف',
      maxShortSide: 360,
      baseBitrateKbps: 700,
      audioBitrateKbps: 64,
    ),
    CompressPreset(
      kind: PresetKind.targetSize,
      title: 'حجم دلخواه',
      subtitle: 'حجم خروجی را خودتان دقیق تعیین کنید',
      maxShortSide: null,
      baseBitrateKbps: 2000,
    ),
    CompressPreset(
      kind: PresetKind.custom,
      title: 'تنظیمات پیشرفته',
      subtitle: 'رزولوشن، بیت‌ریت و فریم‌ریت دلخواه',
      maxShortSide: null,
      baseBitrateKbps: 2000,
    ),
  ];
}

/// تنظیمات نهایی فشرده‌سازی
class CompressOptions {
  final CompressPreset preset;
  final VideoCodec codec;
  final OutputFormat format;
  final bool removeAudio;

  /// فقط برای حالت «حجم دلخواه» (مگابایت)
  final double targetSizeMb;

  /// فقط برای حالت «تنظیمات پیشرفته»
  final int? customShortSide;
  final int? customBitrateKbps;
  final double? customFps;

  final String outputName;

const CompressOptions({
    required this.preset,
    this.codec = VideoCodec.h264,
    this.format = OutputFormat.mp4,
    this.removeAudio = false,
    this.targetSizeMb = 10,
    this.customShortSide,
    this.customBitrateKbps,
    this.customFps,
    this.outputName = '',
  });

  CompressOptions copyWith({
    CompressPreset? preset,
    VideoCodec? codec,
    OutputFormat? format,
    bool? removeAudio,
    double? targetSizeMb,
    int? customShortSide,
    int? customBitrateKbps,
    double? customFps,
    String? outputName,
  }) {
    return CompressOptions(
      preset: preset ?? this.preset,
      codec: codec ?? this.codec,
      format: format ?? this.format,
      removeAudio: removeAudio ?? this.removeAudio,
      targetSizeMb: targetSizeMb ?? this.targetSizeMb,
      customShortSide: customShortSide ?? this.customShortSide,
      customBitrateKbps: customBitrateKbps ?? this.customBitrateKbps,
      customFps: customFps ?? this.customFps,
      outputName: outputName ?? this.outputName,
    );
  }

  int? get effectiveShortSide {
    if (preset.kind == PresetKind.custom) return customShortSide;
    return preset.maxShortSide;
  }

  int get audioKbps => preset.audioBitrateKbps;

  /// بیت‌ریت واقعی ویدئو — این عدد مستقیم به FFmpeg داده می‌شود و مستقیم
  /// حجم خروجی را تعیین می‌کند (برخلاف CRF که فقط تخمینی بود)
  int effectiveBitrateKbps(MediaInfo info) {
    switch (preset.kind) {
      case PresetKind.quality:
        final sourceKbps =
            info.bitrate > 0 ? (info.bitrate / 1000).round() : 6000;
        return (sourceKbps * 0.85).round().clamp(800, 14000);
      case PresetKind.recommended:
      case PresetKind.small:
      case PresetKind.tiny:
        return preset.baseBitrateKbps;
      case PresetKind.targetSize:
        final audio = removeAudio || !info.hasAudio ? 0 : audioKbps;
        final totalKbps =
            (targetSizeMb * 8192) / math.max(info.durationSeconds, 1);
        return (totalKbps - audio).round().clamp(80, 40000);
      case PresetKind.custom:
        return (customBitrateKbps ?? 2000).clamp(80, 40000);
    }
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

  @override
  String toString() => '$width×$height';
}

/// تخمین حجم خروجی — چون مستقیم از بیت‌ریت هدف محاسبه می‌شود، دقیق است
/// (نه یک حدس آماری مثل حالت CRF قبلی)
class SizeEstimator {
  static int estimate(MediaInfo info, CompressOptions options) {
    final videoKbps = options.effectiveBitrateKbps(info);
    final audioKbps =
        options.removeAudio || !info.hasAudio ? 0 : options.audioKbps;
    final totalBits = (videoKbps + audioKbps) * 1000 * info.durationSeconds;
    return (totalBits / 8).round();
  }
}
