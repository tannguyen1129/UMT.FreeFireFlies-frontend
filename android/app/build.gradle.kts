plugins {
    id("com.android.application")
    id("kotlin-android") // Hoặc "org.jetbrains.kotlin.android" tùy phiên bản Flutter
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.frontend_citizen"
    compileSdk = flutter.compileSdkVersion

    // 👇 QUAN TRỌNG: Sửa dòng này để fix lỗi NDK version mismatch
    // Không dùng flutter.ndkVersion nữa vì nó đang trỏ về bản cũ
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.frontend_citizen"
        // Bạn có thể để minSdk 23 để tương thích tốt với các thư viện mới
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 👇 Đã xóa khối buildscript{} ở đây vì nó thừa (nó thuộc về file android/build.gradle)