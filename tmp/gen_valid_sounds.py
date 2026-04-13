import wave
import struct
import math
import os

os.makedirs('assets/sounds', exist_ok=True)

with wave.open('assets/sounds/bell.wav', 'w') as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(44100)
    frames = bytearray()
    for i in range(44100 // 2):
        envelope = math.exp(-6.0 * i / 44100.0)
        value = int(32767.0 * envelope * math.sin(2.0 * math.pi * 880.0 * i / 44100.0))
        frames += struct.pack('<h', value)
    f.writeframes(frames)

with wave.open('assets/sounds/chime.wav', 'w') as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(44100)
    frames = bytearray()
    for i in range(44100):
        envelope = math.exp(-3.0 * i / 44100.0)
        v1 = math.sin(2.0 * math.pi * 523.25 * i / 44100.0)
        v2 = math.sin(2.0 * math.pi * 659.25 * i / 44100.0)
        value = int(16000.0 * envelope * (v1 + v2))
        frames += struct.pack('<h', value)
    f.writeframes(frames)
