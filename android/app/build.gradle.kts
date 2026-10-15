import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // CUSTOM: id("org.jetbrains.kotlin.android") removed — the Flutter Gradle plugin applies it (AGP 9 / Flutter warns when the app declares it)
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sixamtech.sixam_mart_user"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.talabati.user" // CUSTOM: rebrand — matches Firebase project 'Talabati' (was com.sixamtech.sixam_mart_user)
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    // CUSTOM: replaces android:extractNativeLibs="true" from AndroidManifest.xml (AGP 9 rejects the attribute)
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug") // or "release" if you have real keystore
        }
    }
}

// CUSTOM-START: AGP 9 / KGP 2.4 — android { kotlinOptions } was removed; same JVM 11 target
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}
// CUSTOM-END

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.firebase:firebase-messaging:23.4.1")
    // CUSTOM: Facebook SDK removed (SY-TPRA permission rules)
}
