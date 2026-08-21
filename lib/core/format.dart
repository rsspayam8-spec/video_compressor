/// توابع کمکی برای نمایش فارسی حجم، زمان و اعداد
class Fmt {
  static const _fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  /// تبدیل ارقام انگلیسی به فارسی
  static String fa(String input) {
    var out = input;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(i.toString(), _fa[i]);
    }
    return out;
  }

  /// حجم فایل به صورت خوانا: ۱۲٫۴ مگابایت
  static String size(num bytes, {bool persian = true}) {
    if (bytes <= 0) return persian ? '۰ بایت' : '0 B';
    const units = ['بایت', 'کیلوبایت', 'مگابایت', 'گیگابایت'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(value >= 100 ? 0 : 1);
    final result = '$text ${units[unit]}';
    return persian ? fa(result).replaceAll('.', '٫') : result;
  }

  /// مدت زمان: ۰۱:۲۳ یا ۱:۰۲:۰۳
  static String duration(Duration d, {bool persian = true}) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = h > 0 ? '$h:$m:$s' : '$m:$s';
    return persian ? fa(text) : text;
  }

  /// درصد
  static String percent(double value, {bool persian = true}) {
    final text = '${value.toStringAsFixed(0)}٪';
    return persian ? fa(text) : text;
  }

  static String num_(num value, {int decimals = 0}) {
    return fa(value.toStringAsFixed(decimals)).replaceAll('.', '٫');
  }

  /// نام فایل امن برای خروجی
  static String safeName(String name) {
    final withoutExt = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    return withoutExt.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
