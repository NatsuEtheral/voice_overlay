plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.offlinestt.voicenotes.offline_voice_notes"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.offlinestt.voicenotes.offline_voice_notes"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        ndk {
            abiFilters += setOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
        jniLibs {
            pickFirsts += listOf(
                "lib/arm64-v8a/libonnxruntime.so",
                "lib/arm64-v8a/libsherpa-onnx-jni.so",
                "lib/arm64-v8a/libsherpa-onnx-c-api.so",
                "lib/arm64-v8a/libsherpa-onnx-cxx-api.so",
                "lib/armeabi-v7a/libonnxruntime.so",
                "lib/armeabi-v7a/libsherpa-onnx-jni.so",
                "lib/armeabi-v7a/libsherpa-onnx-c-api.so",
                "lib/armeabi-v7a/libsherpa-onnx-cxx-api.so",
                "lib/x86_64/libonnxruntime.so",
                "lib/x86_64/libsherpa-onnx-jni.so",
                "lib/x86_64/libsherpa-onnx-c-api.so",
                "lib/x86_64/libsherpa-onnx-cxx-api.so",
                "lib/x86/libonnxruntime.so",
                "lib/x86/libsherpa-onnx-jni.so",
                "lib/x86/libsherpa-onnx-c-api.so",
                "lib/x86/libsherpa-onnx-cxx-api.so"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Core AndroidX
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("androidx.activity:activity-compose:1.9.3")

    // Jetpack Compose & Material 3
    val composeBom = platform("androidx.compose:compose-bom:2024.10.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    // DataStore (Preferences)
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // OkHttp (Streaming Model Downloads)
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Unit tests
    testImplementation("junit:junit:4.13.2")
}
