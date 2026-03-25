# Flutter & Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase Realtime (WebSocket)
-keep class io.crossingthestreams.** { *; }
-keep class org.java_websocket.** { *; }
-keep class com.google.crypto.tink.** { *; }

# OkHttp (used by some plugins for WebSocket)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# Play Core (deferred components - not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Gson / JSON serialization
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
