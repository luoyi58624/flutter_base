plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 原生插件跟随 Flutter 的目标架构，避免单架构 APK 混入其他架构的解码库。
        // 拆分 APK 时交给 Flutter 的 splits 配置，避免与 ndk 过滤冲突。
        if (providers.gradleProperty("split-per-abi").orNull != "true") {
            providers.gradleProperty("target-platform").orNull?.let { platforms ->
                ndk {
                    abiFilters.clear()
                    abiFilters.addAll(platforms.split(",").map { platform ->
                        when (platform) {
                            "android-arm" -> "armeabi-v7a"
                            "android-arm64" -> "arm64-v8a"
                            "android-x64" -> "x86_64"
                            else -> error("不支持的 Flutter Android 目标架构：$platform")
                        }
                    })
                }
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
