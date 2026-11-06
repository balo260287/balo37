"""Canh lại mốc từng chữ theo giọng hát đã tách (Vocals stem).

Tiếng Việt: mỗi chữ = một âm tiết = một lần bật giọng (onset). Lấy các onset trong
giọng hát, rồi dùng quy hoạch động gán lần lượt từng chữ vào một onset, bám gần mốc
cũ (moc_gio.lrc, đo từ video Suno) và ưu tiên đầu câu rơi sau một khoảng lặng.
Chạy: python3 align_vocals.py vocals.wav  ->  moc_gio_khop.lrc
"""
import re, sys
import numpy as np, librosa

vocal = sys.argv[1]
HERE = __file__.rsplit("/", 1)[0] or "."
y, sr = librosa.load(vocal, sr=16000, mono=True)
hop = 160  # 10 ms
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
rms = librosa.feature.rms(y=y, hop_length=hop, frame_length=640)[0]
db = 20 * np.log10(rms + 1e-6)
voiced_thr = np.percentile(db, 95) - 18
pk = librosa.util.peak_pick(env, pre_max=4, post_max=4, pre_avg=10, post_avg=10, delta=env.std() * .15, wait=7)
pk = [p for p in pk if db[min(p + 5, len(db) - 1)] > voiced_thr]
ct = np.array(pk) / 100.0
strength = env[pk] / np.percentile(env[pk], 90)
# độ "lặng" trước onset: dB trung bình 0.4s trước so với ngưỡng
quiet = np.array([max(0, voiced_thr - db[max(p - 40, 0):max(p - 5, 1)].mean()) for p in pk]) / 10

lines = []
for l in open(f"{HERE}/moc_gio.lrc", encoding="utf-8"):
    w = re.findall(r"<(\d+):(\d+\.\d+)>([^<]*)", l)
    if w:
        toks = [(int(a) * 60 + float(b), x.strip()) for a, b, x in w]
        lines.append(([t for t, x in toks if x], [x for t, x in toks if x], toks[-1][0]))
words = [(li, wi, t, x) for li, (ts, xs, _) in enumerate(lines) for wi, (t, x) in enumerate(zip(ts, xs))]
N, M = len(words), len(ct)
INF = 1e18
SIG = 2.0
cost = np.full((N, M), INF); back = np.zeros((N, M), int)
def local(i, j):
    li, wi, p, _ = words[i]
    c = ((ct[j] - p) / SIG) ** 2 - .6 * min(strength[j], 1.5)
    c += -2.5 * min(quiet[j], 2) if wi == 0 else 2.0 * min(quiet[j], 2)
    return c
for j in range(M):
    if abs(ct[j] - words[0][2]) < 4: cost[0, j] = local(0, j)
for i in range(1, N):
    prev = cost[i - 1]
    best = np.minimum.accumulate(prev); arg = np.zeros(M, int); a = 0
    for j in range(M):
        if prev[j] <= prev[a]: a = j
        arg[j] = a
    p = words[i][2]
    lo, hi = np.searchsorted(ct, p - 4.5), np.searchsorted(ct, p + 4.5)
    for j in range(max(lo, 1), hi):
        b = best[j - 1]
        if b >= INF: continue
        gap = ct[j] - ct[arg[j - 1]]
        cost[i, j] = b + local(i, j) + (3 if gap < .09 else 0)
        back[i, j] = arg[j - 1]
j = int(np.argmin(cost[-1])); assign = [0] * N
for i in range(N - 1, -1, -1):
    assign[i] = j; j = back[i, j]
newt = [ct[j] for j in assign]
shift = np.array(newt) - np.array([w[2] for w in words])
print(f"lệch so với mốc cũ: trung vị {np.median(shift):+.2f}s, |lệch| TB {np.abs(shift).mean():.2f}s", file=sys.stderr)

def f(t): return f"{int(t // 60):02d}:{t % 60:05.2f}"
out, k = [], 0
for li, (ts, xs, end) in enumerate(lines):
    st = list(newt[k:k + len(xs)]); k += len(xs)
    if len(st) > 1 and st[1] - st[0] > .6: st[0] = st[1] - .2   # chữ đầu bị kéo về tiếng nhiễu sớm
    # chữ cuối kéo tới khi giọng tắt (tối đa 2.5s, không quá câu sau)
    lp = int(st[-1] * 100); e = lp + 20
    while e < len(db) - 1 and db[e] > voiced_thr and e - lp < 250: e += 1
    end = e / 100
    if k < N: end = min(end, newt[k] - .05)
    out.append(f"[{f(st[0])}]" + " ".join(f"<{f(t)}>{x}" for t, x in zip(st, xs)) + f" <{f(max(end, st[-1] + .2))}>")
open(f"{HERE}/moc_gio_khop.lrc", "w", encoding="utf-8").write("[ti:Cười Với Đời Hết Hơi]\n" + "\n".join(out) + "\n")
print("ghi moc_gio_khop.lrc:", len(out), "câu,", N, "chữ,", M, "onset", file=sys.stderr)
