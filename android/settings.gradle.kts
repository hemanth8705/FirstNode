pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Pinned below AGP 9: file_picker 11.0.2 only applies its own Kotlin plugin
    // when AGP < 9 (assuming AGP 9's "Built-in Kotlin" otherwise handles it), but
    // this project disables built-in Kotlin because `alarm` applies its own Kotlin
    // plugin unconditionally. AGP 9 support across the plugin ecosystem is still
    // transitional — 8.13 is the latest stable pre-9 release and avoids the gap.
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
