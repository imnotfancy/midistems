use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::process::Command;
use std::path::Path;
use serde::{Deserialize, Serialize};
use serde_json;

// TODO: PYTHON PATH CONFIGURATION
// The paths for the Python executable (e.g., "venv/bin/python") and the
// scripts ("python/midi_extractor.py", "python/processor.py") are currently
// hardcoded assuming a specific project structure and virtual environment.
// For robust deployment, these should be made configurable (e.g., via
// environment variables, a configuration file passed from Dart, or by
// discovering them relative to the main application executable).

// --- Structs for MIDI Extraction ---
#[derive(Deserialize, Debug)]
struct MidiExtractionResult {
    midi_path: Option<String>,
}

#[derive(Deserialize, Debug)]
struct MidiExtractionOutput { // Expected from python/midi_extractor.py
    status: String,
    result: Option<MidiExtractionResult>,
    error: Option<String>,
}

// --- Struct for Stem Separation Error JSON (used only by Rust for error reporting) ---
#[derive(Serialize, Debug)]
struct RustErrorOutput {
    status: String,
    error: String,
    result: Option<serde_json::Value>,
}


/// Frees a C string that was previously allocated by Rust and returned via FFI.
#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

fn make_internal_error_cstring(msg: &str) -> *mut c_char {
    eprintln!("Rust: Creating internal error CString: {}", msg); // Logging
    let error_json = RustErrorOutput {
        status: "error".to_string(),
        error: format!("Rust internal error: {}", msg),
        result: None,
    };
    let json_str = serde_json::to_string(&error_json).unwrap_or_else(|e_serialize| {
        eprintln!("Rust: Emergency fallback error serialization failed: {}", e_serialize);
        "{\"status\":\"error\",\"error\":\"Rust: Emergency fallback error serialization failed.\"}"
            .to_string()
    });
    CString::new(json_str).unwrap_or_else(|e_cstring| {
        eprintln!("Rust: Error message contained null bytes during CString creation: {}", e_cstring);
        CString::new("{\"status\":\"error\",\"error\":\"Rust: Error message contained null bytes.\"}")
            .unwrap()
    }).into_raw()
}


/// Executes the python/midi_extractor.py script to extract MIDI from an audio file.
#[no_mangle]
pub extern "C" fn extract_midi(
    input_audio_path_ptr: *const c_char,
    output_midi_path_ptr: *const c_char,
) -> *mut c_char {
    let input_audio_path_str = unsafe {
        if input_audio_path_ptr.is_null() { return make_internal_error_cstring("Input audio path was null."); }
        match CStr::from_ptr(input_audio_path_ptr).to_str() {
            Ok(s) => s.to_string(),
            Err(e) => return make_internal_error_cstring(&format!("Invalid UTF-8 in input audio path: {}", e)),
        }
    };

    let output_midi_path_str = unsafe {
        if output_midi_path_ptr.is_null() { return make_internal_error_cstring("Output MIDI path was null."); }
        match CStr::from_ptr(output_midi_path_ptr).to_str() {
            Ok(s) => s.to_string(),
            Err(e) => return make_internal_error_cstring(&format!("Invalid UTF-8 in output MIDI path: {}", e)),
        }
    };

    let python_executable = if cfg!(target_os = "windows") { "venv/Scripts/python.exe" } else { "venv/bin/python" };
    let script_path = "python/midi_extractor.py";

    if !Path::new(python_executable).exists() { return make_internal_error_cstring(&format!("Python executable not found at: {}. Ensure venv.", python_executable)); }
    if !Path::new(script_path).exists() { return make_internal_error_cstring(&format!("Python script not found at: {}", script_path)); }

    let input_arg = format!("input_path={}", input_audio_path_str);
    let output_arg = format!("output_path={}", output_midi_path_str);

    eprintln!("Rust: Attempting to execute Python command for MIDI extraction: {} {} extract_midi {} {}",
        python_executable, script_path, input_arg, output_arg);

    let command_output = Command::new(python_executable)
        .arg(script_path)
        .arg("extract_midi")
        .arg(&input_arg)
        .arg(&output_arg)
        .output();

    match command_output {
        Ok(output) => {
            let stdout_str = String::from_utf8_lossy(&output.stdout);
            let stderr_str = String::from_utf8_lossy(&output.stderr);
            eprintln!("Rust: MIDI extraction Python script executed. Status: {}. Stdout: [{}]. Stderr: [{}]",
                output.status, stdout_str, stderr_str);

            if output.status.success() {
                // Python script itself should return JSON that might indicate success or error within JSON
                // We just pass this JSON along.
                match CString::new(stdout_str.into_owned()) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(e) => make_internal_error_cstring(&format!("Python script output (stdout for MIDI) contained null bytes: {}", e)),
                }
            } else {
                // Script execution failed (non-zero exit code from Python process)
                let error_json = RustErrorOutput {
                    status: "error".to_string(),
                    error: format!("Rust: Python script for MIDI extraction failed. Status: {}. Stderr: [{}]. Stdout: [{}]", output.status, stderr_str, stdout_str),
                    result: None,
                };
                let json_str = serde_json::to_string(&error_json).unwrap_or_else(|e_serialize| {
                    eprintln!("Rust: Stderr serialization failed for MIDI extraction: {}", e_serialize);
                     "{\"status\":\"error\",\"error\":\"Rust: Stderr serialization failed.\"}"
                        .to_string()
                });
                CString::new(json_str).unwrap_or_else(|e_cstring|{
                    eprintln!("Rust: Stderr message contained null bytes for MIDI extraction: {}", e_cstring);
                    CString::new("{\"status\":\"error\",\"error\":\"Rust: Stderr message contained null bytes.\"}")
                        .unwrap()
                }).into_raw()
            }
        }
        Err(e) => {
            eprintln!("Rust: Failed to execute Python command for MIDI extraction: {}", e);
            make_internal_error_cstring(&format!("Failed to execute Python command for MIDI extraction: {}", e))
        }
    }
}

/// Executes the python/processor.py script to separate stems from an audio file.
#[no_mangle]
pub extern "C" fn separate_stems_ffi(
    input_audio_path_ptr: *const c_char,
    output_dir_ptr: *const c_char,
) -> *mut c_char {
    let input_audio_path_str = unsafe {
        if input_audio_path_ptr.is_null() { return make_internal_error_cstring("Input audio path was null for stem separation.");}
        match CStr::from_ptr(input_audio_path_ptr).to_str() {
            Ok(s) => s.to_string(),
            Err(e) => return make_internal_error_cstring(&format!("Invalid UTF-8 in input audio path for stem separation: {}", e)),
        }
    };

    let output_dir_str = unsafe {
        if output_dir_ptr.is_null() { return make_internal_error_cstring("Output directory path was null for stem separation."); }
        match CStr::from_ptr(output_dir_ptr).to_str() {
            Ok(s) => s.to_string(),
            Err(e) => return make_internal_error_cstring(&format!("Invalid UTF-8 in output directory path for stem separation: {}", e)),
        }
    };

    let python_executable = if cfg!(target_os = "windows") { "venv/Scripts/python.exe" } else { "venv/bin/python" };
    let script_path = "python/processor.py";

    if !Path::new(python_executable).exists() { return make_internal_error_cstring(&format!("Python executable not found at: {}. Ensure venv.", python_executable)); }
    if !Path::new(script_path).exists() { return make_internal_error_cstring(&format!("Python script for stem separation not found at: {}", script_path)); }

    let input_arg = format!("input_path={}", input_audio_path_str);
    let output_dir_arg = format!("output_dir={}", output_dir_str);

    eprintln!("Rust: Attempting to execute Python command for stem separation: {} {} separate_stems {} {}",
        python_executable, script_path, input_arg, output_dir_arg);

    let command_output = Command::new(python_executable)
        .arg(script_path)
        .arg("separate_stems")
        .arg(&input_arg)
        .arg(&output_dir_arg)
        .output();

    match command_output {
        Ok(output) => {
            let stdout_str = String::from_utf8_lossy(&output.stdout);
            let stderr_str = String::from_utf8_lossy(&output.stderr);
            eprintln!("Rust: Stem separation Python script executed. Status: {}. Stdout: [{}]. Stderr: [{}]",
                output.status, stdout_str, stderr_str);

            if output.status.success() {
                match CString::new(stdout_str.into_owned()) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(e) => make_internal_error_cstring(&format!("Python script output (stdout for stems) contained null bytes: {}", e)),
                }
            } else {
                let error_payload = RustErrorOutput {
                    status: "error".to_string(),
                    error: format!(
                        "Rust: Python script for stem separation failed. Status: {}. Stdout: [{}], Stderr: [{}]",
                        output.status, stdout_str, stderr_str
                    ),
                    result: None,
                };
                let json_err_str = serde_json::to_string(&error_payload).unwrap_or_else(|e_serialize| {
                    eprintln!("Rust: Critical error serializing Python execution failure (stems): {}", e_serialize);
                    "{\"status\":\"error\",\"error\":\"Rust: Critical error serializing Python execution failure details.\"}"
                        .to_string()
                });
                CString::new(json_err_str).unwrap_or_else(|e_cstring|{
                     eprintln!("Rust: Error message contained null bytes after script failure (stems): {}", e_cstring);
                    CString::new("{\"status\":\"error\",\"error\":\"Rust: Error message itself contained null bytes after script failure.\"}")
                        .unwrap()
                }).into_raw()
            }
        }
        Err(e) => {
            eprintln!("Rust: Failed to execute Python command for stem separation: {}", e);
            make_internal_error_cstring(&format!("Failed to execute Python command for stem separation: {}", e))
        }
    }
}
