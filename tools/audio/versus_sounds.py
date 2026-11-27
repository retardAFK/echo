"""Synthesises the sounds of the Versus arcade (spec S-025, T-410): bright,
punchy, toy-like (an arcade shooter, not horror).
- smg_shot.wav: the light machine gun, a short laser pop,
- rifle_shot.wav: the precision flare rifle, a crack and a whoosh,
- shotgun_shot.wav: the sonic shotgun, a bass blast that wobbles,
- hit.wav: the tick of a hit on the boss; hit_face.wav: the ding of a head,
- reload.wav: two clicks and a charge,
- chest_open.wav: a sparkle going up (a major arpeggio),
- flash.wav: the flash grenade, a pop and a ringing,
- zone_warning.wav: the zone about to close, two rising synth notes.
    python tools/audio/versus_sounds.py [out_dir]   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, save  # noqa: E402

rng = np.random.default_rng(2511)


def time(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def sweep(seconds, start, end, curve=3.0):
    """A sine whose pitch glides from start to end (Hz), fast then slow."""
    t = time(seconds)
    freq = end + (start - end) * np.exp(-curve * t / seconds)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def decay(seconds, tau):
    return np.exp(-time(seconds) / tau)


def lowpass(signal, cutoff):
    """One pole low pass (cutoff in Hz)."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    y = 0.0
    for i, x in enumerate(signal):
        y = (1 - a) * x + a * y
        out[i] = y
    return out


def noise(seconds):
    return rng.uniform(-1, 1, int(seconds * RATE))


def place(total, sound, at):
    out = np.zeros(int(total * RATE))
    a = int(at * RATE)
    end = min(out.size, a + sound.size)
    out[a:end] += sound[: end - a]
    return out


def smg_shot(seconds=0.2):
    zap = sweep(seconds, 2200, 380, 5) * decay(seconds, 0.045)
    thump = sweep(seconds, 160, 70, 4) * decay(seconds, 0.05)
    click = noise(seconds) * decay(seconds, 0.006)
    return 0.7 * zap + 0.9 * thump + 0.5 * click


def rifle_shot(seconds=1.0):
    crack = noise(seconds) * decay(seconds, 0.02)
    boom = sweep(seconds, 220, 55, 4) * decay(seconds, 0.12)
    whoosh = lowpass(noise(seconds), 1800) * np.exp(-((time(seconds) - 0.18) ** 2) / 0.02)
    hiss = (noise(seconds) - lowpass(noise(seconds), 3000)) * decay(seconds, 0.35) * 0.3
    zing = sweep(seconds, 3200, 900, 2) * decay(seconds, 0.18) * 0.35
    return 1.0 * crack + 1.0 * boom + 1.6 * whoosh + hiss + zing


def ar_shot(seconds=0.3):
    """The assault rifle (T-413): heavier than the machine gun, a short tail."""
    crack = noise(seconds) * decay(seconds, 0.008)
    zap = sweep(seconds, 1500, 260, 4) * decay(seconds, 0.05)
    thump = sweep(seconds, 130, 50, 4) * decay(seconds, 0.07)
    tail = lowpass(noise(seconds), 1200) * decay(seconds, 0.09) * 0.5
    return 0.8 * crack + 0.6 * zap + 1.1 * thump + tail


def fireball_cast(seconds=0.6):
    """The boss throws a fireball (T-413): a roaring whoosh that rises."""
    t = time(seconds)
    roar = lowpass(noise(seconds), 900) * np.minimum(1, t / 0.08) * decay(seconds, 0.22)
    rise = sweep(seconds, 90, 260, 1.5) * np.minimum(1, t / 0.05) * decay(seconds, 0.25)
    crackle = (noise(seconds) - lowpass(noise(seconds), 2500)) * decay(seconds, 0.3) * 0.25
    return 1.4 * roar + 0.6 * rise + crackle


def fireball_boom(seconds=1.3):
    """A fireball bursts: a deep boom, then fire crackling out."""
    boom = sweep(seconds, 120, 35, 3) * decay(seconds, 0.25)
    blast = lowpass(noise(seconds), 600) * decay(seconds, 0.18)
    crackle = (noise(seconds) - lowpass(noise(seconds), 2000)) * decay(seconds, 0.45) * 0.35
    return 1.2 * boom + 1.3 * blast + crackle


def shotgun_shot(seconds=0.7):
    t = time(seconds)
    wobble = 1 + 0.35 * np.sin(2 * np.pi * 22 * t)
    freq = (45 + 120 * np.exp(-t / 0.08)) * wobble
    bass = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * decay(seconds, 0.22)
    blast = lowpass(noise(seconds), 2500) * decay(seconds, 0.05)
    ring = np.sin(2 * np.pi * 620 * t) * decay(seconds, 0.15) * 0.25
    return 1.4 * bass + 1.0 * blast + ring


def hit(seconds=0.09):
    t = time(seconds)
    return (np.sin(2 * np.pi * 2400 * t) + 0.4 * np.sin(2 * np.pi * 3600 * t)) * decay(
        seconds, 0.02
    )


def hit_face(seconds=0.35):
    t = time(seconds)
    bell = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((1760, 1.0), (2640, 0.5), (3520, 0.3)))
    return bell * decay(seconds, 0.09) + 0.4 * hit(seconds)


def reload(seconds=0.7):
    def click(pitch):
        s = 0.06
        return (noise(s) * 0.6 + np.sin(2 * np.pi * pitch * time(s))) * decay(s, 0.008)

    rise = np.linspace(300, 1400, int(0.3 * RATE))
    charge = np.sin(2 * np.pi * np.cumsum(rise) / RATE) * np.linspace(0, 1, rise.size) * 0.25
    return place(seconds, click(900), 0.0) + place(seconds, click(1300), 0.3) + place(
        seconds, charge, 0.36
    )


def chest_open(seconds=0.9):
    out = np.zeros(int(seconds * RATE))
    for i, freq in enumerate((523.3, 659.3, 784.0, 1046.5, 1318.5)):
        s = 0.45
        t = time(s)
        note = (np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)) * decay(
            s, 0.12
        )
        out += place(seconds, note, i * 0.07)
    return out


def flash(seconds=1.4):
    t = time(seconds)
    pop = lowpass(noise(seconds), 4000) * decay(seconds, 0.03) * 1.5
    ring = (np.sin(2 * np.pi * 3100 * t) + 0.5 * np.sin(2 * np.pi * 3170 * t)) * decay(
        seconds, 0.45
    )
    return pop + 0.35 * ring


def zone_warning(seconds=1.6):
    out = np.zeros(int(seconds * RATE))
    for i, freq in enumerate((440.0, 659.3)):
        s = 0.7
        t = time(s)
        saw = sum(np.sin(2 * np.pi * freq * k * t) / k for k in range(1, 7))
        env = np.minimum(1, t / 0.05) * np.exp(-t / 0.4)
        out += place(seconds, saw * env * (1 + 0.2 * np.sin(2 * np.pi * 6 * t)), i * 0.5)
    return lowpass(out, 3000)


def pistol_shot(seconds=0.35):
    """The pulse pistol (T-415): a bright laser zap that rings."""
    zap = sweep(seconds, 3200, 600, 3) * decay(seconds, 0.06)
    ring = sweep(seconds, 1400, 1300, 1) * decay(seconds, 0.1) * 0.3
    click = noise(seconds) * decay(seconds, 0.005)
    return 0.9 * zap + ring + 0.5 * click


def minigun_shot(seconds=0.12):
    """The neon minigun (T-415): a short buzzing tick, many a second."""
    buzz = sweep(seconds, 900, 300, 3) * decay(seconds, 0.03)
    thump = sweep(seconds, 110, 60, 3) * decay(seconds, 0.03)
    click = noise(seconds) * decay(seconds, 0.004)
    return 0.6 * buzz + 0.9 * thump + 0.4 * click


def burst_shot(seconds=0.25):
    """The burst rifle (T-415): a crisp, mid zap."""
    zap = sweep(seconds, 2600, 420, 4) * decay(seconds, 0.04)
    thump = sweep(seconds, 150, 60, 4) * decay(seconds, 0.05)
    crack = noise(seconds) * decay(seconds, 0.006)
    return 0.8 * zap + 0.9 * thump + 0.6 * crack


SOUNDS = {
    "smg_shot": (smg_shot, 0.8),
    "rifle_shot": (rifle_shot, 0.9),
    "shotgun_shot": (shotgun_shot, 0.9),
    "hit": (hit, 0.5),
    "hit_face": (hit_face, 0.6),
    "reload": (reload, 0.6),
    "chest_open": (chest_open, 0.6),
    "flash": (flash, 0.8),
    "zone_warning": (zone_warning, 0.6),
    # Last: the sounds above keep their random draws.
    "ar_shot": (ar_shot, 0.85),
    "fireball_cast": (fireball_cast, 0.8),
    "fireball_boom": (fireball_boom, 0.95),
    "pistol_shot": (pistol_shot, 0.8),
    "minigun_shot": (minigun_shot, 0.7),
    "burst_shot": (burst_shot, 0.85),
}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/versus"
    os.makedirs(out, exist_ok=True)
    for name, (make, level) in SOUNDS.items():
        save(os.path.join(out, name + ".wav"), make(), level)
