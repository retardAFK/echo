"""Synthesises the music of the Versus arcade (spec S-025, T-410): an upbeat
electro loop at 128 beats a minute, eight bars (15 s) over A minor, F, C, G,
in two layers of the same length that loop seamlessly and play together:
- versus_groove.wav: always there: kick on every beat, clap on 2 and 4,
  hats on the off beats, a pumping bass and chords;
- versus_rush.wav: joins in for the last minute and when the boss is near
  (VersusMusic): a sixteenth-note arpeggio lead and a snare roll.
    python tools/audio/versus_music.py [out_dir]   (needs numpy)
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ambience import RATE, save  # noqa: E402
from versus_sounds import lowpass, noise  # noqa: E402

BPM = 128
BARS = 8
BEAT = 60.0 / BPM
SECONDS = BARS * 4 * BEAT
SIZE = int(round(SECONDS * RATE))
rng = np.random.default_rng(128)
## Two bars each: A minor, F major, C major, G major (MIDI notes).
CHORDS = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)]
ROOTS = [33, 29, 36, 31]


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def at(beat):
    return int(round(beat * BEAT * RATE)) % SIZE


def put(out, sound, beat):
    """Adds sound from beat on, wrapping around the loop's end."""
    a = at(beat)
    end = a + sound.size
    if end <= SIZE:
        out[a:end] += sound
    else:
        out[a:] += sound[: SIZE - a]
        out[: end - SIZE] += sound[SIZE - a :]


def t_of(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def kick():
    t = t_of(0.35)
    freq = 45 + 110 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.12)


def clap():
    t = t_of(0.25)
    burst = sum(np.exp(-np.maximum(t - d, 0) / 0.01) * (t >= d) for d in (0, 0.01, 0.022))
    return (noise(0.25) - lowpass(noise(0.25), 900)) * (burst + np.exp(-t / 0.08)) * 0.5


def hat(length=0.06):
    n = noise(length)
    return (n - lowpass(n, 6000)) * np.exp(-t_of(length) / 0.015)


def saw(freq, seconds, voices=3, detune=0.008):
    t = t_of(seconds)
    out = np.zeros_like(t)
    for v in range(voices):
        f = freq * (1 + detune * (v - (voices - 1) / 2))
        phase = (f * t + rng.uniform()) % 1.0
        out += 2 * phase - 1
    return out / voices


def pump():
    """The sidechain duck: low just after each kick."""
    beat_phase = (np.arange(SIZE) / RATE / BEAT) % 1.0
    return 0.25 + 0.75 * np.minimum(1, beat_phase / 0.45) ** 1.5


def groove():
    drums = np.zeros(SIZE)
    music = np.zeros(SIZE)
    for beat in range(BARS * 4):
        put(drums, kick(), beat)
        if beat % 2 == 1:
            put(drums, clap(), beat)
        put(drums, hat(), beat + 0.5)
        put(drums, 0.4 * hat(0.03), beat + 0.75)
    for bar in range(BARS):
        chord = CHORDS[bar // 2 % 4]
        root = ROOTS[bar // 2 % 4]
        for eighth in range(8):
            if eighth in (0, 3, 4, 6, 7):
                note = root + (12 if eighth in (3, 7) else 0)
                length = BEAT * 0.45
                env = np.exp(-t_of(length) / 0.12)
                put(music, lowpass(saw(hz(note), length, 2), 600) * env * 1.4, bar * 4 + eighth / 2)
        pad = sum(saw(hz(n), 4 * BEAT, 3, 0.01) for n in chord)
        env = np.minimum(1, t_of(4 * BEAT) / 0.05)
        put(music, lowpass(pad, 1800) * env * 0.35, bar * 4)
    return drums + music * pump()


def rush():
    out = np.zeros(SIZE)
    for bar in range(BARS):
        chord = CHORDS[bar // 2 % 4]
        notes = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 24]
        for step in range(16):
            length = BEAT * 0.22
            env = np.exp(-t_of(length) / 0.05)
            tone = saw(hz(notes[step % 4]), length, 2, 0.004)
            put(out, lowpass(tone, 3500) * env * 0.5, bar * 4 + step / 4)
        if bar % 2 == 1:
            for step in range(8):  # A snare roll into the next chord.
                snare = (noise(0.1) - lowpass(noise(0.1), 1500)) * np.exp(-t_of(0.1) / 0.03)
                put(out, snare * (0.2 + 0.1 * step), bar * 4 + 2 + step / 4)
    return out


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio/versus"
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "versus_groove.wav"), groove(), 0.7)
    save(os.path.join(out, "versus_rush.wav"), rush(), 0.6)
