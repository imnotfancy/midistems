use std::ffi::{c_char, CStr, CString, NulError};
use std::os::raw::c_int;
use std::slice;
use std::cell::RefCell;

// Audio processing modules
mod audio_io;
mod dsp;
mod midi;

// Error codes
const SUCCESS: c_int = 0;
const ERROR_INVALID_INPUT: c_int = -1;
const ERROR_PROCESSING_FAILED: c_int = -2;
const ERROR_FILE_NOT_FOUND: c_int = -3;

// Thread-local storage for the last error message
thread_local! {
    static LAST_ERROR_MESSAGE: RefCell<Option<CString>> = RefCell::new(None);
}

// Helper function to set the last error message
// This is not exposed via FFI
fn set_last_error(message: String) {
    match CString::new(message.clone()) { // Clone message in case CString::new fails and we want to log original
        Ok(c_string) => {
            LAST_ERROR_MESSAGE.with(|cell| {
                *cell.borrow_mut() = Some(c_string);
            });
        }
        Err(e: NulError) => {
            // Handle cases where the message itself cannot be converted to CString (e.g., contains null bytes)
            // Log this internal error. For now, we'll print to stderr.
            // A more robust solution might involve a fallback error message.
            eprintln!("Error setting last_error: CString::new failed due to null byte in message: '{}'. Details: {}", message, e);
            // Optionally, set a generic error message indicating this failure
            let fallback_error = CString::new(format!("Internal error: Failed to create CString for error message due to: {}", e)).unwrap_or_else(|_| CString::new("Internal error: Malformed error message.").unwrap());
            LAST_ERROR_MESSAGE.with(|cell| {
                *cell.borrow_mut() = Some(fallback_error);
            });
        }
    }
}

/// Initialize the audio processing engine
/// 
/// # Safety
/// This function is unsafe because it's exposed via FFI
#[no_mangle]
pub extern "C" fn initialize_audio_engine() -> c_int {
    // In a real implementation, this would initialize audio devices,
    // allocate resources, etc.
    println!("Initializing Rust audio engine");
    SUCCESS
}

/// Load an audio file from the given path
/// 
use symphonia::core::codecs::DecoderOptions;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::default::get_probe;
use std::fs::File;

/// # Safety
/// This function is unsafe because it's exposed via FFI and dereferences raw pointers
#[no_mangle]
pub unsafe extern "C" fn load_audio_file(file_path: *const c_char) -> c_int {
    if file_path.is_null() {
        set_last_error("Input file_path was null.".to_string());
        return ERROR_INVALID_INPUT;
    }

    let file_path_str = match unsafe { CStr::from_ptr(file_path) }.to_str() {
        Ok(s) => s,
        Err(_) => {
            set_last_error("Failed to convert file_path to a valid UTF-8 string.".to_string());
            return ERROR_INVALID_INPUT;
        }
    };

    println!("Attempting to load audio file with Symphonia: {}", file_path_str);

    // Open the media source.
    let src = match File::open(file_path_str) {
        Ok(file) => file,
        Err(e) => {
            set_last_error(format!("Failed to open file '{}': {}", file_path_str, e));
            return ERROR_FILE_NOT_FOUND;
        }
    };

    // Create the media source stream.
    let mss = MediaSourceStream::new(Box::new(src), Default::default());

    // Create a hint to help the probe.
    let mut hint = Hint::new();
    // Provide the file extension as a hint.
    if let Some(ext) = std::path::Path::new(file_path_str).extension().and_then(|s| s.to_str()) {
        hint.with_extension(ext);
    }
    
    // Set up format and metadata options.
    let format_opts: FormatOptions = Default::default();
    let metadata_opts: MetadataOptions = Default::default();
    // We don't need to decode actual packets for this basic version, so DecoderOptions is not strictly needed here
    // let decoder_opts: DecoderOptions = Default::default();

    // Probe theG media source.
    match get_probe().format(&hint, mss, &format_opts, &metadata_opts) {
        Ok(probed) => {
            let mut format_reader = probed.format;

            // Get the default track.
            let track = match format_reader.default_track() {
                Some(track) => track,
                None => {
                    set_last_error(format!("No default audio track found in '{}'.", file_path_str));
                    return ERROR_PROCESSING_FAILED;
                }
            };

            // Print track codec parameters.
            let params = &track.codec_params;
            println!("Track Codec Parameters for '{}':", file_path_str);
            if let Some(sample_rate) = params.sample_rate {
                println!("  Sample Rate: {} Hz", sample_rate);
            } else {
                println!("  Sample Rate: Unknown");
            }
            if let Some(channels) = params.channels {
                println!("  Channels: {}", channels);
            } else {
                println!("  Channels: Unknown");
            }
            if let Some(n_frames) = params.n_frames {
                if let Some(time_base) = params.time_base {
                    let duration_seconds = (n_frames as f64 * time_base.numer as f64) / time_base.denom as f64;
                    println!("  Duration: {:.2} seconds ({} frames)", duration_seconds, n_frames);
                } else {
                    println!("  Frames: {} (time_base unknown, cannot calculate duration)", n_frames);
                }
            } else {
                println!("  Duration: Unknown (n_frames not available)");
            }

            // In a real implementation, you might store the format_reader or decoded audio.
            // For now, just printing info is enough.
            println!("Successfully probed and read metadata from '{}'", file_path_str);
            SUCCESS
        }
        Err(err) => {
            set_last_error(format!("Failed to probe audio format for '{}': {}", file_path_str, err));
            ERROR_PROCESSING_FAILED
        }
    }
}

/// Process audio data to separate stems
/// 
/// # Safety
/// This function is unsafe because it's exposed via FFI and dereferences raw pointers
#[no_mangle]
pub unsafe extern "C" fn separate_stems(
    input_buffer: *const f32,
    input_length: usize,
    output_buffers: *mut *mut f32,
    output_lengths: *mut usize,
    num_stems: usize
) -> c_int {
    if input_buffer.is_null() || output_buffers.is_null() || output_lengths.is_null() || num_stems == 0 {
        return ERROR_INVALID_INPUT;
    }
    
    // Unsafe block for dereferencing raw pointers
    unsafe {
        let _input_slice = slice::from_raw_parts(input_buffer, input_length);
        
        println!("Processing audio data with {} samples into {} stems", input_length, num_stems);
    }
    
    // In a real implementation, this would perform stem separation
    // using DSP algorithms or machine learning models
    SUCCESS
}

/// Extract MIDI data from audio
/// 
/// # Safety
/// This function is unsafe because it's exposed via FFI and dereferences raw pointers
#[no_mangle]
pub unsafe extern "C" fn extract_midi(
    input_buffer: *const f32,
    input_length: usize,
    output_path: *const c_char
) -> c_int {
    if input_buffer.is_null() || output_path.is_null() {
        return ERROR_INVALID_INPUT;
    }
    
    // Unsafe block for dereferencing raw pointers
    unsafe {
        let _input_slice = slice::from_raw_parts(input_buffer, input_length);
        
        let c_str = CStr::from_ptr(output_path);
        let output_path_str = match c_str.to_str() {
            Ok(s) => s,
            Err(_) => return ERROR_INVALID_INPUT,
        };
        
        println!("Extracting MIDI from {} samples to {}", input_length, output_path_str);
    }
    
    // In a real implementation, this would perform pitch detection
    // and MIDI extraction using DSP algorithms
    SUCCESS
}

/// Clean up resources used by the audio engine
/// 
/// # Safety
/// This function is unsafe because it's exposed via FFI
#[no_mangle]
pub extern "C" fn cleanup_audio_engine() -> c_int {
    // In a real implementation, this would free resources,
    // close audio devices, etc.
    // For now, just a print statement.
    println!("Rust audio engine cleanup called. Future resource deallocation here.");
    // Conceptually, if LAST_ERROR_MESSAGE or other thread-locals held significant resources
    // that needed explicit cleanup beyond dropping, this could be a place.
    // However, for Option<CString>, drop is usually sufficient.
    SUCCESS
}

/// Test the audio system
/// 
/// # Safety
/// This function is unsafe because it's exposed via FFI and returns a raw pointer
#[no_mangle]
pub extern "C" fn test_audio_system() -> *const c_char {
    match audio_io::test_audio_system() {
        Ok(message) => {
            let c_string = CString::new(message).unwrap_or_else(|_| {
                CString::new("Error converting result to C string").unwrap()
            });
            c_string.into_raw()
        },
        Err(error) => {
            let error_message = format!("Audio system test failed: {}", error);
            let c_string = CString::new(error_message).unwrap_or_else(|_| {
                CString::new("Error converting error message to C string").unwrap()
            });
            c_string.into_raw()
        }
    }
}

/// Get the last error message
/// 
/// # Safety
/// This function is unsafe because it's exposed via FFI and returns a raw pointer
#[no_mangle]
pub extern "C" fn get_last_error_message() -> *const c_char {
    LAST_ERROR_MESSAGE.with(|cell| {
        if let Some(c_string) = cell.borrow_mut().take() {
            // Transfer ownership to the C caller
            c_string.into_raw()
        } else {
            // No error was set, or it was already retrieved
            CString::new("No error").unwrap_or_else(|_| {
                // This should ideally not fail for "No error"
                CString::new("Fallback: No error message available and 'No error' failed to convert.").unwrap()
            }).into_raw()
        }
    })
}

/// Free a string allocated by the Rust library
/// 
/// # Safety
/// This function is unsafe because it's exposed via FFI and dereferences raw pointers
#[no_mangle]
pub unsafe extern "C" fn free_string(string: *mut c_char) {
    if !string.is_null() {
        // Unsafe block for dereferencing raw pointers
        unsafe {
            let _ = CString::from_raw(string);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_initialize_audio_engine() {
        let result = initialize_audio_engine();
        assert_eq!(result, SUCCESS);
    }
}
