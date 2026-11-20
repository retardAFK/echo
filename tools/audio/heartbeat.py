"""Synthesises the heartbeat heard in a hiding spot (spec S-020, T-327, piste H3).

Made by us from oscillators: no sample from anyone else.
- heartbeat.wav: one "lub-dub", two low muffled thumps; TensionMusic plays it
  again and again, faster as the monster comes near.
    python tools/audio/heartbeat.py [out_dir]   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, save  # noqa: E402
from loop_sounds import place  # noqa: E402


def _thump(seconds, pitch, decay):
    """A low thump: a sine sliding down a little, dying fast, no click."""
    t = np.arange(int(seconds * RATE)) / RATE
    slide = pitch * (1.0 + 0.6 * np.exp(-t / 0.02))
    phase = 2 * np.pi * np.cumsum(slide) / RATE
    attack = 1.0 - np.exp(-t / 0.004)
    return np.sin(phase) * attack * np.exp(-t / decay)


def heartbeat(seconds=0.5):
    out = np.zeros(int(seconds * RATE))
    place(out, _thump(0.25, 52, 0.05), 0.0, 1.0)  # Lub.
    place(out, _thump(0.25, 64, 0.04), 0.17, 0.7)  # Dub.
    return out


SOUNDS = {"heartbeat": (heartbeat, 0.8)}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/music"
    os.makedirs(out, exist_ok=True)
    for name, (make, level) in SOUNDS.items():
        save(os.path.join(out, name + ".wav"), make(), level)
