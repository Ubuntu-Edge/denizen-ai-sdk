import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  print("🚀 Starting Denizen AI Binary compilation and packaging...");

  // 1. Stop Gradle
  print("🧹 Stopping Gradle daemons...");
  await Process.run(
    Platform.isWindows ? 'cmd.exe' : 'bash',
    Platform.isWindows ? ['/c', 'gradlew --stop'] : ['-c', './gradlew --stop'],
    workingDirectory: p.join(Directory.current.path, 'example', 'android'),
  );

  // 2. Build for Android (Release mode)
  print("📱 Building Android release binaries...");
  final buildAndroid = await Process.start(
    'flutter',
    ['build', 'apk', '--release'],
    workingDirectory: p.join(Directory.current.path, 'example'),
    mode: ProcessStartMode.inheritStdio,
  );
  await buildAndroid.exitCode;

  // 3. Build for Windows (Release mode)
  if (Platform.isWindows) {
    print("💻 Building Windows release binaries...");
    final buildWindows = await Process.start(
      'flutter',
      ['build', 'windows', '--release'],
      workingDirectory: p.join(Directory.current.path, 'example'),
      mode: ProcessStartMode.inheritStdio,
    );
    await buildWindows.exitCode;
  }

  // 4. Create release bundle folder
  print("📦 Packaging clean release distribution...");
  final releaseDir = Directory(p.join(Directory.current.path, 'release_bundle'));
  if (releaseDir.existsSync()) {
    releaseDir.deleteSync(recursive: true);
  }
  releaseDir.createSync(recursive: true);

  // Helper to copy directories recursively
  void copyDirectory(Directory source, Directory destination) {
    for (var entity in source.listSync(recursive: false)) {
      if (entity is Directory) {
        final newDir = Directory(p.join(destination.path, p.basename(entity.path)));
        newDir.createSync();
        copyDirectory(entity, newDir);
      } else if (entity is File) {
        entity.copySync(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }

  // Copy lib/
  copyDirectory(
    Directory(p.join(Directory.current.path, 'lib')),
    Directory(p.join(releaseDir.path, 'lib'))..createSync(),
  );

  // Copy pubspec.yaml & README.md
  File(p.join(Directory.current.path, 'pubspec.yaml')).copySync(p.join(releaseDir.path, 'pubspec.yaml'));
  File(p.join(Directory.current.path, 'README.md')).copySync(p.join(releaseDir.path, 'README.md'));

  // Copy llama_flutter_android wrapper (only lib, kotlin, pubspec.yaml)
  final destWrapper = Directory(p.join(releaseDir.path, 'packages', 'llama_flutter_android'))..createSync(recursive: true);
  copyDirectory(
    Directory(p.join(Directory.current.path, 'packages', 'llama_flutter_android', 'lib')),
    Directory(p.join(destWrapper.path, 'lib'))..createSync(),
  );
  
  final destKotlin = Directory(p.join(destWrapper.path, 'android', 'src', 'main', 'kotlin'))..createSync(recursive: true);
  copyDirectory(
    Directory(p.join(Directory.current.path, 'packages', 'llama_flutter_android', 'android', 'src', 'main', 'kotlin')),
    destKotlin,
  );
  
  File(p.join(Directory.current.path, 'packages', 'llama_flutter_android', 'pubspec.yaml'))
      .copySync(p.join(destWrapper.path, 'pubspec.yaml'));

  // Copy compiled .so binaries
  final androidSo = File(p.join(
    Directory.current.path,
    'example', 'build', 'app', 'intermediates', 'merged_native_libs', 'release', 'out', 'lib', 'arm64-v8a', 'libllama.so'
  ));
  if (androidSo.existsSync()) {
    final jniDir = Directory(p.join(destWrapper.path, 'android', 'src', 'main', 'jniLibs', 'arm64-v8a'))..createSync(recursive: true);
    androidSo.copySync(p.join(jniDir.path, 'libllama.so'));
    print("✅ Packaged Android release binaries (.so)");
  } else {
    print("⚠️ Android release binary not found. Skipping Android packaging.");
  }

  // Copy compiled .dll binaries
  if (Platform.isWindows) {
    final windowsDll = File(p.join(
      Directory.current.path,
      'example', 'build', 'windows', 'runner', 'Release', 'llama.dll'
    ));
    if (windowsDll.existsSync()) {
      final winDir = Directory(p.join(destWrapper.path, 'windows'))..createSync(recursive: true);
      windowsDll.copySync(p.join(winDir.path, 'llama.dll'));
      print("✅ Packaged Windows release binaries (.dll)");
    } else {
      print("⚠️ Windows release binary not found. Skipping Windows packaging.");
    }
  }

  // Write release build.gradle.kts
  final buildGradleKts = File(p.join(destWrapper.path, 'android', 'build.gradle.kts'));
  buildGradleKts.writeAsStringSync('''group = "com.write4me.llama_flutter_android"
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
            jniLibs.srcDirs("src/main/jniLibs")
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
''');

  print("✅ Release bundle created successfully in directory: \${releaseDir.path}!");
  print("You can zip and distribute the 'release_bundle' package openly without exposing any C++ source code!");
}
