# --- FFmpegKit ---
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.smartexception.** { *; }
-dontwarn com.arthenica.**

# --- Flutter ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Play Core (در صورت نبود در مایکت) ---
-dontwarn com.google.android.play.core.**

# نگه‌داشتن نام کلاس‌های مدل
-keepattributes *Annotation*
-keepattributes Signature
