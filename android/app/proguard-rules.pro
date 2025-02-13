# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# WorkManager
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}

# Notification
-keep class com.dexterous.** { *; }

# Application
-keep class com.mon.golon_babe.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Most of volatile fields are updated with AFU and should not be mangled
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Files and SQLite
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Support Library
-keep class android.support.v4.app.** { *; }
-keep interface android.support.v4.app.** { *; }

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Multidex
-keep class androidx.multidex.MultiDexApplication { *; }

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Rules for local notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom applications
-keep public class * extends android.app.Application

# Keep activities
-keep public class * extends android.app.Activity
-keep public class * extends androidx.appcompat.app.AppCompatActivity

# Keep services
-keep public class * extends android.app.Service

# Keep broadcast receivers
-keep public class * extends android.content.BroadcastReceiver

# Keep content providers
-keep public class * extends android.content.ContentProvider