use std::env;

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