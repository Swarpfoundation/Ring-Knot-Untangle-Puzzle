#!/usr/bin/env python3
"""
Deterministic SFX generator for Ring Knot.
Uses only Python standard library: wave, math, struct, random.
Output WAV files are short, original, conservative loudness.
"""

from __future__ import annotations
import math
import os
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100
PEAK = 0.55  # conservative headroom to avoid clipping

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "shared" / "assets" / "sfx"
OUT.mkdir(parents=True, exist_ok=True)


def write_wav(path: Path, mono: list[float]) -> None:
    # Soft-clip and convert to int16 with no clipping.
    peak = max(1e-9, max(abs(x) for x in mono))
    scale = (PEAK / peak) if peak > PEAK else 1.0
    samples = [max(-1.0, min(1.0, x * scale)) for x in mono]
    int_samples = [int(s * 32760) for s in samples]
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b"".join(struct.pack("<h", v) for v in int_samples))


def envelope(n: int, attack: float, decay: float) -> list[float]:
    out = [0.0] * n
    atk = max(1, int(attack * n))
    for i in range(atk):
        out[i] = i / atk
    rem = n - atk
    if rem <= 0:
        return out
    dec = max(1, int(decay * rem))
    for i in range(rem):
        if i < dec:
            t = i / dec
            out[atk + i] = 1.0 - t
        else:
            out[atk + i] = 0.0
    return out


def adsr(n: int, a: float, d: float, s: float, r: float, sustain_level: float = 0.5) -> list[float]:
    out = [0.0] * n
    a_n = max(1, int(a * n))
    d_n = max(1, int(d * n))
    r_n = max(1, int(r * n))
    s_n = max(1, n - a_n - d_n - r_n)
    idx = 0
    for i in range(a_n):
        out[idx] = i / a_n
        idx += 1
    for i in range(d_n):
        t = i / d_n
        out[idx] = 1.0 + (sustain_level - 1.0) * t
        idx += 1
    for _ in range(s_n):
        out[idx] = sustain_level
        idx += 1
    for i in range(r_n):
        t = i / r_n
        out[idx] = sustain_level * (1.0 - t)
        idx += 1
    return out


def sine(freq: float, n: int, phase: float = 0.0) -> list[float]:
    w = 2.0 * math.pi * freq / SAMPLE_RATE
    return [math.sin(w * i + phase) for i in range(n)]


def triangle(freq: float, n: int) -> list[float]:
    period = SAMPLE_RATE / freq
    out = [0.0] * n
    for i in range(n):
        p = (i % period) / period
        out[i] = 4.0 * abs(p - 0.5) - 1.0
    return out


def noise(n: int, seed: int) -> list[float]:
    r = random.Random(seed)
    return [r.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(x: list[float], cutoff: float) -> list[float]:
    # First-order RC low-pass
    rc = 1.0 / (2.0 * math.pi * cutoff)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    y = [0.0] * len(x)
    if not x:
        return y
    y[0] = x[0] * alpha
    for i in range(1, len(x)):
        y[i] = y[i - 1] + alpha * (x[i] - y[i - 1])
    return y


def highpass(x: list[float], cutoff: float) -> list[float]:
    rc = 1.0 / (2.0 * math.pi * cutoff)
    dt = 1.0 / SAMPLE_RATE
    alpha = rc / (rc + dt)
    y = [0.0] * len(x)
    if not x:
        return y
    y[0] = x[0]
    for i in range(1, len(x)):
        y[i] = alpha * (y[i - 1] + x[i] - x[i - 1])
    return y


def mix(*sources: list[float]) -> list[float]:
    n = max(len(s) for s in sources)
    out = [0.0] * n
    for s in sources:
        for i, v in enumerate(s):
            out[i] += v
    return out


def length_samples(seconds: float) -> int:
    return int(seconds * SAMPLE_RATE)


# --- Individual effects ---

def fx_ring_select() -> list[float]:
    n = length_samples(0.10)
    base = sine(880.0, n)
    chime = sine(1320.0, n)
    env = envelope(n, attack=0.02, decay=0.98)
    base = [v * 0.8 for v in base]
    chime = [v * 0.4 for v in chime]
    mixed = [(b + c) * e for b, c, e in zip(base, chime, env)]
    return mixed


def fx_button_tap() -> list[float]:
    n = length_samples(0.08)
    click = sine(620.0, n)
    env = envelope(n, attack=0.01, decay=0.99)
    return [v * e * 0.7 for v, e in zip(click, env)]


def fx_ring_drag_soft() -> list[float]:
    n = length_samples(0.30)
    rng_noise = noise(n, seed=20260529)
    filtered = lowpass(rng_noise, 1800.0)
    # Pitch sweep sine
    out = [0.0] * n
    for i in range(n):
        t = i / n
        f = 220.0 + 180.0 * t
        out[i] = 0.35 * math.sin(2 * math.pi * f * i / SAMPLE_RATE)
    env = adsr(n, a=0.1, d=0.2, s=0.5, r=0.4, sustain_level=0.45)
    return [(o + n2 * 0.25) * e for o, n2, e in zip(out, filtered, env)]


def fx_ring_invalid() -> list[float]:
    n = length_samples(0.25)
    a = sine(180.0, n)
    b = sine(140.0, n)
    rng_n = lowpass(noise(n, seed=4242), 900.0)
    env = envelope(n, attack=0.02, decay=0.98)
    mixed = [(0.55 * x + 0.35 * y + 0.25 * z) * e for x, y, z, e in zip(a, b, rng_n, env)]
    return mixed


def fx_ring_release() -> list[float]:
    n = length_samples(0.45)
    # Bright bell + tail noise
    a = sine(660.0, n)
    b = sine(990.0, n)
    c = sine(1320.0, n)
    rng_n = highpass(noise(n, seed=777), 1200.0)
    env_tone = adsr(n, a=0.03, d=0.18, s=0.4, r=0.55, sustain_level=0.35)
    env_shimmer = envelope(n, attack=0.01, decay=0.99)
    tone = [(0.5 * x + 0.35 * y + 0.25 * z) * e for x, y, z, e in zip(a, b, c, env_tone)]
    shimmer = [v * e * 0.18 for v, e in zip(rng_n, env_shimmer)]
    return [t + s for t, s in zip(tone, shimmer)]


def fx_hint() -> list[float]:
    n = length_samples(0.25)
    a = sine(740.0, n)
    b = sine(1110.0, n)
    env = envelope(n, attack=0.05, decay=0.95)
    return [(0.55 * x + 0.40 * y) * e for x, y, e in zip(a, b, env)]


def fx_level_complete() -> list[float]:
    n = length_samples(1.20)
    # Two upward sine arpeggios
    out = [0.0] * n
    notes = [523.25, 659.25, 783.99, 987.77]  # C5 E5 G5 B5
    per_note = n // len(notes)
    for idx, freq in enumerate(notes):
        start = idx * per_note
        for i in range(per_note):
            t = i / per_note
            env = math.sin(math.pi * t) ** 0.8
            out[start + i] += 0.45 * math.sin(2 * math.pi * freq * i / SAMPLE_RATE) * env
            out[start + i] += 0.25 * math.sin(2 * math.pi * (freq * 2) * i / SAMPLE_RATE) * env
    # Shimmer tail
    tail_start = int(0.7 * n)
    tail_n = n - tail_start
    shimmer = lowpass(noise(tail_n, seed=20260530), 6000.0)
    for i in range(tail_n):
        t = i / max(1, tail_n)
        out[tail_start + i] += 0.20 * shimmer[i] * (1.0 - t)
    return out


# --- Driver ---

EFFECTS = {
    "sfx_ring_select.wav": fx_ring_select,
    "sfx_button_tap.wav": fx_button_tap,
    "sfx_ring_drag_soft.wav": fx_ring_drag_soft,
    "sfx_ring_invalid.wav": fx_ring_invalid,
    "sfx_ring_release.wav": fx_ring_release,
    "sfx_hint.wav": fx_hint,
    "sfx_level_complete.wav": fx_level_complete,
}


def main() -> None:
    print(f"Generating SFX in {OUT}")
    for name, fn in EFFECTS.items():
        out_path = OUT / name
        write_wav(out_path, fn())
        size = out_path.stat().st_size
        print(f"  wrote {name}  ({size} bytes)")
    print("Done.")


if __name__ == "__main__":
    main()
