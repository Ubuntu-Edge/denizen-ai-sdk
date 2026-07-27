# release.ps1 - Automated Closed-Source Binary Packaging Script for Denizen AI

Write-Host "🚀 Starting Denizen AI Binary compilation and packaging..." -ForegroundColor Cyan

# 1. Stop any running gradle daemons
Write-Host "🧹 Stopping Gradle daemons..." -ForegroundColor Gray
Start-Process -FilePath "cmd.exe" -ArgumentList "/c cd example\android && gradlew --stop" -Wait -NoNewWindow

# 2. Build for Android (Release mode)
Write-Host "📱 Building Android release binaries..." -ForegroundColor Yellow
Start-Process -FilePath "flutter" -ArgumentList "build apk --release" -WorkingDirectory "example" -Wait -NoNewWindow

# 3. Build for Windows (Release mode)
Write-Host "💻 Building Windows release binaries..." -ForegroundColor Yellow
Start-Process -FilePath "flutter" -ArgumentList "build windows --release" -WorkingDirectory "example" -Wait -NoNewWindow

# 4. Check outputs
$androidSo = "example\build\app\intermediates\merged_native_libs\release\out\lib\arm64-v8a\libllama.so"
$windowsDll = "example\build\windows\runner\Release\llama.dll"

if (!(Test-Path $androidSo)) {
    Write-Host "⚠️ Android binary compilation could not find outputs at $androidSo" -ForegroundColor Red
}
if (!(Test-Path $windowsDll)) {
    Write-Host "⚠️ Windows binary compilation could not find outputs at $windowsDll" -ForegroundColor Red
}

# 5. Create release packaging directory structure
Write-Host "📦 Packaging clean release distribution..." -ForegroundColor Green
$releaseDir = "release_bundle"
if (Test-Path $releaseDir) { Remove-Item -Recurse -Force $releaseDir }
New-Item -ItemType Directory -Path "$releaseDir\packages\llama_flutter_android\android\src\main\jniLibs\arm64-v8a" -Force | Out-Null
New-Item -ItemType Directory -Path "$releaseDir\packages\llama_flutter_android\windows" -Force | Out-Null

# 6. Copy compiled binaries to target release folder (if compiled successfully)
if (Test-Path $androidSo) {
    Copy-Item $androidSo -Destination "$releaseDir\packages\llama_flutter_android\android\src\main\jniLibs\arm64-v8a\libllama.so" -Force
    Write-Host "✅ Copied Android release binaries." -ForegroundColor Green
}
if (Test-Path $windowsDll) {
    Copy-Item $windowsDll -Destination "$releaseDir\packages\llama_flutter_android\windows\llama.dll" -Force
    Write-Host "✅ Copied Windows release binaries." -ForegroundColor Green
}

# 7. Copy core SDK (excluding C++ code)
Write-Host "🗑️ Stripping C++ source files and copying clean Dart files..." -ForegroundColor Green
Copy-Item -Recurse "lib" -Destination "$releaseDir\lib" -Force
Copy-Item "pubspec.yaml" -Destination "$releaseDir\pubspec.yaml" -Force
Copy-Item "README.md" -Destination "$releaseDir\README.md" -Force

# 8. Copy llama_flutter_android Dart plugin (excluding native C++ code)
Copy-Item -Recurse "packages\llama_flutter_android\lib" -Destination "$releaseDir\packages\llama_flutter_android\lib" -Force
Copy-Item "packages\llama_flutter_android\pubspec.yaml" -Destination "$releaseDir\packages\llama_flutter_android\pubspec.yaml" -Force
Copy-Item "packages\llama_flutter_android\android\src\main\kotlin" -Destination "$releaseDir\packages\llama_flutter_android\android\src\main\kotlin" -Recurse -Force

# Write the modified release build.gradle.kts to the bundle
$releaseKtsContent = @"
group = "com.write4me.llama_flutter_android"
version = "1.0.0"
extra["kotlinVersion"] = "2.1.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
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

    kotlinOptions {
        jvmTarget = "11"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            jniLibs.srcDirs("src/main/jniLibs") // Load compiled binaries instead of compiling CMake
        }
    }

    defaultConfig {
        minSdk = 26
        ndk {
            abiFilters.addAll(listOf("arm64-v8a"))
        }
    }

    dependencies {
        implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    }
}
"@

Set-Content -Path "$releaseDir\packages\llama_flutter_android\android\build.gradle.kts" -Value $releaseKtsContent -Force

Write-Host "✅ Release bundle created successfully in directory: \`$releaseDir\`!" -ForegroundColor Green
Write-Host "You can zip and distribute the \`$releaseDir\` package openly without exposing any C++ source code!" -ForegroundColor Cyan
