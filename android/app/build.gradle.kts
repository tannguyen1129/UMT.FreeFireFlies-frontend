plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // 👇 SỬA DÒNG NÀY: Xóa 'version' và 'apply false'
    // Chỉ để lại id, nó sẽ tự lấy version từ file gốc
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.frontend_citizen"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion // Hoặc phiên bản cụ thể nếu bạn muốn giữ

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // Nên dùng 1.8 hoặc 11
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.frontend_citizen"
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