use std::env;

/// Build script entry point that emits Cargo directives for platform-specific linking and rebuild triggers.
///
/// Determines the target OS from the `CARGO_CFG_TARGET_OS` environment variable (defaults to `"unknown"`).
/// - On Linux: links dynamically with `asound` (ALSA) and `stdc++`.
/// - On macOS: links the `CoreAudio` and `AudioToolbox` frameworks and `c++`.
/// - On Windows: no additional link directives are emitted.
/// - On unknown targets: emits a `cargo:warning` containing the detected target OS.
///
/// Always emits `cargo:rerun-if-changed` directives for `src/lib.rs`, `src/audio_io.rs`, `src/dsp.rs`,
/// `src/midi.rs`, and `build.rs` so Cargo will rerun the build script when those files change.
///
/// # Examples
///
/// ```
/// // This function is intended to be run as a Cargo build script (build.rs).
/// // Running `main()` directly in tests has no practical effect, but is shown here for completeness.
/// fn run_build_script() {
///     build_rs::main();
/// }
/// ```
fn main() {
    // Get the target OS
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_else(|_| "unknown".to_string());
    
    // Platform-specific configurations
    match target_os.as_str() {
        "linux" => {
            // Link against ALSA on Linux
            println!("cargo:rustc-link-lib=dylib=asound");
            println!("cargo:rustc-link-lib=dylib=stdc++");
        },
        "macos" => {
            // macOS-specific configurations
            println!("cargo:rustc-link-lib=framework=CoreAudio");
            println!("cargo:rustc-link-lib=framework=AudioToolbox");
            println!("cargo:rustc-link-lib=dylib=c++");
        },
        "windows" => {
            // Windows-specific configurations
        },
        _ => {
            // Default case
            println!("cargo:warning=Building for an unknown platform: {}", target_os);
        }
    }
    
    // Rebuild if any of these files change
    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=src/audio_io.rs");
    println!("cargo:rerun-if-changed=src/dsp.rs");
    println!("cargo:rerun-if-changed=src/midi.rs");
    println!("cargo:rerun-if-changed=build.rs");
}