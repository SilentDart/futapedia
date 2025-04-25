# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.firebase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Google Mobile Ads
-keep public class com.google.android.gms.ads.** { public *; }
-keep public class com.google.ads.** { public *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Google API Client
-keep class com.google.api.client.** { *; }
-keep class com.google.api.services.** { *; }
-keep class com.google.gson.** { *; }

# Syncfusion PDF Viewer
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# Youtube Player
-keepattributes SourceFile,LineNumberTable
-keep public class com.pierfrancescosoffritti.androidyoutubeplayer.** { *; }
-keep public class com.google.android.exoplayer2.** { *; }

# WebView
-keep class android.webkit.** { *; }

# Lottie
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

# HTTP
-keep class org.apache.commons.** { *; }
-keep class okhttp3.** { *; }
-dontwarn okio.**
-dontwarn okhttp3.**

# Gson (Used by many Firebase packages)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Encryption
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Provider
-keep class androidx.lifecycle.** { *; }

# Device Info Plus
-keep class android.os.Build { *; }

# Share Plus
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.core.content.FileProvider.** { *; }

# Awesome Notifications
-keep class me.carda.awesome_notifications.** { *; }

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Screen Protector
-keep class com.ryanheise.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Flutter Downloader
-keep class vn.hunghd.flutterdownloader.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Open File
-keep class com.crazecoder.openfile.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Wakelock Plus
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# Keep serializable classes & models
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# General rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Javascript interface methods in WebView
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Package Info Plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep R8 directives
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# 🔧 Play Core Library (Fix R8 missing class errors)
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**
