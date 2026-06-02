# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Video Player Android - Keep all classes
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class dev.flutter.plugins.videoplayer.** { *; }
-keep class io.flutter.plugins.videoplayer.VideoPlayerPlugin { *; }
-keep class io.flutter.plugins.videoplayer.VideoPlayer { *; }
-keep class io.flutter.plugins.videoplayer.VideoPlayerApi { *; }

# Keep Pigeon generated classes for video_player
-keep class dev.flutter.pigeon.video_player_android.** { *; }
-keep class **$Pigeon { *; }
-keep class **$*Pigeon { *; }
-keep class * extends dev.flutter.pigeon.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep annotation default values
-keepattributes AnnotationDefault
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
