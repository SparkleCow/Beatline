"""Compone pistas darkwave/EBM originales (síntesis pura, sin samples) y las guarda en WAV."""
import math, random, struct, sys, wave
from array import array
from operator import add, mul

SR = 44100
SCALE = [0, 2, 3, 5, 7, 8, 10]  # menor natural

def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12)
def deg(root, d): return root + SCALE[d % 7] + 12 * (d // 7)

def kick():
    n = int(0.32 * SR); out = array('f', bytes(4 * n)); ph = 0.0
    for i in range(n):
        t = i / SR
        ph += (45 + 140 * math.exp(-t * 38)) / SR
        out[i] = math.sin(ph * 2 * math.pi) * math.exp(-t * 9) * 1.0 + (0.5 * math.exp(-t * 400) if i < 200 else 0)
    return out

def snare(rng):
    n = int(0.2 * SR); out = array('f', bytes(4 * n)); prev = 0.0
    for i in range(n):
        t = i / SR
        w = rng.uniform(-1, 1); hp = w - prev; prev = w
        gate = 1.0 if t < 0.15 else max(0.0, 1 - (t - 0.15) / 0.02)   # reverb "gated" ochentero
        out[i] = (0.55 * hp * math.exp(-t * 9) + 0.5 * math.sin(2 * math.pi * 185 * t) * math.exp(-t * 28)) * gate
    return out

def hat(rng, length, decay):
    n = int(length * SR); out = array('f', bytes(4 * n)); p1 = p2 = 0.0
    for i in range(n):
        w = rng.uniform(-1, 1); hp = w - 2 * p1 + p2; p2 = p1; p1 = w
        out[i] = hp * 0.16 * math.exp(-(i / SR) * decay)
    return out

def saw(ph): return 2 * (ph % 1.0) - 1

def bass(midi, length):
    n = int(length * SR); out = array('f', bytes(4 * n)); f = hz(midi); y = 0.0
    for i in range(n):
        t = i / SR
        raw = 0.5 * saw(f * t) + 0.5 * saw(f * 1.008 * t + 0.3) + 0.6 * math.sin(2 * math.pi * f * 0.5 * t)
        cutoff = 260 + 2600 * math.exp(-t * 16)
        a = 1 - math.exp(-2 * math.pi * cutoff / SR)
        y += a * (raw - y)
        env = min(1.0, i / 60) * min(1.0, (n - i) / 300)
        out[i] = y * env * 0.5
    return out

def arp(midi, length):
    n = int(length * SR); out = array('f', bytes(4 * n)); f = hz(midi); y = 0.0
    for i in range(n):
        t = i / SR
        raw = 1.0 if (f * t) % 1.0 < 0.28 else -1.0
        y += 0.35 * (raw - y)
        out[i] = y * math.exp(-t * 11) * min(1.0, i / 40) * 0.17
    return out

def pad(midis, length):
    n = int(length * SR); out = array('f', bytes(4 * n)); y = 0.0
    fs = [hz(m) * d for m in midis for d in (0.996, 1.004)]
    for i in range(n):
        t = i / SR
        raw = sum(saw(f * t + k * 0.17) for k, f in enumerate(fs)) / len(fs)
        y += 0.06 * (raw - y)
        out[i] = y * min(1.0, t / 0.5) * min(1.0, (n - i) / (0.25 * SR)) * 0.42
    return out

def lead(midi, length):
    n = int(length * SR); out = array('f', bytes(4 * n)); f = hz(midi); ph = 0.0
    for i in range(n):
        t = i / SR
        ph += f * (1 + 0.006 * math.sin(2 * math.pi * 5.2 * t) * min(1.0, t * 3)) / SR
        tri = 2 * abs(2 * (ph % 1.0) - 1) - 1
        out[i] = (0.6 * math.sin(2 * math.pi * ph) + 0.4 * tri) * min(1.0, i / 400) * min(1.0, (n - i) / 1500) * 0.2
    return out

def put(buf, off, src, gain=1.0):
    n = min(len(src), len(buf) - off)
    if n <= 0: return
    s = src if n == len(src) else src[:n]
    if gain != 1.0: s = array('f', (v * gain for v in s))
    buf[off:off + n] = array('f', map(add, buf[off:off + n], s))

def compose(path, bpm, root, prog, bass_steps, lead_line, seed):
    rng = random.Random(seed)
    spb = SR * 60 / bpm; step = spb / 4; bars = 32
    total = round(bars * 4 * spb)
    L = array('f', bytes(4 * total)); R = array('f', bytes(4 * total)); duck = array('f', bytes(4 * total))
    at = lambda bar, st: round((bar * 16 + st) * step)
    K, S = kick(), snare(rng); H, OH = hat(rng, 0.05, 90), hat(rng, 0.16, 22)
    cache = {}
    def note(fn, midi, length):
        key = (fn.__name__, midi, round(length, 4))
        if key not in cache: cache[key] = fn(midi, length)
        return cache[key]
    step_s = 60 / bpm / 4
    for bar in range(bars):
        sec = bar // 8; d = prog[bar % len(prog)]
        chord = [deg(root, d), deg(root, d + 2), deg(root, d + 4)]
        brk = sec == 3 and bar % 8 < 4
        drums = not brk
        if drums:
            for b in range(4):
                put(L, at(bar, b * 4), K); put(R, at(bar, b * 4), K)
        if drums and sec >= 1:
            for b in (1, 3):
                put(L, at(bar, b * 4), S, 0.9); put(R, at(bar, b * 4), S, 0.9)
        if bar % 8 == 7 and sec >= 1:                       # redoble al cerrar la sección
            for st in (12, 13, 14, 15):
                put(L, at(bar, st), S, 0.5 + 0.1 * (st - 12)); put(R, at(bar, st), S, 0.5 + 0.1 * (st - 12))
        if drums:
            for st in range(16):
                if sec == 0 and st % 2: continue
                h = OH if st % 4 == 2 else H
                g = 1.0 if st % 4 == 2 else (0.75 if st % 2 == 0 else 0.45)
                put(L, at(bar, st), h, g * 0.8); put(R, at(bar, st), h, g)
        if not brk:
            for i, st in enumerate(bass_steps):
                nxt = bass_steps[i + 1] if i + 1 < len(bass_steps) else 16
                m = chord[0] - 12 + (12 if (st % 4 == 2 and rng.random() < 0.5) else 0)
                put(duck, at(bar, st), note(bass, m, (nxt - st) * step_s * 0.92))
        if sec >= 1:
            pd_key = ('pad', d)
            if pd_key not in cache: cache[pd_key] = pad([c + 12 for c in chord], 4 * 60 / bpm)
            put(duck, at(bar, 0), cache[pd_key], 1.0 if not brk else 1.3)
            seq = [chord[0], chord[1], chord[2], chord[1] + 12, chord[2], chord[0] + 12, chord[1], chord[2] + 12]
            for st in range(16):
                if rng.random() < 0.1: continue
                a = note(arp, seq[st % 8] + 24, 0.22)
                o = at(bar, st); e = round(3 * step)
                put(L, o, a, 0.9); put(R, o, a, 0.6)
                put(R, o + e, a, 0.45); put(L, o + 2 * e, a, 0.25)   # eco de corchea con puntillo
        if sec >= 2:
            for st, dg, ln in lead_line[bar % len(lead_line)]:
                a = note(lead, deg(root, dg) + 24, ln * step_s)
                put(L, at(bar, st), a); put(R, at(bar, st), a)
    # Bombeo tipo sidechain: bajo y pad se agachan con cada bombo.
    beat = round(spb)
    env = array('f', (0.25 + 0.75 * min(1.0, (i / beat) * 2.2) ** 1.5 for i in range(beat)))
    full = array('f', bytes(4 * total))
    for b in range(bars * 4):
        o = round(b * spb); n = min(beat, total - o)
        brk = (b // 4) // 8 == 3 and (b // 4) % 8 < 4
        full[o:o + n] = env[:n] if not brk else array('f', [0.9] * n)
    duck = array('f', map(mul, duck, full))
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        frames = bytearray(4 * total)
        for i in range(total):
            l = math.tanh((L[i] + duck[i]) * 1.5) * 0.9; r = math.tanh((R[i] + duck[i]) * 1.5) * 0.9
            struct.pack_into('<hh', frames, 4 * i, int(l * 32767), int(r * 32767))
        w.writeframes(bytes(frames))
    print(path, total / SR, 's')

EIGHTHS = [0, 2, 4, 6, 8, 10, 12, 14]
GALLOP = [0, 2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15]
SYNC = [0, 3, 4, 6, 8, 11, 12, 14, 15]
out = sys.argv[1]
compose(out + '/cold_circuit_126bpm.wav', 126, 45, [0, 5, 2, 6], EIGHTHS,
        [[(0, 4, 8), (8, 2, 8)], [(0, 5, 12), (12, 4, 4)], [(0, 2, 8), (8, 1, 8)], [(0, 4, 6), (6, 3, 2), (8, 1, 8)]], 1)
compose(out + '/glass_cathedral_132bpm.wav', 132, 38, [0, 3, 5, 4], SYNC,
        [[(0, 7, 6), (6, 4, 10)], [(0, 5, 8), (8, 3, 8)], [(0, 7, 4), (4, 5, 4), (8, 4, 8)], [(0, 6, 12), (12, 4, 4)]], 2)
compose(out + '/black_static_140bpm.wav', 140, 42, [0, 0, 5, 6], GALLOP,
        [[(0, 2, 4), (4, 4, 4), (8, 2, 8)], [(0, 4, 12), (12, 2, 4)], [(0, 5, 8), (8, 4, 8)], [(0, 6, 8), (8, 4, 4), (12, 1, 4)]], 3)
