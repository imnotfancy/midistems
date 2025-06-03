import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart'; // For Utf8, toNativeUtf8, toDartString, calloc

// Define FFI function signatures
typedef RustGreetNative = Pointer<Utf8> Function(Pointer<Utf8> name);
typedef RustGreetDart = Pointer<Utf8> Function(Pointer<Utf8> name);

typedef RustFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef RustFreeStringDart = void Function(Pointer<Utf8> ptr);

// Helper class to hold the result and the pointer to be freed
class GreetingResult {
  final String message;
  final Pointer<Utf8> rustStringPtr;

  GreetingResult(this.message, this.rustStringPtr);
}

void main() {
  print("Starting Dart FFI test script...");

  String libraryPath;
  if (Platform.isMacOS || Platform.isIOS) {
    libraryPath = '../target/release/librust_core.dylib'; // Path relative to this script
  } else if (Platform.isLinux || Platform.isAndroid) {
    libraryPath = '../target/release/librust_core.so'; // Path relative to this script
  } else if (Platform.isWindows) {
    libraryPath = '../target/release/rust_core.dll'; // Path relative to this script
  } else {
    print("Unsupported platform.");
    return;
  }

  print("Attempting to load library: $libraryPath");
  late DynamicLibrary dylib;
  try {
    dylib = DynamicLibrary.open(libraryPath);
    print("Library loaded successfully.");
  } catch (e) {
    print("Error loading dynamic library: $e");
    return;
  }

  print("Looking up FFI functions...");
  late RustGreetDart rustGreet;
  late RustFreeStringDart rustFreeString;

  try {
    rustGreet = dylib.lookupFunction<RustGreetNative, RustGreetDart>('rust_greet');
    rustFreeString = dylib.lookupFunction<RustFreeStringNative, RustFreeStringDart>('rust_free_string');
    print("FFI functions looked up successfully.");
  } catch (e) {
    print("Error looking up FFI functions: $e");
    return;
  }

  String nameToSend = "Dart CLI";
  print("Calling rust_greet with name: '$nameToSend'");

  Pointer<Utf8> namePtr = nullptr;
  Pointer<Utf8> resultPtr = nullptr;
  String greetingMessage = "";

  try {
    namePtr = nameToSend.toNativeUtf8();
    resultPtr = rustGreet(namePtr);

    if (resultPtr == nullptr) {
      print("Error: rust_greet returned a null pointer.");
    } else {
      greetingMessage = resultPtr.toDartString();
      print("Received greeting: '$greetingMessage'");
    }
  } catch (e) {
    print("Error calling rust_greet or processing its result: $e");
  } finally {
    if (namePtr != nullptr) {
      calloc.free(namePtr); // Free the input string pointer
      print("Freed input name CString.");
    }
  }

  if (resultPtr != nullptr && resultPtr != Pointer.fromAddress(0)) {
    print("Calling rust_free_string to free the returned string from Rust.");
    try {
      rustFreeString(resultPtr);
      print("Rust string pointer freed successfully.");
    } catch (e) {
      print("Error calling rust_free_string: $e");
    }
  } else {
    print("Skipping rust_free_string as result pointer was null or invalid.");
  }

  // Verification
  if (greetingMessage == "Hello, Dart CLI from Rust!") {
    print("SUCCESS: FFI call seems to have worked correctly!");
  } else {
    print("FAILURE: The received message was not as expected.");
    print("Expected: 'Hello, Dart CLI from Rust!', Got: '$greetingMessage'");
  }

  print("Dart FFI test script finished.");
}
