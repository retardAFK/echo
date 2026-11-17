"""Synthesises the sounds of the hospital of the cité des Tilleuls (S-014, T-191).

Made by us from noise and oscillators: no sample from anyone else.
Devices (game/entities):
- monitor_beep.wav: a patient monitor's alarm, three high beeps, the third
  higher (heard as the MONITOR noise, 15 m),
- roll.wav: the casters of a gurney or a wheelchair on lino, a rattle and a
  dry squeak (the ROLL noise, every 0.5 s while it rolls),
- gurney_crash.wav: a gurney shoved over by the monster, steel on tiles,
- neon_buzz.wav: a fluorescent tube that buzzes, its starter ticking (loop),
Ambience (plain players, never through NoiseBus, so they betray nobody):
- ventilation.wav: the roar of the boiler room and the theatres' ducts, a
  deep hum, a rattling grille (loop),
- distant_roll.wav: far down a corridor, something rolls over the tiles,
  slows, stops,
- distant_slam.wav: a metal door slammed somewhere below, its echo,
- drip.wav: water dripping in a dark room, in a tiled echo (loop).
The loops are seamless: their noise is periodic, their tones have whole
numbers of cycles over the loop.
    python tools/audio/hospital_sounds.py <out_dir>   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, band, creak, save, shaped_noise  # noqa: E402
from loop_sounds import burst, place, ring  # noqa: E402

rng = np.random.default_rng(1414)


def _tone(seconds, freq, attack=0.005, release=0.02):
    t = np.arange(int(seconds * RATE)) / RATE
    env = np.minimum(1.0, t / attack) * np.minimum(1.0, (seconds - t) / release)
    return (np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 3 * t)) * env


def _echo(sound, delays, decay):
    """A tiled room: a few late copies, quieter and duller each time."""
    out = np.zeros(sound.size + int(max(delays) * RATE) + 1)
    out[: sound.size] += sound
    level = 1.0
    for d in delays:
        level *= decay
        i = int(d * RATE)
        dull = np.convolve(sound, np.ones(6) / 6, mode="same")
        out[i : i + sound.size] += dull * level
    return out


def monitor_beep(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    for at, freq in ((0.0, 960), (0.22, 960), (0.44, 1280)):
        place(out, _tone(0.15, freq), at)
    return _echo(out, (0.09, 0.17), 0.35)[: out.size]


def roll(seconds=0.5):
    out = np.zeros(int(seconds * RATE))
    at = 0.0
    while at < seconds - 0.02:  # The casters rattling over the joints.
        place(out, ring(0.04, ((rng.uniform(700, 1100), 1.0), (2600, 0.4)), 0.006), at, rng.uniform(0.2, 0.5))
        place(out, burst(0.03, 300, 3000, 0.008), at, rng.uniform(0.2, 0.4))
        at += rng.uniform(0.025, 0.06)
    rumble = shaped_noise(seconds, band(80, 500, 1.0)) * 0.35
    out += rumble * np.sin(np.pi * np.arange(out.size) / out.size) ** 0.5
    squeak = creak(0.22, 420, 0.3)  # A dry wheel.
    place(out, squeak / np.max(np.abs(squeak)), 0.12, 0.45)
    return out


def gurney_crash(seconds=1.6):
    out = np.zeros(int(seconds * RATE))
    hit = ring(1.0, ((220, 1.0), (517, 0.8), (1130, 0.55), (2410, 0.35), (3900, 0.2)), 0.12)
    place(out, hit + burst(1.0, 60, 4000, 0.05), 0.0, 1.0)
    place(out, ring(0.5, ((340, 1.0), (790, 0.6), (1700, 0.3)), 0.06), 0.28, 0.5)  # It bounces.
    place(out, burst(0.4, 200, 2500, 0.08), 0.3, 0.3)  # The mattress.
    for _ in range(5):  # A tray, bits of metal.
        place(out, ring(0.12, ((rng.uniform(1800, 3200), 1.0),), 0.02), rng.uniform(0.15, 0.9), rng.uniform(0.1, 0.3))
    return _echo(out, (0.11, 0.23), 0.3)[: out.size]


def neon_buzz(seconds=4.0):
    t = np.arange(int(seconds * RATE)) / RATE
    hum = np.zeros_like(t)
    for harmonic, level in ((1, 0.6), (2, 1.0), (3, 0.5), (4, 0.4), (6, 0.2), (8, 0.12), (12, 0.06)):
        hum += level * np.sin(2 * np.pi * 50 * harmonic * t)
    hum = np.tanh(hum * 1.5)  # The ballast's harsh edge.
    out = hum * (1.0 + 0.1 * np.sin(2 * np.pi * 1.0 * t))  # Four slow swells.
    out += shaped_noise(seconds, band(3000, 8000, 0.5)) * 0.04
    for at in (0.7, 1.9, 3.1):  # The starter ticking.
        place(out, ring(0.03, ((3300, 1.0), (6100, 0.5)), 0.004), at, 0.5)
    return out


def ventilation(seconds=6.0):
    t = np.arange(int(seconds * RATE)) / RATE
    roar = shaped_noise(seconds, band(40, 900, 1.5))
    roar *= 1.0 + 0.15 * np.sin(2 * np.pi * (1 / 3) * t)  # Two slow breaths.
    hum = 0.35 * np.sin(2 * np.pi * 47.5 * t) + 0.15 * np.sin(2 * np.pi * 95 * t)
    out = roar + hum
    beat = 1.0 / 6.0
    at = 0.0
    while at < seconds - 0.05:  # A loose grille rattling in the draught.
        place(out, ring(0.05, ((rng.uniform(600, 900), 1.0), (1900, 0.4)), 0.008), at, rng.uniform(0.04, 0.12))
        at += beat
    return out


def distant_roll(seconds=4.5):
    n = int(seconds * RATE)
    out = np.zeros(n)
    at, gap = 0.0, 0.03
    while at < 3.6:  # Rattling, slowing down.
        place(out, ring(0.05, ((rng.uniform(600, 900), 1.0),), 0.008), at, rng.uniform(0.3, 0.6))
        at += gap * rng.uniform(0.8, 1.2)
        gap *= 1.035
    rumble = shaped_noise(seconds, band(60, 400, 1.0)) * 0.6
    rumble *= np.clip(1.0 - np.arange(n) / (3.8 * RATE), 0, 1)
    out += rumble
    place(out, creak(0.4, 300, 0.4), 3.7, 0.6)  # It stops, with a squeak.
    far = np.convolve(out, np.ones(14) / 14, mode="same")  # Far: dull.
    return _echo(far, (0.13, 0.27, 0.42), 0.45)[:n]


def distant_slam(seconds=3.0):
    n = int(seconds * RATE)
    out = np.zeros(n)
    place(out, ring(1.2, ((110, 1.0), (260, 0.7), (590, 0.4), (1240, 0.2)), 0.12), 0.0)
    place(out, burst(0.6, 50, 1500, 0.05), 0.0)
    far = np.convolve(out, np.ones(18) / 18, mode="same")
    return _echo(far, (0.19, 0.41, 0.66, 0.95), 0.5)[:n]


def drip(seconds=5.0):
    out = np.zeros(int(seconds * RATE))
    for at in (0.3, 1.45, 2.2, 3.6, 4.4):
        pitch = rng.uniform(1400, 2200)
        t = np.arange(int(0.08 * RATE)) / RATE
        plop = np.sin(2 * np.pi * pitch * t * (1 + 2.5 * t)) * np.exp(-t / 0.015)
        place(out, plop, at, rng.uniform(0.5, 1.0))
    wet = _echo(out, (0.07, 0.15, 0.24), 0.4)
    tail = wet[out.size :]
    wet = wet[: out.size].copy()
    wet[: tail.size] += tail  # Wrap the echo round, so the loop is seamless.
    return wet + shaped_noise(seconds, band(100, 2000, 1.0)) * 0.01


def _fade(sound, seconds=0.03):
    """A one-shot ends in silence, without a click."""
    n = min(sound.size, int(seconds * RATE))
    sound = sound.copy()
    sound[-n:] *= np.linspace(1.0, 0.0, n)
    return sound


LOOPS = ("neon_buzz", "ventilation", "drip")
SOUNDS = {
    "monitor_beep": (monitor_beep, 0.6),
    "roll": (roll, 0.6),
    "gurney_crash": (gurney_crash, 0.9),
    "neon_buzz": (neon_buzz, 0.35),
    "ventilation": (ventilation, 0.7),
    "distant_roll": (distant_roll, 0.6),
    "distant_slam": (distant_slam, 0.7),
    "drip": (drip, 0.5),
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/hospital"
    os.makedirs(out, exist_ok=True)
    for name, (make, level) in SOUNDS.items():
        sound = make()
        save(os.path.join(out, name + ".wav"), sound if name in LOOPS else _fade(sound), level)
