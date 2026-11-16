"""Synthesises the sounds of the prison and the network of the cité (S-018, T-269).

Made by us from noise and oscillators: no sample from anyone else.
- keyboard.wav: a few keys of an old beige keyboard typed (terminal in use),
- hard_disk.wav: the hard disk of a terminal seeking while it downloads,
- prison_bell.wav: the electric bell of the prison when the guard opens it,
- loudspeaker.wav: one second of the loudspeakers' alarm, saturated,
- cage_gate.wav: the sliding grille of a cage, steel on its rail and a clang,
- keypad_beep.wav: the transformer's keypad refusing a wrong code,
- relay_click.wav: a relay switch thrown (or clicking back), lever and relay,
- camera_break.wav: a security camera smashed, plastic, glass and a spark.
    python tools/audio/network_sounds.py <out_dir>   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, save  # noqa: E402
from interior_sounds import _mix, _norm  # noqa: E402
from loop_sounds import burst, place, ring  # noqa: E402

rng = np.random.default_rng(2018)


def _square(seconds, pitch):
    t = np.arange(int(seconds * RATE)) / RATE
    return np.sign(np.sin(2 * np.pi * pitch * t))


def _key():
    """One key: the plastic cap hitting bottom, a small spring."""
    click = burst(0.04, 1500, 7000, 0.004)
    thock = ring(0.05, ((rng.uniform(350, 500), 1.0), (1300, 0.3)), 0.008)
    return _mix(click, thock * 0.6)


def keyboard(seconds=1.2):
    out = np.zeros(int(seconds * RATE))
    at = 0.0
    while at < 1.05:
        place(out, _key(), at, rng.uniform(0.5, 1.0))
        at += rng.uniform(0.07, 0.16)
    place(out, _mix(_key(), burst(0.06, 600, 4000, 0.01)), 1.08, 1.0)  # The space bar.
    return out


def hard_disk(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    whine = ring(seconds, ((5400 / 60 * 12, 0.05),), 10.0)  # The platters spinning.
    out += whine
    at = 0.05
    while at < 0.9:  # The head seeking: dry little ticks in bursts.
        for _ in range(rng.integers(2, 6)):
            place(out, burst(0.012, 2000, 9000, 0.002), at, rng.uniform(0.4, 1.0))
            at += rng.uniform(0.012, 0.03)
        at += rng.uniform(0.06, 0.2)
    return out


def prison_bell(seconds=2.4):
    out = np.zeros(int(seconds * RATE))
    t = np.arange(int(2.0 * RATE)) / RATE
    strikes = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 22 * t))  # The hammer, 22 times a second.
    gong = ring(2.0, ((1180, 1.0), (2830, 0.5), (4400, 0.2)), 3.0)
    rattle = burst(2.0, 300, 3000, 3.0) * 0.15
    out[: t.size] += (gong + rattle) * (0.6 + 0.4 * strikes)
    place(out, ring(0.4, ((1180, 1.0), (2830, 0.4)), 0.12), 2.0, 0.6)  # It dies away.
    return out


def loudspeaker(seconds=1.0):
    t = np.arange(int(seconds * RATE)) / RATE
    pitch = 620 + 260 * (t / seconds)  # A rising whoop.
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(pitch) / RATE))
    hum = 0.3 * np.sin(2 * np.pi * 50 * t)
    hiss = burst(seconds, 2000, 8000, 5.0) * 0.25
    out = np.tanh(3.0 * (tone * 0.7 + hum + hiss))  # Overdriven cheap horn.
    fade = np.ones_like(out)
    fade[-400:] = np.linspace(1, 0, 400)
    return out * fade


def cage_gate(seconds=1.4):
    out = np.zeros(int(seconds * RATE))
    place(out, ring(0.12, ((1900, 1.0), (4200, 0.5)), 0.015), 0.0, 0.7)  # The bolt.
    grind = burst(0.8, 400, 4000, 0.8)
    grind *= np.sin(np.linspace(0, np.pi, grind.size)) ** 0.5
    squeal = ring(0.8, ((1450, 0.6), (2950, 0.3)), 0.8) * (0.5 + 0.5 * np.sin(np.linspace(0, 30, grind.size)))
    place(out, _mix(grind, squeal * 0.3), 0.1, 0.5)  # The wheels on the rail.
    clang = _mix(ring(0.5, ((260, 1.0), (610, 0.8), (1390, 0.5), (3100, 0.3)), 0.07), burst(0.2, 100, 3000, 0.02))
    place(out, clang, 0.88, 1.0)  # Against the stop.
    return out


def keypad_beep(seconds=0.5):
    out = np.zeros(int(seconds * RATE))
    place(out, _square(0.14, 880) * 0.5, 0.0)
    place(out, _square(0.22, 440) * 0.5, 0.18)  # Low: wrong.
    return out


def relay_click(seconds=0.7):
    out = np.zeros(int(seconds * RATE))
    lever = _mix(ring(0.3, ((310, 1.0), (760, 0.6), (1700, 0.3)), 0.04), burst(0.1, 200, 4000, 0.01))
    place(out, lever, 0.0, 1.0)  # The handle slammed down.
    place(out, ring(0.06, ((3300, 1.0), (6100, 0.4)), 0.005), 0.09, 0.7)  # The relay inside.
    place(out, burst(0.4, 60, 300, 0.12), 0.1, 0.4)  # A thump in the cabinet.
    return out


def camera_break(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    place(out, burst(0.12, 300, 5000, 0.02), 0.0, 1.0)  # The housing cracking.
    at = 0.03
    while at < 0.35:  # The lens and the plastic falling.
        tink = ring(0.08, ((rng.uniform(2500, 6000), 1.0),), 0.012)
        place(out, tink, at, rng.uniform(0.2, 0.6))
        at += rng.exponential(0.04)
    spark = burst(0.25, 3000, 10000, 0.05)
    spark *= rng.random(spark.size) < 0.3  # Crackling.
    place(out, spark, 0.15, 0.5)
    place(out, _norm(ring(0.3, ((50, 1.0), (100, 0.5)), 0.08)) * 0.3, 0.16)  # The supply shorting.
    return out


SOUNDS = {
    "keyboard": (keyboard, 0.5),
    "hard_disk": (hard_disk, 0.5),
    "prison_bell": (prison_bell, 0.8),
    "loudspeaker": (loudspeaker, 0.8),
    "cage_gate": (cage_gate, 0.7),
    "keypad_beep": (keypad_beep, 0.5),
    "relay_click": (relay_click, 0.8),
    "camera_break": (camera_break, 0.8),
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/network"
    os.makedirs(out, exist_ok=True)
    for name, (make, level) in SOUNDS.items():
        save(os.path.join(out, name + ".wav"), make(), level)
