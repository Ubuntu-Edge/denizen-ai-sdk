import 'dart:io';
import 'package:path/path.dart' as p;

/// Runs a shell command through cmd.exe on Windows, bash on Linux/macOS.
Future<int> run(
  String command, {
  String? workingDirectory,
}) async {
  print('  > $command');
  final process = await Process.start(
    Platform.isWindows ? 'cmd.exe' : 'bash',
    Platform.isWindows ? ['/c', command] : ['-c', command],
    workingDirectory: workingDirectory,
    includeParentEnvironment: true,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

void copyDirectory(Directory source, Directory destination) {
  if (!destination.existsSync()) destination.createSync(recursive: true);
  for (var entity in source.listSync()) {
    if (entity is Directory) {
      copyDirectory(
        entity,
        Directory(p.join(destination.path, p.basename(entity.path))),
      );
    } else if (entity is File) {
      entity.copySync(p.join(destination.path, p.basename(entity.path)));
    }
  }
}

/// Searches recursively under [intermediatesRoot] for libllama.so
/// in any arm64-v8a subdirectory, preferring release builds.
String? findAndroidSo(String exampleRoot) {
  final knownPaths = [
    p.join(exampleRoot, 'build', 'app', 'intermediates', 'merged_native_libs',
        'release', 'mergeReleaseNativeLibs', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
    p.join(exampleRoot, 'build', 'app', 'intermediates', 'merged_native_libs',
        'release', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
    p.join(exampleRoot, 'build', 'app', 'intermediates', 'stripped_native_libs',
        'release', 'stripReleaseDebugSymbols', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
    p.join(exampleRoot, 'build', 'app', 'intermediates', 'stripped_native_libs',
        'release', 'out', 'lib', 'arm64-v8a', 'libllama.so'),
  ];
  for (final c in knownPaths) {
    if (File(c).existsSync()) return c;
  }
  final intermediates = Directory(
      p.join(exampleRoot, 'build', 'app', 'intermediates'));
  if (!intermediates.existsSync()) return null;
  try {
    for (final entity in intermediates.listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('libllama.so') &&
          entity.path.contains('arm64-v8a') &&
          entity.path.contains('release')) {
        return entity.path;
      }
    }
  } catch (_) {}
  return null;
}

void main() async {
  final root = p.dirname(p.dirname(Platform.script.toFilePath()));
  print('🚀 Starting Denizen AI Binary compilation and packaging...');
  print('   Working root: $root\n');

  // 1. Expected binary locations
  final windowsDll = p.join(
      root, 'example', 'build', 'windows', 'x64', 'runner', 'Release', 'llama.dll');

  // 2. Clear stale binary outputs & kill lingering MSBuild process locks
  print('🧹 Clearing stale build outputs...');
  if (Platform.isWindows) {
    await Process.run('cmd.exe', ['/c', 'taskkill /F /IM MSBuild.exe /T 2>nul']);
    await Process.run('cmd.exe', ['/c', 'taskkill /F /IM cl.exe /T 2>nul']);
  }

  final staleAndroid = findAndroidSo(p.join(root, 'example'));
  if (staleAndroid != null) {
    try { File(staleAndroid).deleteSync(); } catch (_) {}
  }
  if (File(windowsDll).existsSync()) {
    try { File(windowsDll).deleteSync(); } catch (_) {}
  }

  // 3. Build Android release binaries
  print('📱 Building Android release binaries...');
  final androidExit = await run(
    'flutter build apk --release',
    workingDirectory: p.join(root, 'example'),
  );
  if (androidExit != 0) {
    print('⚠️  Android build exited with code $androidExit — binary may be missing.');
  }

  // 4. Build Windows release binaries (Windows host only)
  if (Platform.isWindows) {
    print('💻 Building Windows release binaries...');
    final winExit = await run(
      'flutter build windows --release',
      workingDirectory: p.join(root, 'example'),
    );
    if (winExit != 0) {
      print('⚠️  Windows build exited with code $winExit — binary may be missing.');
    }
  }

  // 5. Locate produced binaries
  final androidSo = findAndroidSo(p.join(root, 'example'));
  final androidOk = androidSo != null;
  final windowsOk = File(windowsDll).existsSync();

  if (androidOk) print('✅ Android binary found: $androidSo');
  if (!androidOk) print('⚠️  Android binary (.so) not found — bundle will skip native Android support.');
  if (windowsOk) print('✅ Windows binary found: $windowsDll');
  if (!windowsOk && Platform.isWindows) {
    print('⚠️  Windows binary (.dll) not found — bundle will skip native Windows support.');
  }

  // 6. Create clean release packaging directory
  print('\n📦 Packaging clean release distribution...');
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
      print('❌ Expected source path not found: $path');
      print('   Make sure you run this script from the repo root.');
      exit(1);
    }
  }

  // 8. Copy core SDK (Dart only — no C++ files)
  print('✂️  Stripping C++ source and copying clean Dart files...');
  copyDirectory(
    Directory(p.join(root, 'lib')),
    Directory(p.join(releaseDir, 'lib')),
  );
  File(p.join(root, 'pubspec.yaml')).copySync(p.join(releaseDir, 'pubspec.yaml'));
  File(p.join(root, 'README.md')).copySync(p.join(releaseDir, 'README.md'));

  // 9. Copy llama_flutter_android Dart wrapper (no C++ source)
  final destWrapper =
      p.join(releaseDir, 'packages', 'llama_flutter_android');
  copyDirectory(
    Directory(p.join(root, 'packages', 'llama_flutter_android', 'lib')),
    Directory(p.join(destWrapper, 'lib')),
  );
  copyDirectory(
    Directory(p.join(
        root, 'packages', 'llama_flutter_android', 'android', 'src', 'main', 'kotlin')),
    Directory(p.join(destWrapper, 'android', 'src', 'main', 'kotlin')),
  );
  File(p.join(root, 'packages', 'llama_flutter_android', 'pubspec.yaml'))
      .copySync(p.join(destWrapper, 'pubspec.yaml'));

  // 10. Copy compiled binaries into release bundle
  if (androidOk) {
    final jniDir =
        Directory(p.join(destWrapper, 'android', 'src', 'main', 'jniLibs', 'arm64-v8a'))
          ..createSync(recursive: true);
    File(androidSo).copySync(p.join(jniDir.path, 'libllama.so'));
    print('✅ Copied Android release binary (.so)');
  }
  if (windowsOk) {
    final winDir = Directory(p.join(destWrapper, 'windows'))
      ..createSync(recursive: true);
    File(windowsDll).copySync(p.join(winDir.path, 'llama.dll'));
    print('✅ Copied Windows release binary (.dll)');
  }

  // 11. Write release-mode build.gradle.kts (uses jniLibs, strips CMake)
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
''');

  print('\n✅ Release bundle created at: $releaseDir');
  print('   Android: ${androidOk ? "✅ included" : "⚠️  not included (build failed)"}');
  print('   Windows: ${windowsOk ? "✅ included" : "⚠️  not included (build failed)"}');
  print('\nZip the release_bundle/ directory and distribute — no C++ source code exposed!');
}
