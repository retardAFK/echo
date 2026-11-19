"""Synthesises the tension music of Écho (spec S-012, T-146): no melody,
three layers of the same length that loop seamlessly and are started
together, faded in and out by TensionMusic.
- music_base.wav: a low drone, always there, very quiet,
- music_unease.wav: a slow muffled pulse, like a heart, over a dark minor
  second (the monster within 35 m),
- music_dread.wav: high dissonant strings, trembling (within 15 m, or the
  exit open).
Every tone has a whole number of cycles over the loop, every rhythm a whole
number of beats.
    python tools/audio/music.py [out_dir]   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, band, save, shaped_noise  # noqa: E402

SECONDS = 32.0
BEATS = 30  # 56.25 beats a minute.
rng = np.random.default_rng(1212)
T = np.arange(int(SECONDS * RATE)) / RATE


def tone(freq, level=1.0, harmonics=((1, 1.0),)):
    """A tone snapped to whole cycles over the loop."""
    out = np.zeros_like(T)
    for h, amp in harmonics:
        cycles = round(freq * h * SECONDS)
        out += amp * np.sin(2 * np.pi * cycles / SECONDS * T + rng.uniform(0, 2 * np.pi))
    return level * out


def lfo(cycles, depth, offset=0.0):
    return 1.0 - depth + depth * 0.5 * (1 + np.sin(2 * np.pi * cycles / SECONDS * T + offset))


def base():
    warm = ((1, 1.0), (2, 0.4), (3, 0.15))
    out = tone(36.7, 1.0, warm) * lfo(2, 0.3)
    out += tone(36.85, 0.8, warm) * lfo(3, 0.4, 1.0)
    out += tone(55.0, 0.45, warm) * lfo(1, 0.6, 2.0)
    out += 0.25 * shaped_noise(SECONDS, band(80, 600, 1.5)) * lfo(4, 0.5)
    return out


def unease():
    beat = SECONDS / BEATS
    out = np.zeros_like(T)
    thump_t = np.arange(int(0.25 * RATE)) / RATE
    thump = np.sin(2 * np.pi * 48 * thump_t) * np.exp(-thump_t / 0.06)
    for i in range(BEATS):
        for at, level in ((0.0, 1.0), (0.28, 0.6)):  # Lub, dub.
            a = int((i * beat + at) * RATE) % T.size
            end = a + thump.size
            if end <= T.size:
                out[a:end] += level * thump
            else:
                out[a:] += level * thump[: T.size - a]
                out[: end - T.size] += level * thump[T.size - a :]
    pad = tone(73.4, 0.35, ((1, 1.0), (2, 0.5), (3, 0.25))) + tone(77.8, 0.3, ((1, 1.0), (2, 0.5)))
    return out + pad * lfo(2, 0.7)


def dread():
    out = np.zeros_like(T)
    trem = lfo(round(7.5 * SECONDS), 0.5)
    for freq in (698.5, 740.0, 1046.5, 1108.7):
        string = tone(freq, 1.0, ((1, 1.0), (2, 0.45), (3, 0.3), (4, 0.18), (5, 0.1)))
        out += string * lfo(rng.integers(1, 4), 0.8, rng.uniform(0, 6))
    out *= trem
    out += 0.3 * shaped_noise(SECONDS, band(2000, 7000, 1.0)) * lfo(3, 0.8)
    return out


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/music"
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "music_base.wav"), base(), 0.7)
    save(os.path.join(out, "music_unease.wav"), unease(), 0.7)
    save(os.path.join(out, "music_dread.wav"), dread(), 0.6)
