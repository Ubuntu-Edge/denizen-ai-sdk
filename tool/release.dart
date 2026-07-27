import 'dart:io';
import 'package:path/path.dart' as p;

/// Runs a shell command through cmd.exe on Windows, bash on Linux/macOS
Future<int> run(String command, {String? workingDirectory}) async {
  print('  > $command');
  final process = await Process.start(
    Platform.isWindows ? 'cmd.exe' : 'bash',
    Platform.isWindows ? ['/c', command] : ['-c', command],
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

void copyDirectory(Directory source, Directory destination) {
  if (!destination.existsSync()) destination.createSync(recursive: true);
  for (var entity in source.listSync()) {
    if (entity is Directory) {
      copyDirectory(entity, Directory(p.join(destination.path, p.basename(entity.path))));
    } else if (entity is File) {
      entity.copySync(p.join(destination.path, p.basename(entity.path)));
    }
  }
}

void main() async {
  // Resolve root relative to THIS script's location, not the shell cwd
  // tool/release.dart lives one directory below root
  final root = p.dirname(p.dirname(Platform.script.toFilePath()));

  print('🚀 Starting Denizen AI Binary compilation and packaging...');

  // 2. Ensure nuget is available on Windows (needed by flutter_tts Windows plugin)
  if (Platform.isWindows) {
    final nugetCheck = await Process.run('cmd.exe', ['/c', 'where nuget']);
    if (nugetCheck.exitCode != 0) {
      print('📥 nuget.exe not found — installing via winget...');
      await run('winget install Microsoft.NuGet --silent --accept-package-agreements --accept-source-agreements');
    }
  }

  // 3. Define expected output paths — AGP may write .so to different subdirs
  // We search both the merged_native_libs path (AGP <8) and the new stripped path (AGP 8+)
  String? findAndroidSo(String exampleRoot) {
    final candidates = [
      p.join(exampleRoot, 'build', 'app', 'intermediates', 'merged_native_libs', 'release', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
      p.join(exampleRoot, 'build', 'app', 'intermediates', 'merged_native_libs', 'release', 'mergeReleaseNativeLibs', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
      p.join(exampleRoot, 'build', 'app', 'intermediates', 'stripped_native_libs', 'release', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
      p.join(exampleRoot, 'build', 'app', 'intermediates', 'stripped_native_libs', 'release', 'stripReleaseDebugSymbols', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  final windowsDll = p.join(root, 'example', 'build', 'windows', 'runner', 'Release', 'llama.dll');

  // 4. Clear stale outputs so checks below are only true for fresh binaries
  print('🗑️  Clearing stale build outputs...');
  final staleAndroid = findAndroidSo(p.join(root, 'example'));
  if (staleAndroid != null) File(staleAndroid).deleteSync();
  if (File(windowsDll).existsSync()) File(windowsDll).deleteSync();

  // 5. Build Android release binaries
  print('📱 Building Android release binaries...');
  final androidExit = await run('flutter build apk --release', workingDirectory: p.join(root, 'example'));
  if (androidExit != 0) print('⚠️  Android build exited with code $androidExit — binary may be missing.');

  // 6. Build Windows release binaries (Windows host only)
  if (Platform.isWindows) {
    print('💻 Building Windows release binaries...');
    final winExit = await run('flutter build windows --release', workingDirectory: p.join(root, 'example'));
    if (winExit != 0) print('⚠️  Windows build exited with code $winExit — binary may be missing.');
  }

  final androidSo = findAndroidSo(p.join(root, 'example'));
  final androidOk = androidSo != null;
  final windowsOk = File(windowsDll).existsSync();

  if (!androidOk) print('⚠️  Android binary (.so) not found — bundle will skip native Android support.');
  if (!windowsOk && Platform.isWindows) print('⚠️  Windows binary (.dll) not found — bundle will skip native Windows support.');

  // 6. Create release packaging directory
  print('📦 Packaging clean release distribution...');
  final releaseDir = p.join(root, 'release_bundle');
  final releaseD = Directory(releaseDir);
  if (releaseD.existsSync()) releaseD.deleteSync(recursive: true);
  releaseD.createSync(recursive: true);

  // 7. Validate required source paths exist
  final requiredPaths = [
    'lib',
    'pubspec.yaml',
    'README.md',
    p.join('packages', 'llama_flutter_android', 'lib'),
    p.join('packages', 'llama_flutter_android', 'pubspec.yaml'),
    p.join('packages', 'llama_flutter_android', 'android', 'src', 'main', 'kotlin'),
  ];
  for (final path in requiredPaths) {
    final full = p.join(root, path);
    if (!File(full).existsSync() && !Directory(full).existsSync()) {
      print('❌ Expected source path not found: $path (run this from the repo root!)');
      exit(1);
    }
  }

  // 8. Copy core SDK (Dart only, no C++ source)
  print('✂️  Stripping C++ source files and copying clean Dart files...');
  copyDirectory(Directory(p.join(root, 'lib')), Directory(p.join(releaseDir, 'lib')));
  File(p.join(root, 'pubspec.yaml')).copySync(p.join(releaseDir, 'pubspec.yaml'));
  File(p.join(root, 'README.md')).copySync(p.join(releaseDir, 'README.md'));

  // 9. Copy llama_flutter_android Dart wrapper (no C++ source)
  final destWrapper = p.join(releaseDir, 'packages', 'llama_flutter_android');
  copyDirectory(
    Directory(p.join(root, 'packages', 'llama_flutter_android', 'lib')),
    Directory(p.join(destWrapper, 'lib')),
  );
  copyDirectory(
    Directory(p.join(root, 'packages', 'llama_flutter_android', 'android', 'src', 'main', 'kotlin')),
    Directory(p.join(destWrapper, 'android', 'src', 'main', 'kotlin')),
  );
  File(p.join(root, 'packages', 'llama_flutter_android', 'pubspec.yaml'))
      .copySync(p.join(destWrapper, 'pubspec.yaml'));

  // 10. Copy compiled binaries
  if (androidOk) {
    final jniDir = Directory(p.join(destWrapper, 'android', 'src', 'main', 'jniLibs', 'arm64-v8a'))
      ..createSync(recursive: true);
    File(androidSo!).copySync(p.join(jniDir.path, 'libllama.so'));
    print('✅ Copied Android release binary (.so)');
  }
  if (windowsOk) {
    final winDir = Directory(p.join(destWrapper, 'windows'))..createSync(recursive: true);
    File(windowsDll).copySync(p.join(winDir.path, 'llama.dll'));
    print('✅ Copied Windows release binary (.dll)');
  }

  // 11. Write release build.gradle.kts (points to precompiled jniLibs, no CMake)
  File(p.join(destWrapper, 'android', 'build.gradle.kts')).writeAsStringSync('''
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
            // Load precompiled .so binaries instead of compiling via CMake
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
''');

  print('\n✅ Release bundle created successfully at: $releaseDir');
  print('Zip and distribute the release_bundle/ directory — no C++ source code included!');
}
