import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
    implementation("com.google.firebase:firebase-analytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties") // android/key.properties
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val ksKeyAlias = keystoreProperties.getProperty("keyAlias")
    ?: throw GradleException("android/key.properties에서 keyAlias 값을 찾을 수 없음")
val ksKeyPassword = keystoreProperties.getProperty("keyPassword")
    ?: throw GradleException("android/key.properties에서 keyPassword 값을 찾을 수 없음")
val ksStoreFile = keystoreProperties.getProperty("storeFile")
    ?: throw GradleException("android/key.properties에서 storeFile 값을 찾을 수 없음")
val ksStorePassword = keystoreProperties.getProperty("storePassword")
    ?: throw GradleException("android/key.properties에서 storePassword 값을 찾을 수 없음")

android {
    namespace = "com.dz.qbeats"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14206865"   // 실제 설치된 NDK 폴더명과 동일해야 함
    buildToolsVersion = "35.0.0"   // 실제 설치된 build-tools 폴더명과 동일해야 함

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = ksKeyAlias
            keyPassword = ksKeyPassword
            storeFile = file(ksStoreFile)
            storePassword = ksStorePassword
        }
    }

    defaultConfig {
        applicationId = "com.dz.qbeats"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            ndk {
                debugSymbolLevel = "NONE"
            }
        }
    }
}

flutter {
    source = "../.."
}