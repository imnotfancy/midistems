import os
import sys
import json
import numpy as np
import librosa
import pretty_midi
from basic_pitch.inference import predict_and_save
from basic_pitch import ICASSP_2022_MODEL_PATH
from basic_pitch import ICASSP_2022_MODEL_PATH

def log_info(message):
    """Log info message to stderr for Flutter to capture"""
    print(f"INFO: {message}", file=sys.stderr)

def extract_midi_from_audio(audio_path, output_path):
    """Extract MIDI data from audio file using Basic Pitch"""
    try:
        log_info(f"Loading audio file: {audio_path}")
        
        # Create output directory if it doesn't exist
        output_dir = os.path.dirname(output_path)
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            log_info(f"Created output directory: {output_dir}")

        # Use Basic Pitch's predict_and_save function
        log_info("Starting MIDI extraction...")
        predict_and_save(
            audio_path_list=[audio_path],  # List of audio files
            output_directory=output_dir,    # Output directory
            model_or_model_path=ICASSP_2022_MODEL_PATH,  # Model path
            minimum_note_length=0.05,
            minimum_frequency=20,
            maximum_frequency=2000,
            multiple_pitch_bends=False,
            melodia_trick=True,
            save_midi=True,
            sonify_midi=False,
            save_model_outputs=False,
            save_notes=False
        )

        # Get the generated MIDI file path
        midi_filename = os.path.splitext(os.path.basename(audio_path))[0] + '.mid'
        generated_midi_path = os.path.join(output_dir, midi_filename)

        # Move the file to the requested output path if different
        if generated_midi_path != output_path:
            os.rename(generated_midi_path, output_path)
            log_info(f"Moved MIDI file to requested location: {output_path}")

        # Load and validate the MIDI file
        midi_data = pretty_midi.PrettyMIDI(output_path)
        total_notes = sum(len(instrument.notes) for instrument in midi_data.instruments)
        
        log_info(f"Successfully generated MIDI file with {total_notes} notes")
        log_info(f"MIDI duration: {midi_data.get_end_time():.2f} seconds")
        
        # Return success response
        result = {
            "status": "success",
            "result": {
                "midi_path": output_path,
                "details": {
                    "num_notes": total_notes,
                    "duration": midi_data.get_end_time(),
                    "instruments": len(midi_data.instruments)
                }
            }
        }
        
        print(json.dumps(result))
        sys.exit(0) # Ensure exit 0 after successful JSON output
        
    except Exception as e:
        # Log error and return error response
        log_info(f"Error during MIDI extraction: {str(e)}")
        error_result = {
            "status": "error",
            "error": str(e)
        }
        try:
            print(json.dumps(error_result), file=sys.stdout)
            sys.exit(0) # Script ran and reported error correctly
        except Exception as e_json:
            log_info(f"Critical error: Failed to print JSON error to stdout: {str(e_json)}")
            sys.exit(1) # Error in error handling itself

def check_capabilities():
    """Check if all required libraries are available and print JSON to stdout"""
    try:
        # These imports are for checking, so we don't need to log them individually to stderr anymore
        # if Flutter/caller relies on stdout JSON.
        import torch
        import soundfile
        import tensorflow
        from basic_pitch.inference import predict_and_save # Check if main function can be imported
        from basic_pitch import ICASSP_2022_MODEL_PATH # Check if model path can be imported
        
        # If these imports work, we assume basic_pitch is functional enough.
        # The actual model loading integrity will be tested by extract_midi_from_audio
        
        success_result = {
            "status": "success",
            "message": "All required libraries loaded successfully"
        }
        print(json.dumps(success_result), file=sys.stdout)
        sys.exit(0)
    except Exception as e:
        error_result = {
            "status": "error",
            "error": f"Error checking capabilities: {str(e)}"
        }
        try:
            print(json.dumps(error_result), file=sys.stdout)
            sys.exit(0) # Script ran and reported error correctly
        except Exception as e_json:
            # If we can't even print the JSON error, log to stderr and exit 1
            print(f"Critical error: Failed to print JSON error to stdout during capability check: {str(e_json)}", file=sys.stderr)
            sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # For argument errors before JSON can be formed, print to stderr and exit 1
        print("Error: No command specified", file=sys.stderr)
        sys.exit(1)
        
    command = sys.argv[1]
    
    if command == "check_capabilities":
        check_capabilities() # Function now handles JSON output and exit
    elif command == "extract_midi":
        if len(sys.argv) < 4:
            # For argument errors before JSON can be formed, print to stderr and exit 1
            print("Error: Missing required arguments for MIDI extraction", file=sys.stderr)
            sys.exit(1)
            
        # Parse arguments
        args = {}
        for arg in sys.argv[2:]:
            if "=" in arg:
                key, value = arg.split("=", 1)
                # Remove quotes if present
                value = value.strip('"')
                args[key] = value
        
        if "input_path" not in args or "output_path" not in args:
            # For argument errors before JSON can be formed, print to stderr and exit 1
            print("Error: Missing input_path or output_path argument", file=sys.stderr)
            sys.exit(1)
            
        extract_midi_from_audio(args["input_path"], args["output_path"]) # Function now handles JSON output and exit
    else:
        # For argument errors before JSON can be formed, print to stderr and exit 1
        print(f"Error: Unknown command '{command}'", file=sys.stderr)
        sys.exit(1)