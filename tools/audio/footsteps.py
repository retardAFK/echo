"""Synthesises the footsteps of the hunted on each floor, and the monster's
scrape (spec S-012, T-143).

Made by us from noise and oscillators: no sample from anyone else. Four
variants per floor (FloorSurface in the game), drawn at random:
- step_concrete_N.wav: asphalt, cellars, landings: a heel, a dry scuff,
- step_earth_N.wav: the dead lawn and the playground sand: a gritty crunch,
- step_metal_N.wav: fire escapes and steel steps: a hollow clang,
- step_tile_N.wav: terrazzo, lino, hospital floors: a sharp click in a tiled
  room,
- step_wood_N.wav: the parquet of the flats: a hollow knock, a creak now and
  then,
- step_puddle_N.wav: a puddle: a splash and a few drops,
- monster_step_N.wav: the monster: a heavy foot that strikes and drags.
    python tools/audio/footsteps.py [out_dir]   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, band, save, shaped_noise  # noqa: E402
from loop_sounds import burst, place, ring  # noqa: E402

rng = np.random.default_rng(1212)
VARIANTS = 4


def _len(seconds):
    return np.zeros(int(seconds * RATE))


def _env(n, attack, decay):
    t = np.arange(n) / RATE
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)


def _thump(low, high, decay, seconds=0.25):
    return burst(seconds, low, high, decay)


def _grains(seconds, count, low, high, spread):
    """Many tiny clicks: grit, gravel, sand."""
    out = _len(seconds)
    for _ in range(count):
        at = abs(rng.normal(0.0, spread))
        click = burst(0.012, low, high, 0.0015) * rng.uniform(0.2, 1.0)
        if at < seconds - 0.013:
            place(out, click, at)
    return out


def _echo(sound, delays, decay):
    out = np.zeros(sound.size + int(max(delays) * RATE) + 1)
    out[: sound.size] += sound
    level = 1.0
    for d in delays:
        level *= decay
        dull = np.convolve(sound, np.ones(5) / 5, mode="same")
        i = int(d * RATE)
        out[i : i + sound.size] += dull * level
    return out


def _vary():
    return rng.uniform(0.85, 1.15)


def concrete():
    out = _len(0.35)
    place(out, _thump(70 * _vary(), 700, 0.010), 0.0)
    place(out, burst(0.1, 1500, 6000, 0.008), rng.uniform(0.05, 0.08), 0.35)
    place(out, _grains(0.2, 12, 2500, 8000, 0.04), 0.0, 0.25)
    return out


def earth():
    out = _len(0.4)
    place(out, _thump(60, 400, 0.02), 0.0, 0.6)
    place(out, _grains(0.35, 90, 1200 * _vary(), 7000, 0.06), 0.005)
    return out


def metal():
    out = _len(0.6)
    f = _vary()
    place(out, ring(0.55, ((190 * f, 1.0), (430 * f, 0.7), (910 * f, 0.4), (1630 * f, 0.25)), 0.08), 0.0, 0.7)
    place(out, _thump(60, 900, 0.012), 0.0)
    place(out, burst(0.1, 2000, 7000, 0.006), 0.06, 0.3)
    return out


def tile():
    out = _len(0.2)
    place(out, burst(0.05, 1200, 9000, 0.0035), 0.0)
    place(out, _thump(150 * _vary(), 1500, 0.006), 0.0, 0.6)
    place(out, burst(0.05, 1800, 9000, 0.003), rng.uniform(0.05, 0.07), 0.45)
    return _echo(out, (0.05, 0.11, 0.18), 0.4)


def wood():
    out = _len(0.45)
    f = _vary()
    place(out, ring(0.3, ((165 * f, 1.0), (390 * f, 0.5), (720 * f, 0.2)), 0.035), 0.0, 0.8)
    place(out, _thump(80, 900, 0.01), 0.0)
    if rng.uniform() < 0.5:  # A loose board.
        t = np.arange(int(0.18 * RATE)) / RATE
        pitch = 700 * f + 300 * t / t[-1]
        pulses = (np.sin(2 * np.pi * np.cumsum(pitch) / RATE) > 0.97).astype(float)
        creak = np.convolve(pulses, np.hanning(9), mode="same") * np.hanning(t.size)
        place(out, creak, 0.1, 0.25)
    return out


def puddle():
    out = _len(0.55)
    place(out, burst(0.3, 300, 5000, 0.04), 0.0, 0.8)
    place(out, _thump(60, 500, 0.015), 0.0, 0.5)
    for _ in range(rng.integers(3, 6)):
        t = np.arange(int(0.04 * RATE)) / RATE
        freq = rng.uniform(700, 1600) * (1 + 3 * t)
        drop = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.01)
        place(out, drop, rng.uniform(0.05, 0.4), rng.uniform(0.15, 0.35))
    return out


def monster_step():
    out = _len(0.7)
    place(out, _thump(35, 300, 0.035, 0.4), 0.0)
    place(out, ring(0.4, ((55 * _vary(), 1.0), (97, 0.5)), 0.08), 0.0, 0.5)
    n = int(0.42 * RATE)
    drag = shaped_noise(0.42, band(250, 2600, 0.8)) * _env(n, 0.08, 0.2)
    rough = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * rng.uniform(18, 26) * np.arange(n) / RATE))
    place(out, drag * rough, 0.12, 0.55)
    return out


FLOORS = {
    "concrete": concrete,
    "earth": earth,
    "metal": metal,
    "tile": tile,
    "wood": wood,
    "puddle": puddle,
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/steps"
    os.makedirs(out, exist_ok=True)
    for name, make in FLOORS.items():
        for i in range(VARIANTS):
            save(os.path.join(out, "step_%s_%d.wav" % (name, i)), make(), 0.8)
    for i in range(VARIANTS):
        save(os.path.join(out, "monster_step_%d.wav" % i), monster_step(), 0.9)
