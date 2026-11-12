"""Synthesises the sounds of the hunted's ruses (S-008, T-070).

Made by us from noise and oscillators: no sample from anyone else.
- glass_break.wav: an empty bottle shattering on concrete,
- clock_tick.wav: the tic-tac of an old alarm clock, one second (loop),
- clock_ring.wav: its two bells hammered fast, one second (loop),
- clock_crush.wav: the alarm clock crushed under a foot, a last bell hit,
- locker_door.wav: the dented door of a metal locker, creak and latch,
- bin_lid.wav: the heavy plastic lid of a dumpster, creak and thud.
The loops are seamless: they hold whole cycles and end on silence.
    python tools/audio/ruse_sounds.py <out_dir>   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, creak, save  # noqa: E402
from loop_sounds import burst, place, ring  # noqa: E402

rng = np.random.default_rng(2008)


def glass_break(seconds=0.9):
    out = np.zeros(int(seconds * RATE))
    impact = ring(0.3, ((2100, 1.0), (3350, 0.8), (4870, 0.6), (6900, 0.4)), 0.03)
    impact += burst(0.3, 2000, 9000, 0.02) * 1.2
    place(out, impact, 0.0)
    thud = burst(0.12, 80, 500, 0.02)
    place(out, thud, 0.0, 0.6)
    at = 0.03
    while at < 0.7:  # Shards skittering and tinkling, fewer and fewer.
        pitch = rng.uniform(3000, 6000)
        shard = ring(0.08, ((pitch, 1.0), (pitch * 1.53, 0.5)), 0.01)
        place(out, shard, at, rng.uniform(0.2, 0.7) * (1.0 - at))
        at += rng.exponential(0.04)
    return out


def _click(pitch, level):
    return (ring(0.05, ((pitch, 1.0), (pitch * 2.7, 0.4)), 0.006) + burst(0.05, 2000, 7000, 0.002)) * level


def clock_tick(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    place(out, _click(2600, 1.0), 0.0)  # Tic.
    place(out, _click(2200, 0.8), 0.5)  # Tac, a little lower.
    return out


def clock_ring(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    strikes = 18
    for i in range(strikes):  # The hammer between the two bells.
        pitch = 2350 if i % 2 == 0 else 2510
        bell = ring(seconds / strikes, ((pitch, 1.0), (pitch * 2.76, 0.45), (pitch * 3.9, 0.15)), 0.03)
        place(out, bell, i * seconds / strikes)
    return out


def clock_crush(seconds=0.6):
    out = np.zeros(int(seconds * RATE))
    place(out, burst(0.3, 300, 4000, 0.03), 0.0)  # Tin crumpling.
    place(out, burst(0.2, 60, 400, 0.03), 0.0, 0.8)  # The foot.
    place(out, ring(0.5, ((2350, 1.0), (6490, 0.3)), 0.08), 0.02, 0.5)  # A last, dull bell.
    for at in (0.05, 0.09, 0.16):  # Springs and gears popping.
        place(out, ring(0.06, ((rng.uniform(3000, 6000), 1.0),), 0.01), at, 0.4)
    return out


def locker_door(seconds=0.9):
    out = np.zeros(int(seconds * RATE))
    hinge = creak(0.45, 230, 0.5)
    place(out, hinge / np.max(np.abs(hinge)), 0.0, 0.6)
    slam = ring(0.4, ((310, 1.0), (790, 0.7), (1650, 0.4), (2900, 0.2)), 0.07)
    slam += burst(0.4, 200, 3000, 0.01)
    place(out, slam, 0.45)
    latch = ring(0.1, ((1900, 1.0), (4300, 0.4)), 0.015)
    place(out, latch, 0.5, 0.5)
    return out


def bin_lid(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    hinge = creak(0.5, 120, 0.3)
    place(out, hinge / np.max(np.abs(hinge)), 0.0, 0.5)
    thud = burst(0.35, 50, 600, 0.05) + ring(0.35, ((110, 1.0), (260, 0.4)), 0.08) * 0.6
    place(out, thud, 0.5)
    return out


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/ruses"
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "glass_break.wav"), glass_break(), 0.8)
    save(os.path.join(out, "clock_tick.wav"), clock_tick(), 0.5)
    save(os.path.join(out, "clock_ring.wav"), clock_ring(), 0.7)
    save(os.path.join(out, "clock_crush.wav"), clock_crush(), 0.8)
    save(os.path.join(out, "locker_door.wav"), locker_door(), 0.8)
    save(os.path.join(out, "bin_lid.wav"), bin_lid(), 0.8)
