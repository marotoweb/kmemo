import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.marotoweb.kmemo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        applicationId = "com.marotoweb.kmemo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Reproducibility: remove files that vary between builds and break the SHA-256 hash.
    packaging {
        resources {
            excludes += "assets/dexopt/*"
            excludes += "META-INF/*.kotlin_module"
        }
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    val hasKeyProperties = keystorePropertiesFile.exists()
    if (hasKeyProperties) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (hasKeyProperties) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = if (hasKeyProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
            )
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

// FOSS compliance: block proprietary transitive Google Play dependencies.
configurations.all {
    resolutionStrategy {
        force("dev.flutter:empty:1.0")
        eachDependency {
            if (requested.group == "com.google.android.play") {
                useTarget("dev.flutter:empty:1.0")
            }
        }
    }
}

// Deterministic build: disable profile tasks that produce inconsistent binary data.
tasks.withType<org.gradle.api.Task>().configureEach {
    if (name.contains("ArtProfile", ignoreCase = true)) {
        enabled = false
    }
}

flutter {
    source = "../.."
}
