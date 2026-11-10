"""Synthesises the ambient sounds of the cité des Tilleuls (S-006, T-050).

Made by us from filtered noise: no sample from anyone else.
- wind.wav: wind between the blocks, slow gusts and a faint whistle (loop),
- motorway.wav: the motorway behind the east fence, rumble and cars (loop),
- train.wav: a distant train passing on the embankment (one shot),
- swing_creak.wav: the chains of the swing creaking in the wind (loop).
The loops are seamless: their noise is shaped in the frequency domain, where
the signal is periodic, and every modulation has a whole number of cycles.
    python tools/audio/ambience.py <out_dir>   (needs numpy)
"""

import os
import sys
import wave

import numpy as np

RATE = 22050
rng = np.random.default_rng(1971)


def shaped_noise(seconds, shape):
    """Periodic noise whose spectrum follows shape(frequencies in Hz)."""
    n = int(seconds * RATE)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    signal = np.fft.irfft(spectrum * shape(freqs), n)
    return signal / np.max(np.abs(signal))


def band(low, high, slope=1.0):
    """A soft band pass, falling as 1/f^slope inside the band."""

    def shape(f):
        f = np.maximum(f, 1.0)
        gain = (low / f) ** (slope / 2.0)
        gain *= 1.0 / (1.0 + (low / f) ** 4)
        gain *= 1.0 / (1.0 + (f / high) ** 4)
        return gain

    return shape


def peak(center, width):
    return lambda f: np.exp(-(((f - center) / width) ** 2))


def slow_wave(seconds, cutoff):
    """A smooth random curve from 0 to 1, periodic over the loop."""
    curve = shaped_noise(seconds, lambda f: (f > 0) * np.exp(-((f / cutoff) ** 2)))
    return (curve - curve.min()) / (curve.max() - curve.min())


def wind(seconds=16.0):
    gust = slow_wave(seconds, 0.35)
    body = shaped_noise(seconds, band(90, 1200, 1.2)) * (0.35 + 0.65 * gust)
    whistle = shaped_noise(seconds, peak(720, 25)) * gust**3 * 0.25
    return body + whistle


def motorway(seconds=12.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    rumble = shaped_noise(seconds, band(30, 220, 1.0))
    hiss = shaped_noise(seconds, band(400, 2200, 0.5))
    passes = np.zeros(n)
    for at, width, level in ((2.0, 1.6, 1.0), (6.5, 2.4, 0.7), (9.8, 1.2, 0.9)):
        d = (t - at + seconds / 2) % seconds - seconds / 2  # Distance on the loop.
        passes += level * np.exp(-((d / width) ** 2))
    return rumble * (0.8 + 0.3 * passes) + hiss * (0.12 + 0.35 * passes)


def train(seconds=16.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    swell = np.clip(np.minimum(t / 5.0, (seconds - t) / 5.0), 0.0, 1.0)
    swell = swell * swell * (3 - 2 * swell)
    rumble = shaped_noise(seconds, band(25, 180, 1.0))
    clacks = np.zeros(n)
    click = shaped_noise(0.06, band(200, 1400, 0.3)) * np.exp(-np.arange(int(0.06 * RATE)) / (0.012 * RATE))
    beat = 0.0
    while beat < seconds - 0.2:
        for offset, level in ((0.0, 1.0), (0.17, 0.8)):  # The two axles of a bogie.
            i = int((beat + offset) * RATE)
            end = min(n, i + click.size)
            clacks[i:end] += level * click[: end - i]
        beat += 1.05 + rng.uniform(-0.03, 0.03)
    screech = shaped_noise(seconds, peak(2300, 40)) * 0.04
    return (rumble + 0.5 * clacks + screech) * swell


def creak(seconds, pitch, rise):
    """Stick-slip of a chain link: a pulse train gliding in pitch, rung through
    two metal resonances."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    rate = pitch * (1.0 + rise * np.sin(np.pi * t / seconds))
    phase = np.cumsum(rate / RATE + rng.normal(0, 0.004, n))
    pulses = np.diff(np.floor(phase), prepend=0.0) * rng.uniform(0.6, 1.0, n)
    k = np.arange(int(0.03 * RATE)) / RATE
    ring = np.exp(-k / 0.008) * (np.sin(2 * np.pi * 870 * k) + 0.6 * np.sin(2 * np.pi * 1390 * k))
    sound = np.convolve(pulses, ring)[:n]
    envelope = np.sin(np.pi * t / seconds) ** 1.5
    return sound * envelope


def swing_creak(seconds=6.0):
    n = int(seconds * RATE)
    out = np.zeros(n)
    for at, length, pitch, rise, level in (
        (0.3, 0.5, 190, 0.35, 1.0),
        (1.8, 0.4, 160, 0.25, 0.7),
        (3.3, 0.55, 200, 0.4, 0.9),
        (4.8, 0.35, 150, 0.2, 0.55),
    ):
        sound = creak(length, pitch, rise)
        i = int(at * RATE)
        out[i : i + sound.size] += level * sound / np.max(np.abs(sound))
    return out


def save(path, signal, level):
    signal = signal / np.max(np.abs(signal)) * level
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/ambience"
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "wind.wav"), wind(), 0.7)
    save(os.path.join(out, "motorway.wav"), motorway(), 0.7)
    save(os.path.join(out, "train.wav"), train(), 0.8)
    save(os.path.join(out, "swing_creak.wav"), swing_creak(), 0.6)
