"""Synthesises the voices of Écho (spec S-012, T-145 and T-149).

Made by us from noise, pulses and oscillators: no sample from anyone else.
The monster (assets/audio/voices/):
- monster_breath.wav: a slow, hoarse breath, out then in (the 2 m BREATH),
- monster_growl_N.wav: three growls, a low throat rumble with a rough edge
  (GROWL, when it starts to run),
- monster_scream.wav: its cry when it catches a hunted (SCREAM, 30 m),
- scan_drone.wav: the pressure in its head while it scans, for it alone
  (loop),
- scan_crackle.wav: the crackle of a lamp flickering in a scanned building
  (loop, ambience).
The hunted and the cité (T-149):
- hunted_breath.wav: a hunted out of breath, panting,
- call_for_help.wav: a caught hunted calling, muffled ("hé... ici"),
- rescue.wav: a teammate freeing a caught hunted: a struggle, a grunt,
- car_alarm.wav: one second of a car alarm (it rings once a second).
    python tools/audio/voices.py [out_dir]   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, band, peak, save, shaped_noise  # noqa: E402
from loop_sounds import burst, place  # noqa: E402

rng = np.random.default_rng(66)


def _t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def _fft_filter(signal, shape):
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / RATE)
    return np.fft.irfft(spectrum * shape(freqs), signal.size)


def _formants(signal, formants):
    """A voice's mouth: a sum of resonant peaks (Hz, width, level)."""
    def shape(f):
        out = np.zeros_like(f)
        for center, width, level in formants:
            out += level * np.exp(-(((f - center) / width) ** 2))
        return out

    return _fft_filter(signal, shape)


def _glottis(pitch_curve, jitter=0.02):
    """Pulses of a throat at a pitch (Hz per sample), a little irregular."""
    wobble = 1.0 + jitter * shaped_noise(pitch_curve.size / RATE, lambda f: (f > 0) * (f < 30))
    phase = np.cumsum(pitch_curve * wobble) / RATE
    saw = 2.0 * (phase % 1.0) - 1.0
    return saw - np.convolve(saw, np.ones(4) / 4, mode="same")


def _env(n, attack, release):
    t = np.arange(n) / RATE
    length = n / RATE
    return np.clip(t / attack, 0, 1) * np.clip((length - t) / release, 0, 1)


def monster_breath(seconds=0.95):
    n = int(seconds * RATE)
    out = np.zeros(n)
    exhale = shaped_noise(0.5, band(150, 1800, 1.2))
    exhale = _formants(exhale, ((300, 120, 1.0), (750, 200, 0.6), (1400, 300, 0.25)))
    rasp = _glottis(np.full(exhale.size, 38.0), 0.15) * 0.25
    place(out, (exhale + _formants(rasp, ((250, 150, 1.0), (900, 300, 0.4)))) * _env(exhale.size, 0.08, 0.25), 0.0)
    inhale = shaped_noise(0.35, band(400, 3000, 0.8))
    inhale = _formants(inhale, ((900, 300, 1.0), (2200, 500, 0.5)))
    place(out, inhale * _env(inhale.size, 0.2, 0.08), 0.58, 0.45)
    return out


def monster_growl(seconds=1.3, base=62.0):
    t = _t(seconds)
    pitch = base * (1.0 + 0.25 * np.sin(np.pi * t / seconds)) * rng.uniform(0.9, 1.1)
    throat = _glottis(pitch, 0.12)
    rough = 1.0 + 0.6 * np.sin(2 * np.pi * rng.uniform(24, 32) * t)
    voice = _formants(throat * rough, ((180, 90, 1.0), (520, 160, 0.7), (1100, 250, 0.3)))
    noise = _formants(shaped_noise(seconds, band(100, 2500, 1.0)), ((300, 200, 1.0), (800, 300, 0.5)))
    out = voice + 0.35 * noise
    return out * _env(t.size, 0.12, 0.4)


def monster_scream(seconds=1.9):
    t = _t(seconds)
    pitch = 140 + 260 * np.sin(np.pi * np.clip(t / (seconds * 0.8), 0, 1)) ** 0.6
    throat = _glottis(pitch, 0.08)
    sub = _glottis(pitch / 2.0, 0.1) * 0.6
    voice = _formants(throat + sub, ((650, 200, 1.0), (1200, 300, 0.8), (2600, 500, 0.5), (3500, 600, 0.3)))
    hiss = _formants(shaped_noise(seconds, band(500, 6000, 0.6)), ((2500, 900, 1.0),))
    out = np.tanh(2.5 * (voice / np.max(np.abs(voice)) + 0.4 * hiss))
    out *= _env(t.size, 0.06, 0.7)
    # The street throws it back.
    echo = np.zeros(out.size + int(0.3 * RATE))
    echo[: out.size] += out
    echo[int(0.22 * RATE) : int(0.22 * RATE) + out.size] += 0.3 * np.convolve(out, np.ones(8) / 8, "same")
    return echo


def scan_drone(seconds=4.0):
    """Seamless: whole cycles of every tone over the loop."""
    t = _t(seconds)
    out = np.zeros_like(t)
    for freq, level in ((55.0, 1.0), (55.5, 0.8), (110.25, 0.35), (164.75, 0.2), (440.0, 0.04)):
        cycles = round(freq * seconds)
        out += level * np.sin(2 * np.pi * cycles / seconds * t)
    out += 0.15 * shaped_noise(seconds, band(60, 400, 1.5))
    return out


def scan_crackle(seconds=2.0):
    out = 0.15 * shaped_noise(seconds, band(80, 200, 1.0))
    hum_cycles = round(100 * seconds)
    out += 0.2 * np.sin(2 * np.pi * hum_cycles / seconds * _t(seconds))
    for _ in range(26):
        at = rng.uniform(0, seconds - 0.05)
        place(out, burst(0.04, 1500, 8000, 0.004) * rng.uniform(0.3, 1.0), at)
    return out


def hunted_breath(seconds=0.9):
    out = np.zeros(int(seconds * RATE))
    for at, length, level, formants in (
        (0.0, 0.3, 1.0, ((700, 250, 1.0), (1200, 300, 0.6))),
        (0.42, 0.28, 0.7, ((1100, 300, 1.0), (2400, 500, 0.5))),
    ):
        puff = _formants(shaped_noise(length, band(300, 5000, 0.8)), formants)
        place(out, puff * _env(puff.size, 0.03, 0.15), at, level)
    return out


def call_for_help(seconds=1.1):
    out = np.zeros(int(seconds * RATE))
    for at, length, start, end, vowel in (
        (0.0, 0.35, 260, 300, ((550, 120, 1.0), (1700, 250, 0.4))),  # "hé"
        (0.55, 0.45, 280, 210, ((420, 110, 1.0), (2000, 300, 0.3))),  # "ici"
    ):
        t = _t(length)
        pitch = start + (end - start) * t / length
        word = _formants(_glottis(pitch, 0.03), vowel + ((2800, 400, 0.15),))
        word += 0.2 * _formants(shaped_noise(length, band(500, 4000, 1.0)), vowel)
        place(out, word * _env(t.size, 0.04, 0.12), at)
    # Far and muffled: through a cage, a corridor.
    return _fft_filter(out, lambda f: 1.0 / np.sqrt(1.0 + (f / 1800.0) ** 4))


def rescue(seconds=0.9):
    out = np.zeros(int(seconds * RATE))
    for _ in range(9):
        at = rng.uniform(0, seconds - 0.2)
        place(out, burst(0.18, 600, 6000, 0.04) * rng.uniform(0.3, 0.8), at)
    t = _t(0.3)
    grunt = _formants(_glottis(np.full(t.size, 140.0) * (1 - 0.2 * t / 0.3), 0.05), ((500, 150, 1.0), (1100, 250, 0.4)))
    place(out, grunt * _env(t.size, 0.03, 0.15), 0.35, 0.8)
    return out


def car_alarm(seconds=1.0):
    t = _t(seconds)
    # Two tones, a fast whoop between them: a cheap alarm, loud and nasal.
    freq = np.where((t % 0.5) < 0.25, 980.0, 760.0)
    phase = np.cumsum(freq) / RATE
    square = np.sign(np.sin(2 * np.pi * phase))
    out = _fft_filter(square, lambda f: peak(1600, 900)(f) + 0.5 * peak(3200, 900)(f) + 0.2)
    return out * (0.85 + 0.15 * np.sin(2 * np.pi * 8 * t))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/voices"
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "monster_breath.wav"), monster_breath(), 0.7)
    for i, base in enumerate((58.0, 66.0, 74.0)):
        save(os.path.join(out, "monster_growl_%d.wav" % i), monster_growl(base=base), 0.9)
    save(os.path.join(out, "monster_scream.wav"), monster_scream(), 0.9)
    save(os.path.join(out, "scan_drone.wav"), scan_drone(), 0.6)
    save(os.path.join(out, "scan_crackle.wav"), scan_crackle(), 0.5)
    save(os.path.join(out, "hunted_breath.wav"), hunted_breath(), 0.6)
    save(os.path.join(out, "call_for_help.wav"), call_for_help(), 0.8)
    save(os.path.join(out, "rescue.wav"), rescue(), 0.8)
    save(os.path.join(out, "car_alarm.wav"), car_alarm(), 0.7)
