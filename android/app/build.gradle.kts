import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, kept OUT of the repository (this repo is public).
// Locally: copy android/key.properties.example to android/key.properties and
// fill it in. In CI: the workflow writes this file from repository secrets.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.atasanbratan.sstp_shield"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.atasanbratan.sstp_shield"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Both audiences share the "standard" identity (local + foreign, selected by
    // --target).
    //   flutter build apk --flavor standard --target lib/main.dart
    //   flutter build apk --flavor standard --target lib/main_foreign.dart
    //
    // The "admin" flavor is gone: the operator console is its own project now
    // (~/Projects/sstp_shield_vpn_admin), so it is neither shipped to users nor
    // published in this repository.
    flavorDimensions += "audience"
    productFlavors {
        create("standard") {
            dimension = "audience"
            // Inherits the default applicationId.
            manifestPlaceholders["appName"] = "SSTP SHIELD"
        }
    }

    signingConfigs {
        // Real release keys, supplied out-of-band via android/key.properties
        // (gitignored; CI writes it from repository secrets). Absent that file
        // the release build falls back to DEBUG keys — see buildTypes below.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // A debug-signed release APK installs and runs, which is exactly why
            // this is dangerous: it is NOT distributable (the key is not yours,
            // and a properly signed build later cannot upgrade over it). So the
            // fallback is loud rather than silent — see the warning below.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: android/key.properties not found — signing the " +
                        "RELEASE build with DEBUG keys. This APK is NOT " +
                        "distributable. See android/key.properties.example."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required by flutter_local_notifications (java.time APIs on older SDKs).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
