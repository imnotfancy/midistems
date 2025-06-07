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
  late final void Function(Pointer<Float> buffer, int length) _freeStemMemory;

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

    _freeStemMemory = _lib
        .lookup<NativeFunction<Void Function(Pointer<Float>, IntPtr)>>('free_stem_memory')
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

  /// Separate audio into stems
  ///
  /// Returns a list of stems (each a List<double>) or null on failure.
  Future<List<List<double>>?> separateStems(List<double> inputAudioData) async {
    const numStems = 4; // Rust side currently expects 4 stems

    Pointer<Float> inputBuffer = calloc<Float>(inputAudioData.length);
    Pointer<Pointer<Float>> outputBuffers = calloc<Pointer<Float>>(numStems);
    Pointer<IntPtr> outputLengths = calloc<IntPtr>(numStems);

    try {
      // Copy input data to native buffer
      for (int i = 0; i < inputAudioData.length; i++) {
        inputBuffer[i] = inputAudioData[i];
      }

      final result = _separateStems(
        inputBuffer,
        inputAudioData.length,
        outputBuffers,
        outputLengths,
        numStems,
      );

      if (result == RustAudioService.success) {
        final List<List<double>> stems = [];
        for (int i = 0; i < numStems; i++) {
          final stemPtr = outputBuffers[i];
          final stemLen = outputLengths[i];

          if (stemPtr == nullptr) {
            // This case should ideally not happen if Rust side is correct
            // and num_stems matches, but good for robustness.
            print("Error: Received null pointer for stem $i from Rust.");
            // Free any previously processed stems if necessary, though current loop structure
            // frees them one by one. If one stem is null, others might still need freeing.
            // For simplicity here, we'll rely on the finally block to clean up Dart allocations.
            // Rust-side allocations for prior valid stems should have been freed.
            // Consider more granular error handling if this becomes an issue.
            throw Exception("Null pointer for stem $i received from Rust");
          }

          final List<double> currentStem = List.filled(stemLen, 0.0);
          for (int j = 0; j < stemLen; j++) {
            currentStem[j] = stemPtr[j];
          }
          stems.add(currentStem);

          // IMPORTANT: Free the memory for this individual stem now that we've copied it.
          _freeStemMemory(stemPtr, stemLen);
          // Mark the pointer as freed in the outputBuffers array to avoid double free in case of error later
          // though the current structure makes this less critical as we'd bail out.
          outputBuffers[i] = nullptr;
        }
        return stems;
      } else {
        print('Rust separate_stems failed: ${getLastErrorMessage()}');
        return null;
      }
    } catch (e) {
      print('Error during separateStems: $e');
      // If an error occurred after some stems were processed and freed,
      // we need to ensure remaining Rust buffers (if any were populated and not yet freed)
      // are handled. However, the current loop frees them one by one.
      // If an error happens mid-loop (e.g., during currentStem[j] = stemPtr[j]),
      // the specific stemPtr for that iteration won't be freed by _freeStemMemory.
      // This is a complex scenario. The `finally` block handles Dart memory.
      // Rust memory not yet explicitly freed by _freeStemMemory would leak if not handled.
      // For robustness, one might iterate outputBuffers in catch and free non-null pointers
      // if the design guaranteed they were valid at that point, or rely on process termination
      // for cleanup in severe error cases. Given the current structure, we assume _freeStemMemory
      // is called for successfully copied stems.
      return null;
    } finally {
      // Free Dart-allocated memory
      calloc.free(inputBuffer);

      // Free Rust-allocated memory for any stems that might not have been processed and freed
      // in the main loop due to an error *after* Rust returned SUCCESS but *before* all stems were copied.
      // This is a safeguard. If an error occurs *before* Rust returns SUCCESS, these pointers might not be valid.
      // If Rust returned SUCCESS, these pointers *should* be valid unless already freed.
      // The `outputBuffers[i] = nullptr;` line helps prevent double frees here if the loop completed.
      for (int i = 0; i < numStems; i++) {
        if (outputBuffers[i] != nullptr) {
          // This implies the loop didn't complete or an error occurred after Rust populated this stem
          // but before it was freed.
          print("Freeing potentially leaked Rust stem $i in finally block.");
          _freeStemMemory(outputBuffers[i], outputLengths[i]); // outputLengths[i] must be valid here
        }
      }
      calloc.free(outputBuffers);
      calloc.free(outputLengths);
    }
  }
}