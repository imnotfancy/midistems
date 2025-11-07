import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// FFI signature for the test_audio_system function
typedef TestAudioSystemFunc = Pointer<Utf8> Function();
typedef TestAudioSystemFuncDart = Pointer<Utf8> Function();

// FFI signature for the free_string function
typedef FreeStringFunc = Void Function(Pointer<Utf8>);
typedef FreeStringFuncDart = void Function(Pointer<Utf8>);

void main() {
  print('Testing audio system via FFI...');
  
  // Load the dynamic library
  final libraryPath = _getLibraryPath();
  print('Loading library from: $libraryPath');
  
  final dylib = DynamicLibrary.open(libraryPath);
  
  // Look up the test_audio_system function
  final testAudioSystem = dylib.lookupFunction<
    TestAudioSystemFunc,
    TestAudioSystemFuncDart
  >('test_audio_system');
  
  // Look up the free_string function
  final freeString = dylib.lookupFunction<
    FreeStringFunc,
    FreeStringFuncDart
  >('free_string');
  
  // Call the test_audio_system function
  final resultPointer = testAudioSystem();

  // Check for null pointer before dereferencing
  if (resultPointer == nullptr) {
    print('Error: Received null pointer from test_audio_system()');
    print('FFI call failed - the Rust function may have encountered an error');
    exit(1);
  }

  // Convert the result to a Dart string
  final result = resultPointer.toDartString();
  print('Audio system test result: $result');

  // Free the string allocated by Rust
  freeString(resultPointer);

  print('Audio test completed');
}

String _getLibraryPath() {
  // Check for environment variable first
  final envPath = Platform.environment['RUST_CORE_LIB_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    return envPath;
  }

  // Check BUILD_TYPE environment variable; default to release
  final isRelease = Platform.environment['BUILD_TYPE']?.toLowerCase() != 'debug';
  final buildType = isRelease ? 'release' : 'debug';
  final fileName = _getLibraryFileName();

  // Try from test_ffi directory first (when running from test_ffi/)
  var libPath = path.normalize(path.join(
    Directory.current.path,
    '..',
    'rust_core',
    'target',
    buildType,
    fileName,
  ));
  if (File(libPath).existsSync()) {
    return libPath;
  }

  // Try from repo root (when running from project root)
  libPath = path.normalize(path.join(
    Directory.current.path,
    'rust_core',
    'target',
    buildType,
    fileName,
  ));
  if (File(libPath).existsSync()) {
    return libPath;
  }

  // Default to relative path from test_ffi directory
  return path.normalize(path.join(
    Directory.current.path,
    '..',
    'rust_core',
    'target',
    buildType,
    fileName,
  ));
}

String _getLibraryFileName() {
  if (Platform.isWindows) {
    return 'rust_core.dll';
  } else if (Platform.isMacOS) {
    return 'librust_core.dylib';
  } else {
    return 'librust_core.so';
  }
}