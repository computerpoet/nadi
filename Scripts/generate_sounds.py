#!/usr/bin/env python3
"""
Generate the three sound files used by Nadi:
  - tick.wav        440 Hz sine, 50ms, volume 0.7
  - tick-stressed.wav  880 Hz sine, 50ms, volume 0.9
  - bell.wav        520 Hz + harmonics, 3s exponential decay

Requires: numpy (pip install numpy)
Output:   nadi/Resources/Sounds/*.wav

Usage:
  python3 Scripts/generate_sounds.py
"""

import struct
import wave
import math
import os

SAMPLE_RATE = 44100
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "nadi", "Resources", "Sounds")


def write_wav(filename: str, samples: list[float], sample_rate: int = SAMPLE_RATE):
    """Write mono 16-bit WAV file from float samples in [-1, 1]."""
    path = os.path.join(OUTPUT_DIR, filename)
    os.makedirs(os.path.dirname(path), exist_ok=True)

    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)  # 16-bit
        f.setframerate(sample_rate)

        data = b""
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            data += struct.pack("<h", int(clamped * 32767))
        f.writeframes(data)

    print(f"  Written: {path} ({len(samples)} samples, {len(samples)/sample_rate:.3f}s)")


def generate_tick(freq: float, duration_s: float, volume: float) -> list[float]:
    """Generate a short sine tone with a quick fade-in/out to avoid clicks."""
    n_samples = int(SAMPLE_RATE * duration_s)
    fade_samples = min(int(SAMPLE_RATE * 0.005), n_samples // 4)  # 5ms fade

    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        val = math.sin(2 * math.pi * freq * t) * volume

        # Fade envelope
        if i < fade_samples:
            val *= i / fade_samples
        elif i > n_samples - fade_samples:
            val *= (n_samples - i) / fade_samples

        samples.append(val)

    return samples


def generate_bell(
    base_freq: float = 520.0,
    duration_s: float = 3.0,
    harmonics: list[tuple[float, float]] = None,
) -> list[float]:
    """
    Generate a bell tone with harmonics and exponential decay.

    harmonics: list of (frequency_multiplier, amplitude_weight)
    Weights are normalized to sum to 1.0.
    """
    if harmonics is None:
        # 3 harmonics: fundamental + 2 overtones
        harmonics = [
            (1.0, 0.55),   # fundamental
            (2.0, 0.30),   # octave
            (3.0, 0.15),   # fifth above octave
        ]

    n_samples = int(SAMPLE_RATE * duration_s)
    decay_rate = 3.0 / duration_s  # ~60dB decay over duration

    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        envelope = math.exp(-decay_rate * t)

        val = 0.0
        for mult, weight in harmonics:
            val += weight * math.sin(2 * math.pi * base_freq * mult * t)

        val *= envelope * 0.8  # overall volume

        # Quick fade at end to avoid click
        if i > n_samples - 200:
            val *= (n_samples - i) / 200

        samples.append(val)

    return samples


def main():
    print("Generating Nadi sound files...")

    # Regular tick: 440 Hz, 50ms, vol 0.7
    tick = generate_tick(freq=440.0, duration_s=0.05, volume=0.7)
    write_wav("tick.wav", tick)

    # Stressed tick: 880 Hz, 50ms, vol 0.9
    stressed = generate_tick(freq=880.0, duration_s=0.05, volume=0.9)
    write_wav("tick-stressed.wav", stressed)

    # Bell: 520 Hz base, 3s decay, 3 harmonics
    bell = generate_bell(base_freq=520.0, duration_s=3.0)
    write_wav("bell.wav", bell)

    print("Done.")


if __name__ == "__main__":
    main()
