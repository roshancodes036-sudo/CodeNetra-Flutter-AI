# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.embedding.engine.**  { *; }
-keep class io.flutter.embedding.android.**  { *; }
-keep class io.flutter.plugin.common.**  { *; }

# Existing rules from user
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <fields>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
-dontwarn com.google.protobuf.**
-keep class com.google.android.gms.internal.** { *; }


# Added Rules for ML Kit and Google Play Core

# Keep all classes related to ML Kit text recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }


# Keep all classes related to Google Play Core (for deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep auto-generated Parcelable classes
-keep class ** extends android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}
