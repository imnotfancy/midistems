import os
import json
import sys
import logging
import tempfile
from typing import Dict, Any, List

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s: %(message)s',
    stream=sys.stderr  # Send logs to stderr to keep stdout clean for JSON
)
logger = logging.getLogger(__name__)

def write_json_response(data: Dict[str, Any]) -> None:
    """Write JSON response using a temporary file to ensure proper formatting."""
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json') as f:
        json.dump(data, f)
        temp_path = f.name
    
    try:
        with open(temp_path, 'r') as f:
            print(f.read().strip(), flush=True)
    finally:
        try:
            os.unlink(temp_path)
        except:
            pass

def format_json_response(status: str, data: Any = None, error: str = None) -> Dict[str, Any]:
    """Format response as JSON object."""
    response = {'status': status}
    if data is not None:
        response['result'] = data
    if error is not None:
        response['error'] = error
    return response

def parse_args(args: List[str]) -> Dict[str, str]:
    """Parse command line arguments in the format key=value."""
    result = {}
    for arg in args:
        if '=' in arg:
            key, value = arg.split('=', 1)
            # Handle quoted paths more robustly
            value = value.strip()
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]  # Remove surrounding quotes
            # Unescape any escaped quotes within the path
            value = value.replace('\\"', '"')
            # Log the parsed argument
            logger.info(f"Parsed argument - {key}: {value}")
            result[key] = value
    return result

class DependencyManager:
    def __init__(self):
        self.torch_available = False
        self.torchaudio_available = False
        self.demucs_available = False
        self.soundfile_available = False
        self._check_dependencies()
        
    def _check_dependencies(self):
        """Check which dependencies are available."""
        try:
            import torch
            import torchaudio
            self.torch_available = True
            self.torchaudio_available = True
            logger.info(f"PyTorch loaded successfully (device: {torch.device('cuda' if torch.cuda.is_available() else 'cpu')})")
        except ImportError as e:
            logger.error(f"Failed to import PyTorch/torchaudio: {e}")
            
        try:
            import soundfile
            self.soundfile_available = True
            logger.info("SoundFile loaded successfully")
        except ImportError:
            logger.error("Failed to import soundfile")
            
        try:
            from demucs.pretrained import get_model
            from demucs.apply import apply_model
            self.demucs_available = True
            logger.info("Demucs loaded successfully")
        except ImportError:
            logger.error("Failed to import demucs")

    def get_missing_dependencies(self) -> List[str]:
        """Get list of missing dependencies."""
        missing = []
        if not self.torch_available or not self.torchaudio_available:
            missing.extend(['torch', 'torchaudio'])
        if not self.soundfile_available:
            missing.append('soundfile')
        if not self.demucs_available:
            missing.append('demucs')
        return missing

    def can_separate_stems(self) -> bool:
        """Check if stem separation is possible."""
        return all([
            self.torch_available,
            self.torchaudio_available,
            self.soundfile_available,
            self.demucs_available
        ])

class AudioProcessor:
    def __init__(self):
        self.deps = DependencyManager()
        self.device = None
        self.demucs_model = None
        
        if self.deps.torch_available:
            import torch
            self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
            logger.info(f"AudioProcessor initialized (device: {self.device})")
        
    def load_models(self):
        """Load all required models."""
        if not self.deps.can_separate_stems():
            raise ImportError("Required dependencies for stem separation not available")
            
        if self.demucs_model is None:
            from demucs.pretrained import get_model
            logger.info("Loading Demucs model...")
            self.demucs_model = get_model('htdemucs')
            self.demucs_model.to(self.device)
            logger.info("Demucs model loaded successfully")
    
    def load_audio(self, audio_path: str):
        """Load audio file with proper format handling."""
        import soundfile as sf
        import torch
        import numpy as np
        
        logger.info(f"Attempting to load audio file: {audio_path}")
        logger.info(f"File exists: {os.path.exists(audio_path)}")
        logger.info(f"File size: {os.path.getsize(audio_path) if os.path.exists(audio_path) else 'N/A'} bytes")
        
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Audio file not found: {audio_path}")
        
        if not os.access(audio_path, os.R_OK):
            raise PermissionError(f"Cannot read audio file: {audio_path}")
        
        try:
            # Try loading with soundfile first
            data, sr = sf.read(audio_path)
            # Convert to float32 tensor
            if data.dtype != np.float32:
                data = data.astype(np.float32)
            # Ensure stereo format
            if len(data.shape) == 1:  # Mono
                data = np.stack([data, data])  # Duplicate channel for stereo
            elif len(data.shape) == 2:
                if data.shape[1] == 2:  # Already stereo with channels as second dim
                    data = data.T  # Transpose to get channels first
                elif data.shape[0] == 2:  # Already stereo with channels as first dim
                    pass  # Already in correct format
                else:  # Mono as column vector
                    data = np.stack([data[:, 0], data[:, 0]])  # Duplicate channel for stereo
            # Convert to torch tensor (channels, samples)
            wav = torch.from_numpy(data)
            logger.info(f"Audio loaded successfully with soundfile (sample rate: {sr}Hz)")
            return wav, sr
        except Exception as e:
            logger.error(f"Failed to load audio with soundfile: {e}")
            try:
                # Fallback to torchaudio
                import torchaudio
                wav, sr = torchaudio.load(audio_path)
                if wav.shape[0] == 1:  # Convert mono to stereo
                    wav = wav.repeat(2, 1)  # Duplicate mono channel for stereo
                logger.info(f"Audio loaded successfully with torchaudio (sample rate: {sr}Hz)")
                return wav, sr
            except Exception as e:
                logger.error(f"Failed to load audio with torchaudio: {e}")
                raise ValueError(f"Could not load audio file {audio_path}. Supported formats: WAV, FLAC, OGG, MP3")
    
    def separate_stems(self, audio_path: str, output_dir: str) -> dict:
        """Separate audio into stems using Demucs."""
        if not self.deps.can_separate_stems():
            raise ImportError("Required dependencies for stem separation not available")
            
        import torch
        import torchaudio
        from demucs.apply import apply_model
        
        logger.info("=== Starting Stem Separation ===")
        logger.info(f"Input file: {audio_path}")
        logger.info(f"Output directory: {output_dir}")
        logger.info(f"Device: {self.device}")
        logger.info(f"Available memory: {torch.cuda.get_device_properties(0).total_memory if torch.cuda.is_available() else 'N/A'}")
        
        # Verify output directory
        try:
            os.makedirs(output_dir, exist_ok=True)
            logger.info(f"Created output directory: {output_dir}")
            if not os.access(output_dir, os.W_OK):
                raise PermissionError(f"Cannot write to output directory: {output_dir}")
        except Exception as e:
            logger.error(f"Error creating output directory: {e}")
            raise
        
        self.load_models()
        
        # Load audio
        wav, sr = self.load_audio(audio_path)
        wav = wav.to(self.device)
        
        # Apply separation
        logger.info("Starting source separation...")
        logger.info(f"Input audio shape: {wav.shape}")
        
        try:
            # Ensure wav is in the correct shape (batch, channels, samples)
            if len(wav.shape) == 2:  # (channels, samples)
                wav = wav.unsqueeze(0)  # Add batch dimension
                logger.info("Added batch dimension to audio")
            
            logger.info(f"Processed audio shape: {wav.shape}")
            logger.info("Applying Demucs model...")
            
            sources = apply_model(self.demucs_model, wav, shifts=1, split=True, overlap=0.25)
            sources = sources.cpu()
            
            logger.info(f"Separation complete. Output shape: {sources.shape}")
            
            # Save stems
            stem_paths = {}
            stem_names = ['drums', 'bass', 'other', 'vocals']
            
            try:
                # sources shape should be (batch, stems, channels, samples)
                sources = sources.squeeze(0)  # Remove batch dimension
                logger.info(f"Processing stems. Shape after squeeze: {sources.shape}")
                
                for i, (source, name) in enumerate(zip(sources, stem_names)):
                    output_path = os.path.join(output_dir, f"{name}.wav")
                    logger.info(f"Saving {name} stem ({i+1}/{len(stem_names)})")
                    logger.info(f"Stem shape: {source.shape}, Sample rate: {sr}")
                    
                    try:
                        torchaudio.save(output_path, source, sr)
                        stem_paths[name] = output_path
                        logger.info(f"Successfully saved {name} stem to {output_path}")
                    except Exception as e:
                        logger.error(f"Error saving {name} stem: {e}")
                        raise
                
                # Convert paths to use forward slashes for consistency
                stem_paths = {
                    name: path.replace('\\', '/')
                    for name, path in stem_paths.items()
                }
                logger.info("All stems saved successfully")
                logger.info(f"Final stem paths: {stem_paths}")
                return stem_paths
                
            except Exception as e:
                logger.error(f"Error processing stems: {e}")
                raise
                
        except RuntimeError as e:
            if "out of memory" in str(e):
                logger.error("GPU out of memory error. Try processing a shorter audio file or using CPU.")
                raise MemoryError("Not enough GPU memory for audio processing")
            raise
        except Exception as e:
            logger.error(f"Error during source separation: {e}")
            raise

def get_capabilities() -> Dict[str, Any]:
    """Get current capabilities based on available dependencies."""
    deps = DependencyManager()
    return {
        'can_separate_stems': deps.can_separate_stems(),
        'missing_dependencies': deps.get_missing_dependencies()
    }

def process_command(action: str, args: Dict[str, str]) -> Dict[str, Any]:
    """Process command and return response object."""
    try:
        processor = AudioProcessor()
        
        if action == 'get_capabilities':
            return format_json_response('success', get_capabilities())
        elif action == 'separate_stems':
            if not processor.deps.can_separate_stems():
                missing_deps = processor.deps.get_missing_dependencies()
                error_msg = {
                    'message': 'Stem separation not available due to missing dependencies',
                    'details': {
                        'missing_dependencies': missing_deps
                    }
                }
                return format_json_response('error', error=error_msg)
                
            if 'input_path' not in args or 'output_dir' not in args:
                error_msg = {
                    'message': 'Missing required arguments',
                    'details': {
                        'required': ['input_path', 'output_dir'],
                        'provided': list(args.keys())
                    }
                }
                return format_json_response('error', error=error_msg)
            
            try:
                result = processor.separate_stems(args['input_path'], args['output_dir'])
                return format_json_response('success', {
                    'stems': result,
                    'details': {
                        'input_file': args['input_path'],
                        'output_directory': args['output_dir']
                    }
                })
            except Exception as e:
                error_msg = {
                    'message': str(e),
                    'details': {
                        'input_file': args['input_path'],
                        'output_directory': args['output_dir'],
                        'error_type': e.__class__.__name__
                    }
                }
                return format_json_response('error', error=error_msg)
        else:
            error_msg = {
                'message': 'Invalid action specified',
                'details': {
                    'provided_action': action,
                    'valid_actions': ['get_capabilities', 'separate_stems']
                }
            }
            return format_json_response('error', error=error_msg)
    except Exception as e:
        logger.exception("Error processing command")
        error_msg = {
            'message': str(e),
            'details': {
                'error_type': e.__class__.__name__,
                'action': action,
                'args': args
            }
        }
        return format_json_response('error', error=error_msg)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        action = sys.argv[1]
        kwargs = parse_args(sys.argv[2:])
        write_json_response(process_command(action, kwargs))
    else:
        write_json_response(format_json_response('error', error='No arguments provided'))