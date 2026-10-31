#!/usr/bin/env python3
"""Synthesizes the NonoGrid sound effects into assets/audio/*.wav.

Python 3 standard library only. Output is deterministic (fixed random seed),
so running it twice produces identical files.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
PEAK = 0.7  # about -3 dBFS


def envelope(n, attack=0.006, release=0.04):
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    env = []
    for i in range(n):
        g = 1.0
        if i < a:
            g = i / a
        if i > n - r:
            g = min(g, (n - i) / r)
        env.append(g)
    return env


def tone(freq, dur, kind="sine", glide=None, decay=6.0, attack=0.006):
    """A decaying tone; glide is an optional end frequency."""
    n = int(dur * RATE)
    env = envelope(n, attack)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if glide is None else freq + (glide - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        if kind == "triangle":
            s = 2 / math.pi * math.asin(math.sin(phase))
        else:
            s = math.sin(phase)
        out.append(s * env[i] * math.exp(-decay * t / dur))
    return out


def noise(dur, seed, lowpass=0.15, decay=3.0):
    rng = random.Random(seed)
    n = int(dur * RATE)
    env = envelope(n, 0.01, 0.06)
    out = []
    y = 0.0
    for i in range(n):
        y += lowpass * (rng.uniform(-1, 1) - y)
        out.append(y * env[i] * math.exp(-decay * i / n))
    return out


def mix(*parts):
    n = max(len(p[1]) + p[0] for p in parts)
    out = [0.0] * n
    for offset, samples, gain in parts:
        for i, s in enumerate(samples):
            out[offset + i] += s * gain
    return out


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = PEAK / peak
    path = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def ms(v):
    return int(v * RATE / 1000)


def main():
    # fill: soft pop with a tiny downward glide.
    write("fill", tone(440, 0.08, "triangle", glide=330, decay=4.5))
    # mark: lighter, higher tick.
    write("mark", tone(900, 0.05, "sine", glide=820, decay=5.0))
    # undo: short falling glide.
    write("undo", tone(600, 0.12, "triangle", glide=380, decay=4.0))
    # level_clear: rising major arpeggio.
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = [(ms(70 * i), tone(f, 0.15, "sine", decay=3.0), 1.0) for i, f in enumerate(notes)]
    write("level_clear", mix(*parts))


if __name__ == "__main__":
    main()
