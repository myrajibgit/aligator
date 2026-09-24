# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Health Connect
-keep class androidx.health.connect.** { *; }
-dontwarn androidx.health.connect.**

# Firebase
-keepattributes *Annotation*
-dontwarn com.google.firebase.**
