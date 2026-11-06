"""Dựng moc_gio.lrc (mốc từng chữ) từ video Suno.

Suno cuộn lời từng dòng hiển thị một; mỗi lần cuộn = lúc dòng đó bắt đầu được hát
(dòng ở vị trí thứ 3 từ trên). Script dò các lần cuộn trong video, ghép với danh sách
dòng hiển thị (suno_rows.txt, đọc từ video), rồi nội suy thời điểm từng chữ.
Chạy: python3 build_lrc.py suno_goc.mp4
"""
import re, subprocess, sys, unicodedata
import numpy as np

video = sys.argv[1]
HERE = __file__.rsplit("/", 1)[0]
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-vf", "crop=824:280:0:790,scale=412:140,format=gray",
                      "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
fr = np.frombuffer(raw, np.uint8).reshape(-1, 140, 412).astype(np.float32)
fps = 10
dd = np.abs(np.diff(fr, axis=0)).mean((1, 2))
ev = [i + 1 for i in range(len(dd)) if dd[i] > 3 * np.median(dd) + .5]
groups = []
for i in ev:
    if groups and i - groups[-1][-1] <= 2: groups[-1].append(i)
    else: groups.append([i])
# count -> thời điểm (nhóm 2 lần cuộn liền nhau tính 2 bước)
count_t, c = {}, 0
for g in groups:
    for _ in range(len(g)):
        c += 1; count_t[c] = g[0] / fps
rows = [l.rstrip("\n") for l in open(f"{HERE}/suno_rows.txt", encoding="utf-8")]
FIRST_ROW_T = 22.8   # dòng 1 hát trước khi video bắt đầu cuộn (đo theo độ sáng)
def row_t(r):
    return FIRST_ROW_T if r - 1 <= 0 else count_t[min(r - 1, c)]

# gom dòng hiển thị thành câu theo lời gốc
lyr = [l.strip() for l in open(f"{HERE}/LOI_BAI_HAT.txt", encoding="utf-8")
       if l.strip() and not l.startswith("[")][1:]
def key(s): return re.sub(r"[^\w]", "", unicodedata.normalize("NFC", s.lower()))
r = 1; out = []
for li, line in enumerate(lyr):
    target = key(line); acc = ""; seg = []
    while len(acc) < len(target) and r < len(rows):
        t = re.sub(r"^\[[^\]]+\]\s*", "", rows[r])
        if t != "_": seg.append((r, key(t))); acc += key(t)
        r += 1
    while r < len(rows) and rows[r] == "_": r += 1
    if acc != target: print("lệch:", line, "|", acc, file=sys.stderr)
    # mốc theo ký tự: dòng hiển thị k chạy từ row_t(k) tới row_t(k+1)
    knots, pos = [], 0
    for rr, txt in seg:
        knots.append((pos, row_t(rr))); pos += len(txt)
    nxt = row_t(r) if r < len(rows) else knots[-1][1] + 6
    last_len = len(seg[-1][1])
    end = min(nxt, knots[-1][1] + .9 + .11 * last_len)
    knots.append((pos, end))
    xs, ts = zip(*knots)
    words, p, stamps = line.split(), 0, []
    for w in words:
        stamps.append(float(np.interp(p, xs, ts))); p += len(key(w))
    out.append((stamps, words, end))
def f(t): return f"{int(t // 60):02d}:{t % 60:05.2f}"
with open(f"{HERE}/moc_gio.lrc", "w", encoding="utf-8") as fo:
    fo.write("[ti:Cười Với Đời Hết Hơi]\n[ar:balo260287]\n")
    for st, ws, end in out:
        fo.write(f"[{f(st[0])}]" + " ".join(f"<{f(t)}>{w}" for t, w in zip(st, ws)) + f" <{f(end)}>\n")
print("ghi", len(out), "câu")
