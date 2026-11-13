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
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")

// photo_manager 3.12.0 的旧 Kotlin 兼容分支会触发 Flutter 的静态检查，
// 仅替换该插件的构建脚本，原生源码继续使用 Pub 锁定版本。
findProject(":photo_manager")?.let { plugin ->
    val sourceDir = plugin.projectDir
    plugin.projectDir = file("gradle/photo_manager")
    gradle.beforeProject {
        if (path == ":photo_manager") {
            extensions.extraProperties.set("photoManagerSourceDir", sourceDir)
        }
    }
}
