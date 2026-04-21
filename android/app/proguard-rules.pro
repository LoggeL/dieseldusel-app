# Flutter does not use deferred components; silence the missing Play Core
# classes that the Flutter embedding stubs reference so R8 does not abort.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep Flutter plugin registrant — reflection via class name at startup.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
