# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Supabase / OkHttp / Retrofit
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# ExoPlayer / Media3
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# FFmpeg Kit (ancien fork tanersener — conservé pour compatibilité)
-keep class com.arthenica.ffmpegkit.** { *; }

# FFmpeg Kit (fork actuel antonkarpenko — nécessaire en Release)
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# LiveKit WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Flame game engine
-keep class org.libsdl.** { *; }

# Camera plugin
-keep class io.flutter.plugins.camera.** { *; }

# Keep Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# R8 full mode compatibility
-dontwarn java.lang.invoke.StringConcatFactory

# Play Core (SplitCompat / Deferred Components) — referenced by Flutter engine
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Sceneform AR — referenced transitively but not used
-dontwarn com.google.ar.sceneform.**
-dontwarn com.google.devtools.build.android.desugar.runtime.**
