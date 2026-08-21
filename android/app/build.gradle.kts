import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ط®ظˆط§ظ†ط¯ظ† ط§ط·ظ„ط§ط¹ط§طھ ع©ظ„غŒط¯ ط§ظ…ط¶ط§ ط§ط² android/key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // âڑ ï¸ڈ ط§غŒظ† ط´ظ†ط§ط³ظ‡ ط¨ط§غŒط¯ غŒع©طھط§ ط¨ط§ط´ط¯ ظˆ ط¨ط¹ط¯ ط§ط² ط§ظ†طھط´ط§ط± ظ‚ط§ط¨ظ„ طھط؛غŒغŒط± ظ†غŒط³طھ
    namespace = "ir.videotools.video_compressor"
    compileSdk = 35
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "ir.videotools.compressor"
        minSdk = 24          // ط­ط¯ط§ظ‚ظ„ ظ…ظˆط±ط¯ ظ†غŒط§ط² FFmpegKit
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        // ظپظ‚ط· ظ…ط¹ظ…ط§ط±غŒâ€Œظ‡ط§غŒ ظˆط§ظ‚ط¹غŒ ع¯ظˆط´غŒâ€Œظ‡ط§ â€” ط­ط¬ظ… APK ط±ط§ ظ†طµظپ ظ…غŒâ€Œع©ظ†ط¯
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    // ط³ط§ط®طھ APK ط¬ط¯ط§ع¯ط§ظ†ظ‡ ط¨ط±ط§غŒ ظ‡ط± ظ…ط¹ظ…ط§ط±غŒ (ط§ط®طھغŒط§ط±غŒ - ط­ط¬ظ… ع©ظ…طھط±)
    // ط¨ط±ط§غŒ ظپط¹ط§ظ„ ع©ط±ط¯ظ†طŒ ط®ط· ط²غŒط± ط±ط§ ط§ط² ط­ط§ظ„طھ ع©ط§ظ…ظ†طھ ط®ط§ط±ط¬ ع©ظ†غŒط¯:
    // splits {
    //     abi {
    //         isEnable = true
    //         reset()
    //         include("armeabi-v7a", "arm64-v8a")
    //         isUniversalApk = true
    //     }
    // }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}


