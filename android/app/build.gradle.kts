import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release signing key, kept out of the repository. Without it the build
// still works — it falls back to the debug key — so a fresh clone compiles;
// only the release someone installs needs the real one.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.tunebox.tunebox"
    // Pinned above the Flutter default because flutter_secure_storage compiles
    // against SDK 37. Android SDKs are backward compatible, so raising the
    // compile target does not change which devices can install the app.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tunebox.tunebox"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
            storeFile = keyProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = keyProperties.getProperty("storePassword")

            // v2 is what every device that can install this app verifies; v3
            // additionally lets the key be replaced later without every install
            // having to be removed first.
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            // Every build of a given version has to be signed by the same key or
            // Android refuses to install it over the last one. Updates outside a
            // store are the whole point here, so this is the release's identity.
            signingConfig = signingConfigs.getByName(
                if (keyProperties.isEmpty) "debug" else "release",
            )
        }
    }
}

flutter {
    source = "../.."
}
