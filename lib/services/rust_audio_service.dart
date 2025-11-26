import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

/// A service that provides access to the Rust audio processing library.
class RustAudioService {
  static const String _libName = 'rust_core';
  static late final DynamicLibrary _lib;
  static late final RustAudioService _instance;

  // FFI function signatures
  late final int Function() _initializeAudioEngine;
  late final int Function(Pointer<Utf8>) _loadAudioFile;
  late final int Function(
      Pointer<Float>, int, Pointer<Pointer<Float>>, Pointer<IntPtr>, int) _separateStems;
  late final int Function(Pointer<Float>, int, Pointer<Utf8>) _extractMidi;
  late final int Function() _cleanupAudioEngine;
  late final Pointer<Utf8> Function() _getLastErrorMessage;
  late final Pointer<Utf8> Function() _testAudioSystem;
  late final void Function(Pointer<Utf8>) _freeString;

  // Error codes
  static const int success = 0;
  static const int errorInvalidInput = -1;
  static const int errorProcessingFailed = -2;
  static const int errorFileNotFound = -3;

  /// Private constructor to enforce singleton pattern
  RustAudioService._() {
    _loadLibrary();
    _loadFunctions();
  }

  /// Get the singleton instance of the service
  factory RustAudioService() {
    _instance = RustAudioService._();
    return _instance;
  }

  /// Load the Rust dynamic library
  void _loadLibrary() {
    final libraryPath = _getLibraryPath();
    try {
      _lib = DynamicLibrary.open(libraryPath);
      print('Loaded Rust library from: $libraryPath');
    } catch (e) {
      print('Failed to load Rust library: $e');
      rethrow;
    }
  }

  /// Get the path to the Rust dynamic library
  String _getLibraryPath() {
    // This is a simplified version - in a real app, you'd need more robust path handling
    // based on the platform and whether you're in development or production
    
    if (Platform.isWindows) {
      return path.join(Directory.current.path, 'rust_core', 'target', 'release', 'rust_core.dll');
    } else if (Platform.isMacOS) {
      return path.join(Directory.current.path, 'rust_core', 'target', 'release', 'librust_core.dylib');
    } else {
      return path.join(Directory.current.path, 'rust_core', 'target', 'release', 'librust_core.so');
    }
  }

  /// Load function pointers from the dynamic library
  void _loadFunctions() {
    _initializeAudioEngine = _lib
        .lookup<NativeFunction<Int32 Function()>>('initialize_audio_engine')
        .asFunction();

    _loadAudioFile = _lib
        .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('load_audio_file')
        .asFunction();

    _separateStems = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Float>, IntPtr, Pointer<Pointer<Float>>,
                    Pointer<IntPtr>, IntPtr)>>('separate_stems')
        .asFunction();

    _extractMidi = _lib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Float>, IntPtr,
                    Pointer<Utf8>)>>('extract_midi')
        .asFunction();

    _cleanupAudioEngine = _lib
        .lookup<NativeFunction<Int32 Function()>>('cleanup_audio_engine')
        .asFunction();

    _getLastErrorMessage = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function()>>(
            'get_last_error_message')
        .asFunction();
        
    _testAudioSystem = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function()>>(
            'test_audio_system')
        .asFunction();

    _freeString = _lib
        .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('free_string')
        .asFunction();
  }

  /// Initialize the audio processing engine
  bool initialize() {
    final result = _initializeAudioEngine();
    return result == success;
  }

  /// Load an audio file from the given path
  bool loadAudioFile(String filePath) {
    final filePathPointer = filePath.toNativeUtf8();
    try {
      final result = _loadAudioFile(filePathPointer);
      return result == success;
    } finally {
      calloc.free(filePathPointer);
    }
  }

  /// Extract MIDI data from audio
  bool extractMidi(List<double> audioData, String outputPath) {
    final audioBuffer = calloc<Float>(audioData.length);
    final outputPathPointer = outputPath.toNativeUtf8();
    
    try {
      // Copy audio data to native buffer
      for (var i = 0; i < audioData.length; i++) {
        audioBuffer[i] = audioData[i];
      }
      
      final result = _extractMidi(audioBuffer, audioData.length, outputPathPointer);
      return result == success;
    } finally {
      calloc.free(audioBuffer);
      calloc.free(outputPathPointer);
    }
  }

  /// Clean up resources used by the audio engine
  bool cleanup() {
    final result = _cleanupAudioEngine();
    return result == success;
  }

  /// Get the last error message
  String getLastErrorMessage() {
    final messagePointer = _getLastErrorMessage();
    final message = messagePointer.toDartString();
    _freeString(messagePointer);
    return message;
  }
  
  /// Test the audio system
  String testAudioSystem() {
    final resultPointer = _testAudioSystem();
    final result = resultPointer.toDartString();
    _freeString(resultPointer);
    return result;
  }
}