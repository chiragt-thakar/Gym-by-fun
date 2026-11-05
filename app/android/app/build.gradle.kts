import java.util.Properties

// Release signing: android/key.properties (git-ignored) or CI secrets via env.
// storeFile=…/upload.jks  storePassword=…  keyAlias=upload  keyPassword=…
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(key: String, env: String): String? =
    keystoreProps.getProperty(key) ?: System.getenv(env)

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.motionquest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.motionquest"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 11+ covers ~9 in 10 Indian Android devices (plan: device tiers).
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // MediaPipe memory-maps the pose model; keep it uncompressed in the APK.
    androidResources {
        noCompress += "task"
    }

    signingConfigs {
        create("release") {
            val store = signingValue("storeFile", "MQ_KEYSTORE_PATH")
            if (store != null) {
                storeFile = file(store)
                storePassword = signingValue("storePassword", "MQ_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "MQ_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "MQ_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val release = signingConfigs.getByName("release")
            // Without an upload key the release build is signed with the debug
            // key so it can still be installed locally; Play will refuse it.
            signingConfig = if (release.storeFile != null) release else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
