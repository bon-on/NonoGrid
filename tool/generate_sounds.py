#!/usr/bin/env python3
"""Synthesizes the NonoGrid sound effects and music loop into assets/audio/*.wav.

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


def write(name, samples, rate=RATE, peak_level=PEAK):
    peak = max(abs(s) for s in samples) or 1.0
    scale = peak_level / peak
    path = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def bell(freq, dur, rate=RATE, decay=3.0, bright=1.0):
    """Music-box style bell: a few partials, the high ones fade faster."""
    n = int(dur * rate)
    partials = ((1.0, 1.0, 1.0), (2.0, 0.32 * bright, 2.2), (3.01, 0.14 * bright, 3.5), (4.17, 0.07 * bright, 5.0))
    out = [0.0] * n
    attack = max(1, int(0.003 * rate))
    for ratio, amp, dk in partials:
        f = freq * ratio
        if f > rate / 2.2:
            continue
        w = 2 * math.pi * f / rate
        for i in range(n):
            t = i / rate
            g = min(1.0, i / attack)
            out[i] += math.sin(w * i) * amp * g * math.exp(-decay * dk * t)
    release = max(1, int(0.02 * rate))
    for i in range(max(0, n - release), n):
        out[i] *= (n - i) / release
    return out


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


MUSIC_RATE = 16000


def music_loop():
    """Gentle music-box / lo-fi loop: 8 bars at 76 bpm in C, seamless."""
    rate = MUSIC_RATE
    beat = 60.0 / 76
    bar = beat * 4
    total = int(round(bar * 8 * rate))
    buf = [0.0] * total
    rng = random.Random(1976)

    def add(start, samples, gain):
        for i, v in enumerate(samples):
            buf[(start + i) % total] += v * gain

    chords = [
        ([48, 52, 55, 59], 36),
        ([45, 48, 52, 55], 33),
        ([41, 45, 48, 52], 29),
        ([43, 47, 50, 52], 31),
    ]
    melody = [
        [76, 79, 83, 79, 84, 83, 79, 76],
        [76, 72, 69, 72, 76, 79, 76, 72],
        [77, 76, 72, 69, 72, 76, 77, 81],
        [79, 74, 71, 74, 76, 79, 83, -1],
        [84, 83, 79, 76, 79, 83, 84, 88],
        [81, 79, 76, 72, 76, 79, 81, 84],
        [81, 77, 76, 72, 69, 72, 76, 77],
        [79, 76, 74, 71, 74, 79, -1, -1],
    ]
    for b in range(8):
        bar_start = int(b * bar * rate)
        notes, root = chords[b % 4]
        # Soft pad: low-passed triangle chord with a slow swell.
        n = int(bar * rate)
        pad = [0.0] * n
        for k, note in enumerate(notes):
            f = midi(note) * (1 + 0.0015 * (k - 1.5))
            ph = 0.0
            y = 0.0
            for i in range(n):
                ph += 2 * math.pi * f / rate
                tri = 2 / math.pi * math.asin(math.sin(ph))
                y += 0.08 * (tri - y)
                pad[i] += y
        swell = int(0.45 * rate)
        for i in range(n):
            g = min(1.0, i / swell) * min(1.0, (n - i) / swell)
            pad[i] *= g
        add(bar_start, pad, 0.10)
        # Bass on beats 1 and 3.
        for beat_i in (0, 2):
            add(bar_start + int(beat_i * beat * rate), bell(midi(root), beat * 1.6, rate, decay=1.6, bright=0.2), 0.22)
        # Music box melody, eighth notes, a little humanized.
        for step, note in enumerate(melody[b]):
            if note < 0:
                continue
            start = bar_start + int(step * beat / 2 * rate) + rng.randint(-40, 40)
            vel = 0.85 if step % 2 == 0 else 0.6
            vel *= 0.9 + rng.random() * 0.2
            add(start, bell(midi(note), 1.4, rate, decay=2.2), 0.30 * vel)
        # Lo-fi kit: soft thump on 1 and 3, brushed hat on the off-beats.
        for beat_i in range(4):
            t0 = bar_start + int(beat_i * beat * rate)
            if beat_i in (0, 2):
                kick = []
                for i in range(int(0.16 * rate)):
                    t = i / rate
                    f = 55 + 70 * math.exp(-t * 30)
                    kick.append(math.sin(2 * math.pi * f * t) * math.exp(-t * 22))
                add(t0, kick, 0.20)
            hat_start = t0 + int(beat / 2 * rate)
            hat = []
            y = 0.0
            prev = 0.0
            for i in range(int(0.06 * rate)):
                x = rng.uniform(-1, 1)
                y = x - prev
                prev = x
                hat.append(y * math.exp(-i / rate * 60))
            add(hat_start, hat, 0.025)
    # Vinyl crackle: sparse clicks and a faint hiss.
    y = 0.0
    for i in range(total):
        y += 0.05 * (rng.uniform(-1, 1) - y)
        buf[i] += y * 0.02
        if rng.random() < 0.0009:
            buf[i] += rng.uniform(-0.12, 0.12)
    return buf


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
    # line_done: a two-note music-box chime.
    write("line_done", mix((0, bell(1318.5, 0.45, decay=4.0), 1.0), (ms(55), bell(1975.5, 0.4, decay=4.5), 0.7)))
    # mistake: a soft wooden "bonk" with a little low buzz.
    write("mistake", mix((0, tone(196, 0.2, "triangle", glide=130, decay=5.0), 1.0), (0, noise(0.08, 3, 0.3, 6.0), 0.35)))
    # star: a bright upward sparkle.
    write("star", mix((0, bell(1568.0, 0.35, decay=4.0), 1.0), (ms(40), bell(2093.0, 0.35, decay=4.5), 0.8), (ms(80), bell(2637.0, 0.3, decay=5.0), 0.5)))
    # level_up: music-box arpeggio up to a held chord.
    up = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    parts = [(ms(80 * i), bell(f, 0.9, decay=2.2), 0.9) for i, f in enumerate(up)]
    parts += [(ms(420), bell(f, 1.0, decay=1.6), 0.45) for f in (523.25, 659.25, 783.99)]
    write("level_up", mix(*parts))
    # music_loop: background loop (16 kHz mono keeps it under 1 MB).
    write("music_loop", music_loop(), rate=MUSIC_RATE, peak_level=0.6)


if __name__ == "__main__":
    main()
