import 'package:flutter/material.dart';
import '../core/theme.dart';

/// دکمه اصلی با گرادیان فیروزه‌ای
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final bool expanded;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 56,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.tealGradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x4D0DB0B0),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  )
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// دکمه ثانویه
class OutlineButtonX extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  const OutlineButtonX({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(115)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      ),
    );
  }
}

/// چیپ نمایش اطلاعات (رزولوشن، حجم، مدت)
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const InfoChip({super.key, required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// عنوان بخش
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionTitle({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      color: AppColors.tealLight, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// خط جداکننده تنظیمات
class SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.tealLight),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 14.5)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_left_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
