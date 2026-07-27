group = "com.write4me.llama_flutter_android"
version = "1.0.0"
extra["kotlinVersion"] = "2.1.0"

buildscript {
    repositories { google(); mavenCentral() }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

allprojects {
    repositories { google(); mavenCentral() }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.write4me.llama_flutter_android"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            // Load precompiled .so binaries — no CMake compilation needed
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    defaultConfig {
        minSdk = 26
        ndk { abiFilters.addAll(listOf("arm64-v8a")) }
    }

    dependencies {
        implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    }
}
