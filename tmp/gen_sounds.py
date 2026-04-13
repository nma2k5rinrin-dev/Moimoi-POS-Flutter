import wave
import struct
import math
import os

def generate_wave(filename, duration, frequencies, sample_rate=44100, volume=0.5):
    filepath = os.path.join(r"e:\Moimoi-POS-Flutter\assets\sounds", filename)
    num_samples = int(duration * sample_rate)
    
    with wave.open(filepath, 'w') as wav:
        wav.setnchannels(1) # mono
        wav.setsampwidth(2) # 2 bytes = 16 bit
        wav.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            value = 0
            # Envelope (decay)
            envelope = math.exp(-3.0 * t) 
            
            for freq in frequencies:
                value += math.sin(2.0 * math.pi * freq * t)
                
            value = value / len(frequencies) * volume * envelope
            
            # Clip
            value = max(min(value, 1.0), -1.0)
            data = struct.pack('<h', int(value * 32767.0))
            wav.writeframesraw(data)

# Bell (Service Bell sound, multiple high frequencies decaying fast)
generate_wave("bell.wav", 1.5, [1800, 2400, 3100, 4200], volume=0.4)

# Chime (Ding-Dong style: Ding = high freq, Dong = low freq after delay)
# For simplicity, we just synthesize two tones overlapping
def generate_chime(filename):
    filepath = os.path.join(r"e:\Moimoi-POS-Flutter\assets\sounds", filename)
    sample_rate = 44100
    duration = 2.0
    num_samples = int(duration * sample_rate)
    
    with wave.open(filepath, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            
            # Ding: starts at 0, freq = 880 (A5)
            # Dong: starts at 0.5s, freq = 740 (F#5)
            
            val1 = 0
            if t < 1.0:
                env1 = math.exp(-5.0 * t)
                val1 = math.sin(2.0 * math.pi * 880 * t) * env1
            
            val2 = 0
            if t > 0.4:
                env2 = math.exp(-4.0 * (t - 0.4))
                val2 = math.sin(2.0 * math.pi * 659.25 * (t - 0.4)) * env2 # E5
                
            value = (val1 + val2) * 0.4
            
            value = max(min(value, 1.0), -1.0)
            data = struct.pack('<h', int(value * 32767.0))
            wav.writeframesraw(data)

generate_chime("chime.wav")
print("Generated bell.wav and chime.wav successfully.")
