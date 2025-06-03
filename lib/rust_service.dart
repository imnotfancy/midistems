import 'dart:convert'; // For jsonDecode
import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart'; // For Utf8, toNativeUtf8, toDartString, calloc, and nullptr

// --- FFI Type Definitions ---
typedef _RustGreetNative = Pointer<Utf8> Function(Pointer<Utf8> name);
typedef _RustGreetDart = Pointer<Utf8> Function(Pointer<Utf8> name);

typedef _RustFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _RustFreeStringDart = void Function(Pointer<Utf8> ptr);

typedef _ExtractMidiNative = Pointer<Utf8> Function(
    Pointer<Utf8> inputAudioPath, Pointer<Utf8> outputMidiPath);
typedef _ExtractMidiDart = Pointer<Utf8> Function(
    Pointer<Utf8> inputAudioPath, Pointer<Utf8> outputMidiPath);

typedef _SeparateStemsNative = Pointer<Utf8> Function(
    Pointer<Utf8> inputAudioPath, Pointer<Utf8> outputDirPath);
typedef _SeparateStemsDart = Pointer<Utf8> Function(
    Pointer<Utf8> inputAudioPath, Pointer<Utf8> outputDirPath);


class RustService {
  static final RustService _instance = RustService._internal();
  factory RustService() => _instance;

  late DynamicLibrary _dylib;
  late _RustGreetDart _rustGreet;
  late _ExtractMidiDart _extractMidi;
  late _SeparateStemsDart _separateStemsFfi;
  late _RustFreeStringDart _freeRustString;

  Pointer<Utf8>? _lastGreetedPtr;

  RustService._internal() {
    try {
      _dylib = DynamicLibrary.open(_getDynamicLibraryPath());
      _rustGreet = _dylib.lookupFunction<_RustGreetNative, _RustGreetDart>('rust_greet');
      _extractMidi = _dylib.lookupFunction<_ExtractMidiNative, _ExtractMidiDart>('extract_midi');
      _separateStemsFfi = _dylib.lookupFunction<_SeparateStemsNative, _SeparateStemsDart>('separate_stems_ffi');
      _freeRustString = _dylib.lookupFunction<_RustFreeStringNative, _RustFreeStringDart>('rust_free_string');
      print("RustService: Dynamic library loaded and FFI functions looked up successfully.");
    } catch (e) {
      print("RustService: Error loading dynamic library or FFI functions: $e");
      rethrow;
    }
  }

  static String _getDynamicLibraryPath() {
    if (Platform.isMacOS || Platform.isIOS) return 'librust_core.dylib';
    if (Platform.isLinux || Platform.isAndroid) return 'librust_core.so';
    if (Platform.isWindows) return 'rust_core.dll';
    throw Exception('Unsupported platform for Rust FFI');
  }

  String callRustGreet(String name) {
    final namePtr = name.toNativeUtf8();
    final resultPtr = _rustGreet(namePtr);
    calloc.free(namePtr);
    if (resultPtr == nullptr) return "Error: rust_greet returned null pointer";
    disposeLastGreetedString();
    _lastGreetedPtr = resultPtr;
    return resultPtr.toDartString();
  }

  void disposeLastGreetedString() {
    if (_lastGreetedPtr != nullptr && _lastGreetedPtr != Pointer.fromAddress(0)) {
      _freeRustString(_lastGreetedPtr!);
      _lastGreetedPtr = nullptr;
    }
  }

  Future<String> extractMidi(String inputAudioPath, String outputMidiPath) async {
    final inputAudioPathPtr = inputAudioPath.toNativeUtf8();
    final outputMidiPathPtr = outputMidiPath.toNativeUtf8();
    Pointer<Utf8> resultPtr = nullptr;

    try {
      // CRITICAL TODO FOR UI RESPONSIVENESS:
      // This FFI call can be blocking. For a production app, run this in a separate
      // Isolate using Isolate.run() or compute() to prevent freezing the UI.
      resultPtr = _extractMidi(inputAudioPathPtr, outputMidiPathPtr);
      if (resultPtr == nullptr) throw Exception("Rust extract_midi returned a null pointer.");

      final resultJsonString = resultPtr.toDartString();
      Map<String, dynamic> parsedJson;
      try {
        parsedJson = jsonDecode(resultJsonString);
      } catch (e) {
        throw Exception("Failed to parse JSON response from Rust (extract_midi): '$resultJsonString'. Error: $e");
      }

      if (parsedJson['status'] == 'error') {
        throw Exception("Error from Rust MIDI extraction: ${parsedJson['error'] ?? 'Unknown error'}");
      }
      if (parsedJson['status'] == 'success' && parsedJson['result']?['midi_path'] != null) {
        return parsedJson['result']['midi_path'];
      }
      throw Exception("Invalid JSON response from Rust extract_midi: $resultJsonString");
    } finally {
      calloc.free(inputAudioPathPtr);
      calloc.free(outputMidiPathPtr);
      if (resultPtr != nullptr && resultPtr != Pointer.fromAddress(0)) {
        _freeRustString(resultPtr);
      }
    }
  }

  Future<Map<String, dynamic>> separateStems(String inputAudioPath, String outputDirPath) async {
    final inputAudioPathPtr = inputAudioPath.toNativeUtf8();
    final outputDirPathPtr = outputDirPath.toNativeUtf8();
    Pointer<Utf8> resultJsonPtr = nullptr;

    try {
      // CRITICAL TODO FOR UI RESPONSIVENESS:
      // This FFI call can be blocking, especially for large audio files.
      // For a production app, run this in a separate Isolate using Isolate.run() or compute()
      // to prevent freezing the UI.
      resultJsonPtr = _separateStemsFfi(inputAudioPathPtr, outputDirPathPtr);

      if (resultJsonPtr == nullptr) {
        throw Exception("Rust separate_stems_ffi returned a null pointer.");
      }

      final resultJsonString = resultJsonPtr.toDartString();
      Map<String, dynamic> parsedJson;
      try {
        parsedJson = jsonDecode(resultJsonString);
      } catch (e) {
        throw Exception("Failed to parse JSON response from Rust (separate_stems): '$resultJsonString'. Error: $e");
      }

      if (parsedJson['status'] == 'error') {
        throw Exception("Error from Rust/Python stem separation: ${parsedJson['error'] ?? 'Unknown error'}");
      }

      if (parsedJson['status'] == 'success' && parsedJson['result'] != null) {
        if (parsedJson['result']['stems'] is Map) {
          return parsedJson['result'] as Map<String, dynamic>;
        } else {
          throw Exception("Stem separation successful, but 'stems' field is missing or not a map in the result.");
        }
      }
      throw Exception("Invalid or unexpected JSON response from Rust separate_stems_ffi: $resultJsonString");

    } finally {
      calloc.free(inputAudioPathPtr);
      calloc.free(outputDirPathPtr);
      if (resultJsonPtr != nullptr && resultJsonPtr != Pointer.fromAddress(0)) {
        _freeRustString(resultJsonPtr);
      }
    }
  }

  // --- Example Usage (for testing, can be removed or adapted) ---
  // ... (example methods remain unchanged) ...
  static void runGreetExample() {
    print("RustService: Running greet example...");
    final service = RustService();
    try {
      final message = service.callRustGreet("Flutter");
      print("RustService: Message from rust_greet: $message");
      service.disposeLastGreetedString();
      print("RustService: Greet example finished.");
    } catch (e) {
      print("RustService: Error in greet example: $e");
    }
  }

  static Future<void> runExtractMidiExample(String inputPath, String outputPath) async {
    print("RustService: Running extract_midi example...");
    final service = RustService();
    try {
      print("RustService: Calling extractMidi with input: '$inputPath', output: '$outputPath'");
      final midiPath = await service.extractMidi(inputPath, outputPath);
      print("RustService: MIDI extraction successful. Output MIDI path: $midiPath");
    } catch (e) {
      print("RustService: Error during MIDI extraction: $e");
    }
    print("RustService: Extract_midi example finished.");
  }

  static Future<void> runSeparateStemsExample(String inputPath, String outputDir) async {
    print("RustService: Running separate_stems example...");
    final service = RustService();
    try {
      print("RustService: Calling separateStems with input: '$inputPath', outputDir: '$outputDir'");
      final result = await service.separateStems(inputPath, outputDir);
      print("RustService: Stem separation successful. Result: $result");
    } catch (e) {
      print("RustService: Error during stem separation: $e");
    }
    print("RustService: Separate_stems example finished.");
  }
}
