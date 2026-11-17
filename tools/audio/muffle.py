"""Writes the muffled version of every game sound (spec S-012, T-142).

Behind a wall, SoundSpace plays foo_muffled.wav instead of foo.wav: the
browser cannot filter a sound live in Godot's web "samples" mode, so the
filtering is done here, once. A low-pass (Butterworth-like slope, order 3,
cut at CUTOFF Hz) keeps the thump and drops the detail; the level is kept,
SoundSpace lowers the volume per wall.

    python tools/audio/muffle.py [file.wav ...]   (needs numpy)

Without arguments, it muffles every sound of GAME_SOUNDS. Run it again after
a game sound changes, then reimport (godot --headless --import).
"""

import glob
import os
import sys
import wave

import numpy as np

CUTOFF = 700.0
ORDER = 3
SUFFIX = "_muffled"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")

# Game noises played through SoundSpace (not the ambience loops).
GAME_SOUNDS = [
    "assets/audio/interiors/*.wav",
    "assets/audio/network/*.wav",
    "assets/audio/ruses/*.wav",
    "assets/audio/loop/fuse_clank.wav",
    "assets/audio/loop/repair_sparks.wav",
    "assets/audio/loop/siren.wav",
    "assets/audio/hospital/monitor_beep.wav",
    "assets/audio/hospital/roll.wav",
    "assets/audio/hospital/gurney_crash.wav",
    "assets/audio/steps/*.wav",
    "assets/audio/voices/monster_*.wav",
    "assets/audio/voices/hunted_breath.wav",
    "assets/audio/voices/call_for_help.wav",
    "assets/audio/voices/rescue.wav",
    "assets/audio/voices/car_alarm.wav",
]


def read(path):
    with wave.open(path, "rb") as f:
        rate = f.getframerate()
        data = np.frombuffer(f.readframes(f.getnframes()), dtype="<i2")
    return rate, data.astype(np.float64) / 32767.0


def write(path, rate, signal):
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(data.tobytes())


def low_pass(signal, rate, cutoff=CUTOFF, order=ORDER):
    """Zero-phase low-pass in the frequency domain, padded so nothing wraps."""
    n = signal.size
    pad = int(rate * 0.1)
    spectrum = np.fft.rfft(np.concatenate([signal, np.zeros(pad)]))
    freqs = np.fft.rfftfreq(n + pad, 1.0 / rate)
    spectrum *= 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** (2 * order))
    return np.fft.irfft(spectrum, n + pad)[:n]


def muffle(path):
    rate, signal = read(path)
    out = low_pass(signal, rate)
    peak = np.max(np.abs(out))
    if peak > 0:
        out *= np.max(np.abs(signal)) / peak  # Same peak as the clean sound.
    base, ext = os.path.splitext(path)
    write(base + SUFFIX + ext, rate, out)
    return base + SUFFIX + ext


def game_sounds():
    paths = []
    for pattern in GAME_SOUNDS:
        paths += sorted(glob.glob(os.path.join(ROOT, pattern)))
    return [p for p in paths if not os.path.splitext(p)[0].endswith(SUFFIX)]


if __name__ == "__main__":
    for path in sys.argv[1:] or game_sounds():
        print(os.path.relpath(muffle(path), ROOT))
