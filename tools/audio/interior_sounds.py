"""Synthesises the sounds of the building interiors (S-016, T-242).

Made by us from noise and oscillators: no sample from anyone else.
Doors (game/entities/door):
- door_open.wav: a flat door opened standing, the handle, a short creak,
- door_quiet.wav: the same door eased open crouched, one long, faint creak,
- door_close.wav: the door pushed shut, a wooden thud and the latch,
- door_smash.wav: the running monster bursting a door open, wood cracking,
  the leaf banging against the wall,
- fire_door_slam.wav: a fire door closing on its own, the closer hissing, a
  heavy metal slam,
- crash_bar.wav: the crash bar of an emergency exit, a loud clack and a bang,
- shutter_roll.wav: a metal roller shutter rattling up (or down),
- shop_bell.wav: the bell over the baker's door, shaken by the door,
Hiding spots (game/entities/hiding_spot):
- crawl.wav: crawling under a bed or the stage, cloth dragged over dusty floor,
- rustle.wav: slipping behind cardboard, curtains or stacked chairs,
- metal_cabinet.wav: the stainless door of a cold cabinet, the seal and a clunk.
    python tools/audio/interior_sounds.py <out_dir>   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, creak, save  # noqa: E402
from loop_sounds import burst, place, ring  # noqa: E402

rng = np.random.default_rng(2016)


def _mix(*sounds):
    """Sounds of different lengths added from their start."""
    out = np.zeros(max(s.size for s in sounds))
    for s in sounds:
        out[: s.size] += s
    return out


def _norm(sound):
    return sound / np.max(np.abs(sound))


def _knock(seconds, low, high, level=1.0):
    """Wood struck: a dull low body and a short crack."""
    body = ring(seconds, ((low, 1.0), (low * 2.3, 0.5), (low * 3.9, 0.2)), 0.025)
    crack = burst(seconds, 300, high, 0.008)
    return (body + crack) * level


def _latch(level=1.0):
    return _mix(ring(0.08, ((2100, 1.0), (4700, 0.5)), 0.01), burst(0.05, 2000, 8000, 0.003) * 0.4) * level


def door_open(seconds=0.8):
    out = np.zeros(int(seconds * RATE))
    place(out, _latch(), 0.0, 0.7)  # The handle.
    place(out, _norm(creak(0.45, 140, 0.4)), 0.08, 0.45)
    place(out, _knock(0.2, 110, 2000), 0.55, 0.25)  # Swung against the stop.
    return out


def door_quiet(seconds=1.4):
    out = np.zeros(int(seconds * RATE))
    place(out, _latch(), 0.0, 0.25)  # The handle, held down.
    place(out, _norm(creak(1.2, 70, 0.2)), 0.12, 0.3)
    return out


def door_close(seconds=0.6):
    out = np.zeros(int(seconds * RATE))
    place(out, _norm(creak(0.2, 160, 0.3)), 0.0, 0.25)
    place(out, _knock(0.4, 95, 2500), 0.18)
    place(out, _latch(), 0.19, 0.6)
    return out


def door_smash(seconds=1.3):
    out = np.zeros(int(seconds * RATE))
    place(out, burst(0.25, 60, 600, 0.04), 0.0, 1.0)  # The shoulder.
    at = 0.0
    while at < 0.18:  # Wood splitting round the lock.
        place(out, _knock(0.08, rng.uniform(200, 500), 6000), at, rng.uniform(0.4, 0.9))
        at += rng.exponential(0.02)
    place(out, ring(0.15, ((1800, 1.0), (3900, 0.6)), 0.02), 0.04, 0.5)  # The keeper torn off.
    place(out, _knock(0.6, 85, 3000), 0.35, 1.0)  # The leaf banging the wall.
    place(out, _knock(0.3, 90, 2000), 0.62, 0.35)  # Bounce.
    for _ in range(6):  # Splinters falling.
        place(out, _knock(0.05, rng.uniform(600, 1200), 7000), rng.uniform(0.4, 1.0), rng.uniform(0.05, 0.15))
    return out


def fire_door_slam(seconds=1.6):
    out = np.zeros(int(seconds * RATE))
    hiss = burst(0.9, 2500, 9000, 0.5)  # The closer's piston.
    hiss *= np.sin(np.linspace(0, np.pi, hiss.size)) ** 2
    place(out, hiss, 0.0, 0.12)
    slam = _mix(ring(0.7, ((140, 1.0), (330, 0.7), (720, 0.45), (1530, 0.25)), 0.09), burst(0.5, 60, 2500, 0.03) * 0.8)
    place(out, slam, 0.85)
    place(out, _latch(), 0.86, 0.5)
    return out


def crash_bar(seconds=1.2):
    out = np.zeros(int(seconds * RATE))
    place(out, ring(0.2, ((900, 1.0), (2300, 0.7), (5100, 0.3)), 0.015), 0.0, 0.9)  # The bar.
    place(out, burst(0.15, 1000, 8000, 0.01), 0.0, 0.6)
    bang = _mix(ring(0.8, ((160, 1.0), (380, 0.7), (850, 0.4)), 0.08), burst(0.5, 60, 2500, 0.03) * 0.8)
    place(out, bang, 0.25)  # The door flung against the outside wall.
    return out


def shutter_roll(seconds=2.0):
    out = np.zeros(int(seconds * RATE))
    place(out, _mix(ring(0.3, ((240, 1.0), (610, 0.6)), 0.05), burst(0.2, 100, 3000, 0.02)), 0.0, 0.8)  # Unlocked.
    at = 0.12
    while at < 1.75:  # Slats rattling over the drum, faster then slower.
        progress = at / 1.75
        pitch = rng.uniform(500, 900)
        clack = _mix(ring(0.06, ((pitch, 1.0), (pitch * 2.6, 0.5)), 0.01), burst(0.05, 800, 6000, 0.006) * 0.6)
        place(out, clack, at, rng.uniform(0.25, 0.5))
        at += 0.035 + 0.03 * abs(progress - 0.4)
    rumble = burst(1.6, 40, 400, 2.0)
    rumble *= np.sin(np.linspace(0, np.pi, rumble.size))
    place(out, rumble, 0.12, 0.35)
    place(out, ring(0.4, ((180, 1.0), (470, 0.5)), 0.06), 1.75, 0.6)  # Up against the box.
    return out


def shop_bell(seconds=1.6):
    out = np.zeros(int(seconds * RATE))
    for i, at in enumerate((0.0, 0.11, 0.2, 0.33, 0.5, 0.72)):  # The clapper swinging, dying down.
        pitch = 2650 if i % 2 == 0 else 3150
        bell = ring(seconds - at, ((pitch, 1.0), (pitch * 2.32, 0.35), (pitch * 4.1, 0.12)), 0.18)
        place(out, bell, at, 1.0 - i * 0.14)
    return out


def crawl(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    for at in (0.0, 0.35, 0.65):  # Knees and elbows dragged over the floor.
        drag = burst(0.3, 400, 5000, 0.15)
        drag *= np.sin(np.linspace(0, np.pi, drag.size))
        place(out, drag, at, rng.uniform(0.5, 0.8))
    place(out, burst(0.15, 60, 300, 0.03), 0.3, 0.4)  # A knee thud.
    return out


def rustle(seconds=0.8):
    out = np.zeros(int(seconds * RATE))
    at = 0.0
    while at < 0.6:  # Crackles of cardboard and cloth.
        place(out, burst(0.08, 1000, 7000, 0.02), at, rng.uniform(0.3, 0.9))
        at += rng.exponential(0.05)
    place(out, burst(0.2, 150, 900, 0.05), 0.25, 0.4)  # Something leaned on.
    return out


def metal_cabinet(seconds=1.0):
    out = np.zeros(int(seconds * RATE))
    place(out, ring(0.15, ((1300, 1.0), (3100, 0.5)), 0.02), 0.0, 0.6)  # The lever.
    seal = burst(0.12, 200, 2000, 0.03)
    place(out, seal, 0.08, 0.5)  # The rubber seal letting go.
    clunk = _mix(ring(0.6, ((210, 1.0), (520, 0.8), (1210, 0.5), (2600, 0.25)), 0.06), burst(0.3, 80, 2000, 0.02))
    place(out, clunk, 0.45)
    return out


SOUNDS = {
    "door_open": (door_open, 0.7),
    "door_quiet": (door_quiet, 0.35),
    "door_close": (door_close, 0.7),
    "door_smash": (door_smash, 0.9),
    "fire_door_slam": (fire_door_slam, 0.9),
    "crash_bar": (crash_bar, 0.9),
    "shutter_roll": (shutter_roll, 0.8),
    "shop_bell": (shop_bell, 0.6),
    "crawl": (crawl, 0.5),
    "rustle": (rustle, 0.5),
    "metal_cabinet": (metal_cabinet, 0.8),
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/interiors"
    os.makedirs(out, exist_ok=True)
    for name, (make, level) in SOUNDS.items():
        save(os.path.join(out, name + ".wav"), make(), level)
