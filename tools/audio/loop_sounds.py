"""Synthesises the sounds of the game loop (S-007, T-059).

Made by us from noise and oscillators: no sample from anyone else.
- fuse_clank.wav: the metal door of a fuse box, a latch and a fuse pulled out,
- repair_sparks.wav: sheet metal knocked and electric sparks at the transformer,
- transformer_hum.wav: the repaired transformer humming at 50 Hz (loop),
- siren.wav: the cité's siren, rising and falling twice in 10 s,
- monster_rumble.wav: a deep growl rolling over the cité when the monster
  rises a stage (S-023, Q6, T-355); heard by the hunted, not a game noise.
The hum loops seamlessly: every partial has a whole number of cycles.
    python tools/audio/loop_sounds.py <out_dir>   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, band, save, shaped_noise  # noqa: E402

rng = np.random.default_rng(2007)


def ring(seconds, partials, decay):
    """A struck metal plate: inharmonic partials (Hz, level) dying out."""
    t = np.arange(int(seconds * RATE)) / RATE
    out = np.zeros_like(t)
    for freq, level in partials:
        phase = rng.uniform(0, 2 * np.pi)
        out += level * np.sin(2 * np.pi * freq * t + phase) * np.exp(-t / (decay * (300 / freq) ** 0.3))
    return out


def burst(seconds, low, high, decay):
    """A short noise burst, filtered, dying out."""
    n = int(seconds * RATE)
    noise = shaped_noise(seconds, band(low, high, 0.5))
    return noise * np.exp(-np.arange(n) / (decay * RATE))


def place(out, sound, at, level=1.0):
    i = int(at * RATE)
    end = min(out.size, i + sound.size)
    out[i:end] += level * sound[: end - i]


def fuse_clank(seconds=0.7):
    out = np.zeros(int(seconds * RATE))
    door = ring(0.5, ((410, 1.0), (1130, 0.6), (2270, 0.35), (3410, 0.2)), 0.09)
    door += burst(0.5, 300, 3000, 0.012) * 0.8
    place(out, door, 0.0)
    latch = ring(0.2, ((1850, 1.0), (4200, 0.5)), 0.025) + burst(0.2, 1500, 6000, 0.004)
    place(out, latch, 0.16, 0.5)
    pull = burst(0.25, 800, 4000, 0.03) * np.linspace(1, 0.2, int(0.25 * RATE))
    place(out, pull, 0.3, 0.35)
    return out


def repair_sparks(seconds=1.4):
    out = np.zeros(int(seconds * RATE))
    sheet = ring(1.0, ((95, 1.0), (233, 0.8), (517, 0.5), (1210, 0.3)), 0.25)
    sheet += burst(1.0, 60, 900, 0.05) * 0.7
    place(out, sheet, 0.0)
    at = 0.25
    while at < seconds - 0.1:  # Crackling sparks, in quick irregular bursts.
        spark = burst(0.04, 2500, 9000, 0.006) * rng.uniform(0.3, 1.0)
        place(out, spark, at, 0.6)
        at += rng.exponential(0.035)
    buzz_t = np.arange(int(0.6 * RATE)) / RATE
    buzz = np.sign(np.sin(2 * np.pi * 100 * buzz_t)) * np.exp(-buzz_t / 0.25) * 0.15
    place(out, buzz, 0.3)
    return out


def transformer_hum(seconds=4.0):
    t = np.arange(int(seconds * RATE)) / RATE
    hum = np.zeros_like(t)
    for harmonic, level in ((1, 0.5), (2, 1.0), (3, 0.35), (4, 0.25), (6, 0.12), (8, 0.06)):
        hum += level * np.sin(2 * np.pi * 50 * harmonic * t)
    wobble = 1.0 + 0.08 * np.sin(2 * np.pi * 0.5 * t)  # Two cycles over the loop.
    hiss = shaped_noise(seconds, band(2000, 6000, 0.5)) * 0.03
    return hum * wobble + hiss


def siren(seconds=10.0):
    t = np.arange(int(seconds * RATE)) / RATE
    cycle = seconds / 2.0
    phase_in_cycle = (t % cycle) / cycle
    # Slow rise, short hold, slow fall, like a hand-cranked civil siren.
    sweep = np.clip(np.minimum(phase_in_cycle / 0.45, (1.0 - phase_in_cycle) / 0.4), 0, 1)
    sweep = sweep * sweep * (3 - 2 * sweep)
    freq = 180 + 520 * sweep
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    tone = np.sin(phase) + 0.45 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase) + 0.1 * np.sin(5 * phase)
    envelope = np.clip(np.minimum(t / 0.6, (seconds - t) / 1.5), 0, 1)
    echo = np.zeros_like(tone)
    delay = int(0.37 * RATE)  # Thrown back by the blocks of flats.
    echo[delay:] = tone[:-delay] * 0.35
    return (tone + echo) * (0.4 + 0.6 * sweep) * envelope


def monster_rumble(seconds=3.2):
    """A low growl that swells and dies: two detuned voices near 48 Hz with
    rough harmonics, a throaty noise band, and a far echo off the blocks."""
    t = np.arange(int(seconds * RATE)) / RATE
    swell = np.clip(np.minimum(t / 1.1, (seconds - t) / 1.6), 0, 1) ** 1.5
    wobble = 1.0 + 0.05 * np.sin(2 * np.pi * 1.7 * t) + 0.03 * np.sin(2 * np.pi * 4.3 * t)
    out = np.zeros_like(t)
    for base, level in ((46.0, 1.0), (49.5, 0.8)):
        phase = 2 * np.pi * np.cumsum(base * wobble * (1.0 - 0.12 * t / seconds)) / RATE
        for harmonic, part in ((1, 1.0), (2, 0.55), (3, 0.35), (5, 0.18), (7, 0.08)):
            out += level * part * np.sin(harmonic * phase)
    out = np.tanh(out * 0.9)  # Rough, like a throat.
    throat = shaped_noise(seconds, band(70, 420, 1.0)) * 0.6
    grit = 0.5 + 0.5 * np.sin(2 * np.pi * 23 * t) ** 2  # Rattling, 23 times a second.
    sound = (out + throat * grit) * swell
    echo = np.zeros_like(sound)
    delay = int(0.41 * RATE)
    echo[delay:] = sound[:-delay] * 0.3
    return sound + echo


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/loop"
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "fuse_clank.wav"), fuse_clank(), 0.8)
    save(os.path.join(out, "repair_sparks.wav"), repair_sparks(), 0.8)
    save(os.path.join(out, "transformer_hum.wav"), transformer_hum(), 0.6)
    save(os.path.join(out, "siren.wav"), siren(), 0.8)
    save(os.path.join(out, "monster_rumble.wav"), monster_rumble(), 0.85)
