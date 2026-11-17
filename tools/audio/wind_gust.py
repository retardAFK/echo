"""Synthesises the whistle of a gust of wind between the blocks (spec S-012,
T-144): a hollow howl gliding in pitch, over hissing air. Seamless loop.
    python tools/audio/wind_gust.py [out_dir]   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, band, peak, save, shaped_noise, slow_wave  # noqa: E402

SECONDS = 8.0


def gust(seconds=SECONDS):
    sweep = slow_wave(seconds, 0.4)
    air = shaped_noise(seconds, band(300, 6000, 1.0)) * (0.4 + 0.6 * slow_wave(seconds, 0.8))
    howl = np.zeros(int(seconds * RATE))
    for center, width, level in ((520, 40, 1.0), (780, 60, 0.6), (1150, 80, 0.3)):
        tone = shaped_noise(seconds, peak(center, width))
        howl += level * tone * (0.3 + 0.7 * sweep)
    return 0.6 * air + howl


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/ambience"
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "gust.wav"), gust(), 0.6)
