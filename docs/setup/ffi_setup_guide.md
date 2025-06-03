# Manual FFI Environment and Project Setup Guide

This guide outlines the necessary steps to configure your environment and the MidiStems project for manual Foreign Function Interface (FFI) integration between Dart/Flutter and Rust. This is necessary if automated tools like `flutter_rust_bridge` cannot be used due to environmental constraints (e.g., Rust version).

**Goal:** Create an environment where `flutter run` and `dart path/to/script.dart` can execute successfully, and where a Rust `cdylib` (dynamic C library) can be compiled, linked, and called from Dart.

---

**A. Flutter & Dart SDK Installation and Configuration:**

1.  **Install Flutter SDK:**
    *   Follow the official Flutter installation guide for your operating system (Windows, macOS, Linux): [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
    *   Ensure the Flutter SDK `bin` directory is added to your system's `PATH` environment variable.
    *   Verify installation by running `flutter doctor` in your terminal. Address any issues it reports. This command will also help identify if necessary build tools for your OS (like Visual Studio for Windows, Xcode for macOS, or build-essentials for Linux) are present.

2.  **Dart SDK (usually comes with Flutter):**
    *   The Dart SDK is bundled with Flutter. Once `flutter doctor` is happy, the `dart` command should also be available in your `PATH`.
    *   Verify by running `dart --version`.

---

**B. Rust Development Environment:**

1.  **Install Rust:**
    *   Follow the official Rust installation guide: [https://www.rust-lang.org/tools/install](https://www.rust-lang.org/tools/install)
    *   Ensure `cargo` (Rust's package manager and build tool) and `rustc` (Rust compiler) are in your `PATH`.
    *   Verify by running `cargo --version` and `rustc --version`.
    *   The environment this plan was based on had Rust 1.75.0. While later versions are generally fine, ensure your version is compatible with any specific needs if issues arise.

2.  **Setup Rust Library for C-Dynamic Library (cdylib):**
    *   A Rust library crate (e.g., named `rust_core`) will be created (or already exists) in the project.
    *   In its `Cargo.toml` file (e.g., `rust_core/Cargo.toml`), ensure the library type is set to `cdylib` to produce a C-compatible dynamic library:
        ```toml
        [lib]
        crate-type = ["cdylib"]
        ```
    *   Rust functions intended to be called from Dart via FFI must be defined in `rust_core/src/lib.rs` (or modules it includes) using `pub extern "C" fn func_name(...) -> ...` and marked with `#[no_mangle]`.

---

**C. Project Configuration for Manual FFI:**

1.  **Flutter Project `pubspec.yaml`:**
    *   Ensure the `ffi` package is listed under `dependencies`. This package provides utilities for working with C types and memory in Dart.
        ```yaml
        dependencies:
          flutter:
            sdk: flutter
          ffi: ^2.1.0 # Or the latest compatible version
          # ... other dependencies
        ```
    *   After adding/modifying, run `flutter pub get` in your Flutter project root.

2.  **Dynamic Library Loading in Dart:**
    *   The Dart code responsible for FFI calls (e.g., a service class like `lib/rust_service.dart`) will need to load the compiled Rust dynamic library.
    *   The path used in `DynamicLibrary.open("path/to/your/rust_library")` is critical.
        *   **For Local Development/Testing:**
            *   After compiling the Rust library (e.g., `cargo build --release` in the `rust_core` directory), the dynamic library will be in `rust_core/target/release/` (e.g., `librust_core.so` on Linux, `rust_core.dll` on Windows, `librust_core.dylib` on macOS).
            *   For `dart path/to/test_script.dart`: The path in `DynamicLibrary.open()` must be correct relative to the script's execution location, or an absolute path.
            *   For `flutter run`:
                *   **Linux:** You might need to set the `LD_LIBRARY_PATH` environment variable to include the directory containing `librust_core.so`, or copy the `.so` file to a standard system library path, or more robustly, place it within the Flutter build structure (e.g., `linux/libs`) and adjust `linux/CMakeLists.txt` to find and bundle it.
                *   **Windows:** The `rust_core.dll` should ideally be placed alongside the Flutter executable that `flutter run` generates, or its directory needs to be in the system `PATH`. For bundling, you'd typically add it to the `windows/runner/CMakeLists.txt`.
                *   **macOS:** The `librust_core.dylib` needs to be locatable. This might involve setting `DYLD_FALLBACK_LIBRARY_PATH` for testing, or configuring the Xcode project (`macos/Runner.xcworkspace`) to embed the dylib within the app bundle (e.g., in the Frameworks directory).
        *   **For Production Bundling (Later Stage):** Proper bundling is essential. This involves modifying the platform-specific build configurations for your Flutter app:
            *   **Linux:** Edit `linux/CMakeLists.txt`. You might use `add_custom_command` or similar to ensure the Rust library is built and then `install(FILES ...)` to copy it into the bundle.
            *   **Windows:** Edit `windows/runner/CMakeLists.txt`. Similar to Linux, ensure the DLL is copied to the correct location in the output bundle.
            *   **macOS:** Edit the Xcode project settings (`macos/Runner.xcworkspace`) under "Build Phases" to add a phase to copy or embed the `.dylib` file into the app bundle.

---

**D. Testing the FFI Bridge (Once Environment & Basic Code is Ready):**

1.  **Compile the Rust Library:**
    *   Navigate to your Rust crate directory (e.g., `rust_core`).
    *   Run `cargo build` (for debug builds) or `cargo build --release` (for release builds).

2.  **Prepare Library for Dart/Flutter Access:**
    *   Based on your OS and whether you're running a Dart CLI script or Flutter app, ensure the compiled dynamic library from `rust_core/target/debug/` or `rust_core/target/release/` is accessible (see notes in C.2).

3.  **Run Dart CLI Test (If you create one for isolated FFI testing):**
    *   Example: `dart test/manual_ffi_test.dart`
    *   Verify successful execution, correct data passing, and no memory errors.

4.  **Run Flutter Application:**
    *   Example: `flutter run -d <your_platform>`
    *   Trigger the FFI calls from within your Flutter app.
    *   Verify functionality, performance, and absence of crashes or memory issues related to FFI. Use Flutter DevTools and platform-specific debugging tools as needed.

---

This checklist provides a starting point. Specific paths and build commands might need slight adjustments based on your exact project structure and operating system nuances. Refer to official Flutter and Rust FFI documentation for more detailed platform-specific guidance.