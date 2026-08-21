import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // پالت فیروزه‌ای
  static const Color teal = Color(0xFF0DB0B0);
  static const Color tealLight = Color(0xFF22E2D2);
  static const Color tealDark = Color(0xFF065F6E);
  static const Color tealDeep = Color(0xFF04414E);

  // پس‌زمینه تیره
  static const Color bg = Color(0xFF0B1417);
  static const Color surface = Color(0xFF122127);
  static const Color surfaceHigh = Color(0xFF172B33);
  static const Color stroke = Color(0xFF1F3C45);

  static const Color textPrimary = Color(0xFFE9F6F6);
  static const Color textSecondary = Color(0xFF8FAFB6);

  static const Color success = Color(0xFF2ECC8F);
  static const Color warning = Color(0xFFF2B33D);
  static const Color danger = Color(0xFFE5586A);

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [tealLight, teal, tealDark],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF172B33), Color(0xFF102026)],
  );
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        secondary: AppColors.tealLight,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Vazirmatn',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      dividerColor: AppColors.stroke,
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.teal,
        inactiveTrackColor: AppColors.stroke,
        thumbColor: AppColors.tealLight,
        overlayColor: Color(0x330DB0B0),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// استایل‌های تکراری
class AppStyles {
  static BoxDecoration card({Color? color, double radius = 20, bool border = true}) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: AppColors.stroke, width: 1) : null,
    );
  }

  static BoxDecoration selectedCard({double radius = 20}) {
    return BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.teal, width: 1.6),
      boxShadow: const [
        BoxShadow(color: Color(0x330DB0B0), blurRadius: 18, spreadRadius: 1),
      ],
    );
  }
}
