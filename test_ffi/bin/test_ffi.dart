import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// FFI signatures
typedef InitializeAudioEngineFunc = Int32 Function();
typedef CleanupAudioEngineFunc = Int32 Function();
typedef GetLastErrorMessageFunc = Pointer<Utf8> Function();
typedef FreeStringFunc = Void Function(Pointer<Utf8>);

// Dart signatures
typedef InitializeAudioEngineFuncDart = int Function();
typedef CleanupAudioEngineFuncDart = int Function();
typedef GetLastErrorMessageFuncDart = Pointer<Utf8> Function();
typedef FreeStringFuncDart = void Function(Pointer<Utf8>);

void main() {
  // Load the dynamic library
  final libraryPath = _getLibraryPath();
  print('Loading library from: $libraryPath');
  
  final dylib = DynamicLibrary.open(libraryPath);
  
  // Look up the C functions
  final initializeAudioEngine = dylib
      .lookupFunction<InitializeAudioEngineFunc, InitializeAudioEngineFuncDart>(
          'initialize_audio_engine');
  
  final cleanupAudioEngine = dylib
      .lookupFunction<CleanupAudioEngineFunc, CleanupAudioEngineFuncDart>(
          'cleanup_audio_engine');
  
  final getLastErrorMessage = dylib
      .lookupFunction<GetLastErrorMessageFunc, GetLastErrorMessageFuncDart>(
          'get_last_error_message');
  
  final freeString = dylib
      .lookupFunction<FreeStringFunc, FreeStringFuncDart>(
          'free_string');
  
  // Test the functions
  print('Initializing audio engine...');
  final initResult = initializeAudioEngine();
  print('Initialize result: $initResult');
  
  if (initResult != 0) {
    final errorMessagePointer = getLastErrorMessage();
    final errorMessage = errorMessagePointer.toDartString();
    print('Error message: $errorMessage');
    freeString(errorMessagePointer);
  }
  
  print('Cleaning up audio engine...');
  final cleanupResult = cleanupAudioEngine();
  print('Cleanup result: $cleanupResult');
  
  print('FFI test completed');
}

String _getLibraryPath() {
  // Check for environment variable first
  final envPath = Platform.environment['RUST_CORE_LIB_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    return envPath;
  }

  final String fileName;
  if (Platform.isWindows) {
    fileName = 'rust_core.dll';
  } else if (Platform.isMacOS) {
    fileName = 'librust_core.dylib';
  } else {
    fileName = 'librust_core.so';
  }

  // Try from test_ffi directory first (when running from test_ffi/)
  var libPath = '${Directory.current.path}/../rust_core/target/release/$fileName';
  if (File(libPath).existsSync()) {
    return libPath;
  }

  // Try from repo root (when running from project root)
  libPath = '${Directory.current.path}/rust_core/target/release/$fileName';
  if (File(libPath).existsSync()) {
    return libPath;
  }

  // Default to relative path from test_ffi directory
  return '${Directory.current.path}/../rust_core/target/release/$fileName';
}