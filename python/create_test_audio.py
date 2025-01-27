import numpy as np
import soundfile as sf

# Generate a simple sine wave
duration = 2.0  # seconds
sample_rate = 44100
t = np.linspace(0, duration, int(sample_rate * duration))
frequency = 440.0  # A4 note
amplitude = 0.5

# Create sine wave
audio_data = amplitude * np.sin(2 * np.pi * frequency * t)

# Create test directory if it doesn't exist
import os
os.makedirs('test/resources', exist_ok=True)

# Save as WAV file
sf.write('test/resources/test_audio.wav', audio_data, sample_rate)
print("Created test audio file: test/resources/test_audio.wav")