#!/usr/bin/env python3
"""Synthesises all of Inkwell Academy's sound effects (original) as 16-bit WAVs."""
import os, wave
import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'audio')
os.makedirs(OUT, exist_ok=True)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, decay=6.0):
    x = np.arange(n) / SR
    e = np.exp(-x * decay)
    ai = int(a * SR)
    if ai > 0:
        e[:ai] *= np.linspace(0, 1, ai)
    return e


def bell(f, d, partials=((1, 1), (2.0, .5), (2.76, .35), (5.4, .15), (8.9, .06)), decay=3.0):
    tt = t(d)
    s = sum(a * np.sin(2 * np.pi * f * m * tt) * np.exp(-tt * decay * (1 + m * 0.35)) for m, a in partials)
    return s * env(len(tt), 0.002, 0)


def place(buf, snd, at):
    i = int(at * SR)
    end = min(len(buf), i + len(snd))
    buf[i:end] += snd[:end - i]


def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())


rng = np.random.default_rng(3)

# school hand-bell: two bells rung alternately
buf = np.zeros(int(SR * 2.4))
for i in range(10):
    place(buf, bell(1318 if i % 2 else 1567, 1.2, decay=4), i * 0.13)
save('bell', buf, 0.6)

# pea-shooter "fwip-pop"
tt = t(0.14)
f = np.linspace(1400, 300, len(tt))
s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.002, 25)
s += rng.normal(0, 1, len(tt)) * env(len(tt), 0.001, 80) * 0.4
save('fire', s, 0.55)

# bonk (teacher hit)
tt = t(0.35)
f = np.linspace(420, 140, len(tt))
s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.001, 10)
s += 0.5 * np.sin(2 * np.pi * np.cumsum(f * 2.4) / SR) * env(len(tt), 0.001, 22)
save('bonk', s, 0.7)

# crest lights up: sparkly arpeggio
buf = np.zeros(int(SR * 1.3))
for i, fr in enumerate([784, 988, 1175, 1568, 1976]):
    place(buf, bell(fr, 0.8, ((1, 1), (3, .2), (4.2, .1)), decay=5), i * 0.07)
save('crest', buf, 0.55)

# lines: a gentle "uh-oh" (two descending soft tones)
buf = np.zeros(int(SR * 0.7))
for i, fr in enumerate([440, 330]):
    tt = t(0.32)
    s = (np.sin(2 * np.pi * fr * tt) + 0.3 * np.sin(2 * np.pi * fr * 2 * tt) + 0.15 * np.sin(2 * np.pi * fr * 3 * tt))
    s *= env(len(tt), 0.01, 7) * (1 + 0.05 * np.sin(2 * np.pi * 6 * tt))
    place(buf, s, i * 0.2)
save('lines', buf, 0.55)

# punch / thud
tt = t(0.3)
f = np.linspace(160, 45, len(tt))
s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.001, 12)
noise = rng.normal(0, 1, len(tt))
noise = np.convolve(noise, np.ones(12) / 12, 'same')
s += noise * env(len(tt), 0.001, 30) * 0.8
save('punch', s, 0.8)

# the Founder's Bell: big tower bell, four strikes
buf = np.zeros(int(SR * 6))
for i in range(4):
    place(buf, bell(196 if i % 2 == 0 else 165, 3.5, ((0.5, .6), (1, 1), (1.19, .45), (1.5, .4), (2, .35), (2.52, .2), (3, .12)), decay=0.9), i * 1.1)
save('founders', buf, 0.75)

# expelled: sad descending notes
buf = np.zeros(int(SR * 2.2))
for i, fr in enumerate([392, 370, 349, 262]):
    tt = t(0.6 if i < 3 else 1.0)
    s = (np.sin(2 * np.pi * fr * tt) + 0.5 * np.sin(2 * np.pi * fr * 2 * tt) + 0.25 * np.sin(2 * np.pi * fr * 3 * tt))
    s *= env(len(tt), 0.02, 3) * (1 + 0.08 * np.sin(2 * np.pi * 5 * tt))
    place(buf, s, i * 0.42)
save('expel', buf, 0.6)

# cheer-ish: bright rising chord swell (half-holiday)
buf = np.zeros(int(SR * 1.6))
for i, fr in enumerate([523, 659, 784, 1047]):
    place(buf, bell(fr, 1.2, ((1, 1), (2, .3)), decay=2.5), i * 0.09)
save('win', buf, 0.6)

# whoosh for the knocked-down fall
tt = t(0.25)
n = rng.normal(0, 1, len(tt))
n = np.convolve(n, np.ones(30) / 30, 'same') * np.sin(np.linspace(0, np.pi, len(tt)))
save('whoosh', n, 0.4)

# UI click
tt = t(0.05)
save('click', np.sin(2 * np.pi * 1200 * tt) * env(len(tt), 0.001, 90), 0.4)
print('audio written')
