"""Tạo beat sinh nhật (giai điệu gốc, 120 BPM, Đô trưởng) cho bài "Sinh nhật anh Ủn 9 tuổi".
Chạy: python3 make_beat.py  ->  sinh_nhat_anh_Un.wav
"""
import numpy as np, wave

SR = 44100
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
rng = np.random.default_rng(9)

def mtof(m): return 440 * 2 ** ((m - 69) / 12)

SECTIONS = [("intro", 4), ("v1", 8), ("v2", 8), ("v3", 8), ("chorus", 8), ("chorus", 8), ("outro", 4)]
TOTAL = sum(b for _, b in SECTIONS) * BAR + 3
L = np.zeros(int(TOTAL * SR)); R = np.zeros_like(L)

def add(sig, t, pan=0.0, gain=1.0):
    i = int(t * SR); n = min(len(sig), len(L) - i)
    if n <= 0: return
    L[i:i+n] += sig[:n] * gain * (1 - pan) / 2 * 2 ** .5
    R[i:i+n] += sig[:n] * gain * (1 + pan) / 2 * 2 ** .5

def env(n, a=0.005, d=0.3):
    t = np.arange(n) / SR
    return np.minimum(t / a, 1) * np.exp(-t / d)

def lowpass(x, k=8):
    return np.convolve(x, np.ones(k) / k, mode="same")

# ---- nhạc cụ ----
def kick():
    n = int(.35 * SR); t = np.arange(n) / SR
    f = 45 + 90 * np.exp(-t / .04)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / .18)

def snare():
    n = int(.22 * SR); t = np.arange(n) / SR
    nz = rng.standard_normal(n); nz = nz - lowpass(nz, 6)
    return (.6 * nz * np.exp(-t / .07) + .5 * np.sin(2*np.pi*190*t) * np.exp(-t / .05))

def clap():
    n = int(.2 * SR); t = np.arange(n) / SR
    nz = rng.standard_normal(n); nz = nz - lowpass(nz, 4)
    e = sum(np.exp(-np.clip(t - d, 0, None) / .012) * (t >= d) for d in (0, .01, .02)) + np.exp(-t/.08)*.5
    return nz * e * .5

def hat(open_=False):
    n = int((.25 if open_ else .05) * SR); t = np.arange(n) / SR
    nz = rng.standard_normal(n); nz = nz - lowpass(nz, 3)
    return nz * np.exp(-t / (.08 if open_ else .015)) * .5

def crash():
    n = int(1.6 * SR); t = np.arange(n) / SR
    nz = rng.standard_normal(n); nz = nz - lowpass(nz, 3)
    return nz * np.exp(-t / .5) * .35

def bass(m, dur):
    n = int(dur * SR); t = np.arange(n) / SR; f = mtof(m)
    s = sum(np.sin(2*np.pi*f*k*t) / k for k in range(1, 6))
    return lowpass(s, 10) * env(n, .005, dur * .8) * .5

def stab(notes, dur=.22):
    n = int(dur * SR); t = np.arange(n) / SR
    s = sum(np.sin(2*np.pi*mtof(m)*t) + .3*np.sin(2*np.pi*2*mtof(m)*t) + .15*np.sin(2*np.pi*3*mtof(m)*t) for m in notes)
    return s * env(n, .003, .09) / len(notes)

def pad(notes, dur):
    n = int(dur * SR); t = np.arange(n) / SR
    s = sum(np.sin(2*np.pi*mtof(m)*t*(1+d)) for m in notes for d in (-.002, .002))
    a = np.minimum(t / .3, 1) * np.minimum((dur - t) / .3, 1)
    return s * a / (2 * len(notes))

def bell(m, dur):
    n = int((dur + .4) * SR); t = np.arange(n) / SR; f = mtof(m)
    vib = 1 + .004 * np.sin(2*np.pi*5.5*t) * np.minimum(t / .3, 1)
    ph = 2*np.pi*f*np.cumsum(vib)/SR
    s = np.sin(ph) + .35*np.sin(2*ph) + .12*np.sin(3*ph) + .2*np.sin(4.01*ph)*np.exp(-t/.05)
    e = np.minimum(t/.01, 1) * np.where(t < dur, np.exp(-t/1.2), np.exp(-dur/1.2)*np.exp(-(t-dur)/.08))
    return s * e * .35

# ---- hòa âm & giai điệu (gốc) ----
CH = {"C": [60, 64, 67], "Am": [57, 60, 64], "F": [53, 57, 60], "G": [55, 59, 62], "Em": [52, 55, 59]}
VERSE_CH = ["C", "Am", "F", "G"]          # mỗi câu hát = 2 nhịp (bar)
CHORUS_CH = ["F", "G", "Am", ("G", "C")]
VERSE_MEL = [
    [(0,.5,64),(.5,.5,64),(1,1,67),(2,1,69),(3,3,67)],                       # Hôm nay là ngày vui
    [(0,.5,72),(.5,.5,71),(1,1,69),(2,1,67),(3,3,64)],                       # Anh Ủn lớn thêm rồi
    [(0,.5,65),(.5,.5,65),(1,.5,69),(1.5,.5,72),(2,1,74),(3,1,72),(4,2,69)], # Chín cây nến lung linh sáng
    [(0,.5,67),(.5,.5,69),(1,1,71),(2,1,74),(3,3,71)],                       # Rạng rỡ nụ cười tươi
]
CHORUS_MEL = [
    [(0,.5,72),(.5,.5,72),(1,1,77),(2,1,76),(3,3,72)],                       # Chúc mừng anh Ủn ơi
    [(0,.5,71),(.5,.5,71),(1,1,74),(2,1,72),(3,3,71)],                       # Chín tuổi thật tuyệt vời
    [(0,.5,69),(.5,.5,71),(1,.5,72),(1.5,.5,74),(2,1,76),(3,1,74),(4,2,72)], # Học giỏi, ngoan, luôn vui vẻ
    [(0,.5,71),(.5,.5,72),(1,1,74),(2,1,71),(4,4,72)],                       # Hạnh phúc mãi không vơi
]

def drums_bar(t0, chorus=False, fill=False):
    for b in range(4):
        tb = t0 + b * BEAT
        add(kick(), tb, gain=.9) if b in (0, 2) else None
        if b in (1, 3):
            add(snare(), tb, gain=.55)
            if chorus: add(clap(), tb, .1, .6)
        add(hat(), tb, .3, .35); add(hat(b == 3 and chorus), tb + BEAT/2, .3, .45)
    add(kick(), t0 + 2.5 * BEAT, gain=.6)
    if fill:
        for k in range(4): add(snare(), t0 + 3*BEAT + k*BEAT/4, gain=.25 + .1*k)

def harmony_bar(t0, chord, chorus=False):
    notes = CH[chord]; root = notes[0] - 24 if notes[0] >= 57 else notes[0] - 12
    for e in range(8):
        add(bass(root + (12 if e % 4 == 3 else 0), BEAT/2*.9), t0 + e*BEAT/2, gain=.8)
    for b in range(4):
        add(stab([n + 12 for n in notes]), t0 + b*BEAT + BEAT/2, -.35, .55 if chorus else .45)
    add(pad([n + 12 for n in notes], BAR), t0, .35, .18 if chorus else .12)

t = 0.0
for name, bars in SECTIONS:
    if name != "intro": add(crash(), t, .4, .8)
    if name == "intro":
        for i, c in enumerate(VERSE_CH):
            harmony_bar(t + i*BAR, c)
            for k, m in enumerate([0, 1, 2, 1, 0, 1, 2, 1]):  # chuông arpeggio
                add(bell(CH[c][m] + 24, BEAT/2), t + i*BAR + k*BEAT/2, .2, .45)
            if i >= 2: drums_bar(t + i*BAR, fill=(i == 3))
    elif name in ("v1", "v2", "v3", "chorus"):
        chorus = name == "chorus"
        chords = CHORUS_CH if chorus else VERSE_CH
        mel = CHORUS_MEL if chorus else VERSE_MEL
        for line in range(4):
            tl = t + line * 2 * BAR
            c = chords[line]
            c1, c2 = (c if isinstance(c, tuple) else (c, c))
            harmony_bar(tl, c1, chorus); harmony_bar(tl + BAR, c2, chorus)
            drums_bar(tl, chorus); drums_bar(tl + BAR, chorus, fill=(line == 3))
            for st, du, m in mel[line]:
                add(bell(m, du * BEAT), tl + st * BEAT, -.1, .9)
                if chorus: add(bell(m - 12, du * BEAT), tl + st * BEAT, .1, .4)
    elif name == "outro":
        # "Một, hai, ba..." : trống dồn, rồi hợp âm Đô bùng nổ
        for k in range(8): add(kick(), t + k*BEAT/2, gain=.5 + .05*k)
        for k in range(16): add(snare(), t + BAR + k*BEAT/4, gain=.2 + .03*k)
        add(crash(), t + 2*BAR, 0, 1.0); add(kick(), t + 2*BAR, gain=1)
        add(pad([60, 64, 67, 72, 76], 2*BAR + 2), t + 2*BAR, 0, .35)
        add(bass(36, 2*BAR), t + 2*BAR, gain=.9)
        for k, m in enumerate([72, 76, 79, 84]): add(bell(m, 1.5), t + 2*BAR + k*.12, 0, .6)
    t += bars * BAR

mix = np.stack([L, R], 1)
mix = np.tanh(mix / np.max(np.abs(mix)) * 1.6) * .89
fade = int(.02 * SR); mix[-fade:] *= np.linspace(1, 0, fade)[:, None]
with wave.open("sinh_nhat_anh_Un.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())
print("ok", round(len(mix) / SR, 1), "s")
