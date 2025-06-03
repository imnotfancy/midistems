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
  
  // Convert the result to a Dart string
  final result = resultPointer.toDartString();
  print('Audio system test result: $result');
  
  // Free the string allocated by Rust
  freeString(resultPointer);
  
  print('Audio test completed');
}

String _getLibraryPath() {
  // Get the path to the dynamic library
  final scriptDir = Directory.current.path;
  final isRelease = true; // Set to false for debug builds
  
  final libraryPath = path.normalize(path.join(
    scriptDir,
    '..',
    'rust_core',
    'target',
    isRelease ? 'release' : 'debug',
    _getLibraryFileName(),
  ));
  
  return libraryPath;
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