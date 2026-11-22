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

# lines: a teacher screaming. A rasping, over-driven voice shouting a sharp "SIT DOWN!" on a rising-then-falling
# pitch, run through vowel formants, with breath noise, a shaky vibrato and hard clipping.
def formant(x, fc, bw):
    # two-pole resonator
    r = np.exp(-np.pi * bw / SR)
    th = 2 * np.pi * fc / SR
    a1, a2 = -2 * r * np.cos(th), r * r
    y = np.zeros(len(x))
    for i in range(2, len(x)):
        y[i] = x[i] - a1 * y[i - 1] - a2 * y[i - 2]
    return y


rng_l = np.random.default_rng(7)
dur = 1.25
tt = t(dur)
n = len(tt)
# pitch: a hard jump up, a shouted plateau with a ragged wobble, then a falling bark
f0 = np.interp(tt, [0, 0.05, 0.25, 0.75, 1.1, dur], [260, 520, 600, 560, 430, 300])
f0 *= 1 + 0.035 * np.sin(2 * np.pi * 9.5 * tt) + 0.02 * rng_l.normal(0, 1, n).cumsum() / np.sqrt(np.arange(1, n + 1))
phase = 2 * np.pi * np.cumsum(f0) / SR
src = np.zeros(n)
for k in range(1, 40):                       # bright, buzzy glottal source: many strong harmonics
    src += np.sin(k * phase) / (k ** 0.7)
src += rng_l.normal(0, 1, n) * 0.35          # rasp
# two syllables: SIT (short) ... DOWN! (long), with a gap
amp = np.interp(tt, [0, 0.03, 0.30, 0.34, 0.42, 0.46, 0.60, 1.0, dur], [0, 1, 0.9, 0.2, 0.15, 1.0, 1.0, 0.8, 0])
src *= amp
f1 = formant(src, 800, 140)                  # open, strained "aah"
f2 = formant(src, 1500, 220)
f3 = formant(src, 2700, 300)
voice = f1 + 0.9 * f2 + 0.7 * f3
voice += 0.4 * np.sin(2 * np.pi * np.cumsum(f0 * 2.01) / SR) * amp   # a screechy edge
voice = voice / (np.max(np.abs(voice)) + 1e-9)
voice = np.tanh(voice * 6.0)                 # shout it into distortion
voice = np.clip(voice * 1.3, -1, 1)
# a snap of consonant noise at the start of each syllable
for at in (0.0, 0.43):
    tn = t(0.07)
    place(voice, rng_l.normal(0, 1, len(tn)) * env(len(tn), 0.001, 55) * 0.9, at)
save('lines', voice, 0.98)

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
