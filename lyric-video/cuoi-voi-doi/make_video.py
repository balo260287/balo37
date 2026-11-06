"""Lyric video 16:9 cho "Cười Với Đời Hết Hơi" — phong cách trầm, ấm, điện ảnh.

Mốc giờ đọc từ file .lrc (kể cả LRC có mốc từng chữ <mm:ss.xx>) hoặc .srt.
Nếu mốc chỉ có theo câu, chữ được tô màu dần đều trong thời lượng câu đó.
Nhãn phần (Verse, Chorus…) lấy từ LOI_BAI_HAT.txt bằng cách dò theo thứ tự câu.

Chạy:  python3 make_video.py --timing moc_gio.lrc --duration 30 -o ban_nhap_30s.mp4
       python3 make_video.py --timing moc_gio.lrc -o cuoi_voi_doi_lyric.mp4
"""
import argparse, colorsys, difflib, os, re, subprocess, sys, unicodedata
import numpy as np
import librosa
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "fonts")
W, H, FPS = 1920, 1080, 30
TITLE = "Cười Với Đời Hết Hơi"
SECTION_VI = {"verse 1": "Đoạn 1", "verse 2": "Đoạn 2", "verse 3": "Đoạn 3", "pre-chorus": "Tiền điệp khúc",
              "chorus": "Điệp khúc", "bridge": "Bridge", "final chorus": "Điệp khúc cuối", "outro": "Kết"}


# ---------------------------------------------------------------- đọc mốc giờ
def _ts(s):
    s = s.strip().replace(",", ".")
    parts = [float(p) for p in s.split(":")]
    return sum(p * 60 ** (len(parts) - 1 - i) for i, p in enumerate(parts))


def read_timing(path):
    """-> list of dict(start, end|None, text, words=[(w, s, e)] | None)"""
    txt = open(path, encoding="utf-8-sig").read()
    out = []
    if path.lower().endswith(".srt"):
        for blk in re.split(r"\n\s*\n", txt.strip()):
            ls = blk.strip().splitlines()
            m = next((re.match(r"(\S+)\s*-->\s*(\S+)", l) for l in ls if "-->" in l), None)
            if not m: continue
            body = " ".join(l for l in ls[ls.index(m.string) + 1:] if l.strip())
            out.append(dict(start=_ts(m[1]), end=_ts(m[2]), text=re.sub(r"<[^>]+>", "", body).strip(), words=None))
    else:
        for line in txt.splitlines():
            tags = re.findall(r"\[(\d+:\d+(?:[.:]\d+)?)\]", line)
            body = re.sub(r"\[[^\]]*\]", "", line).strip()
            if not tags or not body: continue
            words = None
            if re.search(r"<\d+:\d+", body):  # LRC nâng cao: <mm:ss.xx>chữ
                pieces = re.findall(r"<(\d+:\d+(?:\.\d+)?)>([^<]*)", body)
                words = [(w.strip(), _ts(t)) for t, w in pieces if w.strip()]
                body = " ".join(w for w, _ in words)
            for t in tags:
                out.append(dict(start=_ts(t), end=None, text=body, words=words))
    out.sort(key=lambda d: d["start"])
    for i, d in enumerate(out):
        nxt = out[i + 1]["start"] if i + 1 < len(out) else d["start"] + 6
        if d["end"] is None:
            d["end"] = min(nxt, d["start"] + 1.0 + 0.42 * len(d["text"].split()) + 1.5)
        w = d.pop("words")
        toks = d["text"].split()
        if w:
            starts = [s for _, s in w] + [d["end"]]
            d["syl"] = [(x, starts[k], starts[k + 1]) for k, (x, _) in enumerate(w)]
        else:  # tô đều theo số âm tiết, chừa 15% cuối cho chữ cuối ngân
            span = (d["end"] - d["start"]) * .85
            step = span / max(len(toks), 1)
            d["syl"] = [(x, d["start"] + k * step, d["start"] + (k + 1) * step) for k, x in enumerate(toks)]
            d["syl"][-1] = (toks[-1], d["syl"][-1][1], d["end"])
    return out


def norm(s):
    s = unicodedata.normalize("NFC", s.lower())
    return re.sub(r"[^\w ]", "", s).split()


def attach_sections(lines, lyrics_path):
    sec, seq = None, []
    for l in open(lyrics_path, encoding="utf-8"):
        l = l.strip()
        m = re.match(r"\[(.+)\]", l)
        if m: sec = SECTION_VI.get(m[1].lower(), m[1]); continue
        if l and sec: seq.append((sec, l))
    j = 0
    for L in lines:
        best, bj = 0, None
        for k in range(j, min(j + 6, len(seq))):  # dò tiến dần, cho phép bỏ qua vài câu
            r = difflib.SequenceMatcher(None, norm(L["text"]), norm(seq[k][1])).ratio()
            if r > best: best, bj = r, k
        if bj is not None and best > .5:
            L["section"] = seq[bj][0]; j = bj + 1
        else:
            L["section"] = lines[lines.index(L) - 1]["section"] if lines.index(L) else ""
    return lines


# ---------------------------------------------------------------- phụ đề ASS
def T(t):
    cs = int(round(max(t, 0) * 100))
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def esc(s):
    return s.replace("{", "(").replace("}", ")")


def write_ass(lines, path, duration):
    head = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Sing,Be Vietnam Pro ExtraBold,82,&H0060C8FF,&H00F0EAE6,&H00281810,&H8C000000,0,0,0,0,100,100,0.5,0,1,4,3,5,160,160,0,1
Style: Prev,Be Vietnam Pro,52,&H90F0EAE6,&H90F0EAE6,&HB0281810,&H00000000,1,0,0,0,100,100,0.5,0,1,2,0,5,200,200,0,1
Style: Title,Be Vietnam Pro ExtraBold,120,&H00F0EAE6,&H00F0EAE6,&H00281810,&H8C000000,0,0,0,0,100,100,3,0,1,5,4,5,80,80,0,1
Style: Sub,Be Vietnam Pro,44,&H0060C8FF,&H0060C8FF,&H00281810,&H00000000,1,0,0,0,100,100,10,0,1,2,0,5,80,80,0,1
Style: Tag,Be Vietnam Pro,34,&H50F0EAE6,&H50F0EAE6,&H00281810,&H00000000,1,0,0,0,100,100,8,0,1,2,0,7,70,70,56,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    ev = []
    first = lines[0]["start"] if lines else 8
    tend = max(min(first - .6, 14), 3)
    ev.append(f"Dialogue: 2,{T(.4)},{T(tend)},Title,,0,0,0,,{{\\pos(960,500)\\fad(1200,700)\\blur1}}{TITLE}")
    ev.append(f"Dialogue: 2,{T(1.2)},{T(tend)},Sub,,0,0,0,,{{\\pos(960,620)\\fad(1200,700)}}LYRIC VIDEO")
    lead = .3
    for i, L in enumerate(lines):
        st = L["start"] - lead
        if st > duration: break
        nxt = lines[i + 1]["start"] - lead if i + 1 < len(lines) else L["end"] + 2
        en = min(nxt, L["end"] + 2.5)
        parts, cur = [], st
        for w, s, e in L["syl"]:
            if s > cur: parts.append(f"{{\\k{int(round((s - cur) * 100))}}}")
            parts.append(f"{{\\kf{max(int(round((e - s) * 100)), 1)}}}{esc(w)} ")
            cur = max(e, cur)
        ev.append(f"Dialogue: 1,{T(st)},{T(en)},Sing,,0,0,0,,"
                  r"{\pos(960,540)\fad(350,300)\blur0.6}" + "".join(parts).rstrip())
        if i + 1 < len(lines) and lines[i + 1]["start"] - lead - en < 1:
            ev.append(f"Dialogue: 0,{T(st)},{T(en)},Prev,,0,0,0,,{{\\pos(960,700)\\fad(450,300)}}{esc(lines[i + 1]['text'])}")
        if L.get("section") and (i == 0 or lines[i - 1].get("section") != L["section"]):
            send = st
            for k in range(i, len(lines)):
                if lines[k]["section"] != L["section"]: break
                send = lines[k]["end"]
            ev.append(f"Dialogue: 0,{T(st)},{T(send)},Tag,,0,0,0,,{{\\fad(500,500)}}{L['section'].upper()}")
    open(path, "w", encoding="utf-8").write(head + "\n".join(ev) + "\n")


# ---------------------------------------------------------------- âm thanh
def analyze(audio, n):
    sr = 22050  # giải mã bằng ffmpeg (soundfile không đọc được m4a/aac)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", audio, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    y = np.frombuffer(raw, np.float32).copy()
    hop = sr // FPS
    on = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
    rms = librosa.feature.rms(y=y, hop_length=hop)[0]
    mel = librosa.feature.melspectrogram(y=y, sr=sr, hop_length=hop, n_mels=32, fmax=8000)
    low = librosa.power_to_db(mel[:4].sum(0) + 1e-9)

    def fit(x):
        x = np.asarray(x, float); return np.pad(x, (0, max(0, n - len(x))), mode="edge")[:n]

    def nz(x):
        lo, hi = np.percentile(x, 5), np.percentile(x, 98); return np.clip((x - lo) / (hi - lo + 1e-9), 0, 1)

    on, rms, low = nz(fit(on)), nz(fit(rms)), nz(fit(low))
    pulse = np.zeros(n); kick = np.zeros(n); energy = np.zeros(n); a = b = c = 0
    for i in range(n):
        a = max(on[i], a * .86); pulse[i] = a
        b = max(low[i] ** 2, b * .84); kick[i] = b
        c = c * .97 + rms[i] * .03; energy[i] = c   # độ to dài hạn: điệp khúc sáng hơn
    energy = np.clip((energy - energy.min()) / (np.ptp(energy) + 1e-9), 0, 1)
    return dict(pulse=pulse, kick=kick, energy=energy)


# ---------------------------------------------------------------- nền
def rgb(h, s, v): return np.array(colorsys.hsv_to_rgb(h % 1, s, v), np.float32)


class Background:
    """Phòng tối xanh xám, nắng hổ phách xiên qua cửa sổ, bụi bay lơ lửng, đập nhẹ theo nhịp."""

    def __init__(self, seed=7):
        rng = np.random.default_rng(seed)
        h4, w4 = H // 4, W // 4
        yy, xx = np.mgrid[0:h4, 0:w4].astype(np.float32)
        u, v = xx / w4, yy / h4
        self.vert = v[..., None]
        self.vign = np.clip(1 - ((u - .5) ** 2 * 1.3 + (v - .5) ** 2 * 1.9), 0, 1)[..., None] ** 1.3
        self.u, self.v = u, v
        self.halo = np.exp(-(((u - .5) * 1.8) ** 2 + ((v - .52) * 3.2) ** 2))[..., None]
        n = 160
        self.px, self.py = rng.uniform(0, W, n), rng.uniform(0, H, n)
        self.pz = rng.uniform(.3, 1, n); self.pp = rng.uniform(0, 6.28, n)
        self.grain = [rng.normal(0, 1, (H // 2, W // 2)).astype(np.float32) for _ in range(6)]
        self.spr = {}

    def sprite(self, r):
        r = max(int(r), 1)
        if r not in self.spr:
            yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
            self.spr[r] = np.clip(1 - np.sqrt(xx ** 2 + yy ** 2) / (r + .5), 0, 1) ** 2
        return self.spr[r]

    def frame(self, t, f, A):
        p, k, e = A["pulse"][f], A["kick"][f], A["energy"][f]
        top, bot = rgb(.60, .45, .13 + .05 * e), rgb(.58, .40, .25 + .07 * e)
        img = top * (1 - self.vert) + bot * self.vert
        # tia nắng xiên (đổi góc rất chậm), sáng thêm khi nhạc dày
        ang = .55 + .05 * np.sin(t * .05)
        d = (self.u - .18) * np.cos(ang) + (self.v - .0) * np.sin(ang)
        beam = np.zeros_like(d)
        for off, wd, s in ((.10, .06, 1), (.22, .04, .7), (.31, .08, .5)):
            beam += s * np.exp(-((d - off - .01 * np.sin(t * .3 + off * 9)) / wd) ** 2)
        beam = (beam * np.clip(1.2 - self.v * 1.1, 0, 1))[..., None]
        amber = rgb(.09, .62, 1)
        img = img + beam * amber * (.10 + .10 * e + .06 * k)
        img = img + self.halo * amber * (.05 + .07 * k + .05 * e)
        img = img * (.35 + .65 * self.vign)
        img = np.kron(img, np.ones((4, 4, 1), np.float32))
        # bụi bay trong nắng
        dust = np.zeros((H, W), np.float32)
        for i in range(len(self.px)):
            z = self.pz[i]
            x = (self.px[i] + t * 14 * z + 30 * np.sin(t * .2 * z + self.pp[i])) % W
            y = (self.py[i] - t * 9 * z + 20 * np.cos(t * .17 + self.pp[i])) % H
            r = 2 + 7 * z * (1 + .5 * k)
            s = self.sprite(r); R = s.shape[0] // 2
            x0, y0 = int(x) - R, int(y) - R
            xa, ya, xb, yb = max(x0, 0), max(y0, 0), min(x0 + s.shape[1], W), min(y0 + s.shape[0], H)
            if xa < xb and ya < yb:
                tw = .35 + .65 * (.5 + .5 * np.sin(t * 1.3 + self.pp[i] * 5))
                dust[ya:yb, xa:xb] += s[ya - y0:yb - y0, xa - x0:xb - x0] * z * tw * (.25 + .5 * p)
        img = img + dust[..., None] * rgb(.10, .35, 1) * .55
        g = self.grain[f % 6]
        img = img + np.kron(g, np.ones((2, 2), np.float32))[..., None] * .012
        return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", default=os.path.join(HERE, "cuoi_voi_doi.m4a"))
    ap.add_argument("--lyrics", default=os.path.join(HERE, "LOI_BAI_HAT.txt"))
    ap.add_argument("--timing", required=True, help="file .lrc hoặc .srt")
    ap.add_argument("--start", type=float, default=0, help="bắt đầu từ giây thứ…")
    ap.add_argument("--duration", type=float, default=None)
    ap.add_argument("-o", "--out", default=os.path.join(HERE, "cuoi_voi_doi_lyric.mp4"))
    a = ap.parse_args()

    total = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                           "-of", "csv=p=0", a.audio]).strip())
    t0 = a.start; dur = min(a.duration or total - t0, total - t0)
    lines = attach_sections(read_timing(a.timing), a.lyrics)
    for L in lines:
        print(f"{L['start']:7.2f}  {L['section'][:14]:14}  {L['text']}")
    n_all = int((t0 + dur) * FPS)
    A = analyze(a.audio, n_all)
    ass = os.path.splitext(a.out)[0] + ".ass"
    write_ass(lines, ass, t0 + dur)
    cut = a.duration is not None and t0 + dur < total
    vf = f"setpts=PTS+{t0}/TB,ass='{ass}':fontsdir='{FONTS}',setpts=PTS-STARTPTS,hqdn3d=3:2:4:3,fade=t=in:st=0:d=0.8"
    af = "afade=t=in:st=0:d=0.5" if t0 else "anull"
    if cut or t0:
        vf += f",fade=t=out:st={dur - 1}:d=1"; af += f",afade=t=out:st={dur - 1}:d=1"
    cmd = ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
           "-i", "-", "-ss", f"{t0:.3f}", "-t", f"{dur:.3f}", "-i", a.audio, "-vf", vf, "-af", af,
           "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "24", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", a.out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    bg = Background()
    f0 = int(t0 * FPS)
    for f in range(f0, f0 + int(dur * FPS)):
        p.stdin.write(bg.frame(f / FPS, f, A).tobytes())
        if (f - f0) % (FPS * 10) == 0: print(f"  {(f - f0) / FPS:5.0f}s / {dur:.0f}s", file=sys.stderr)
    p.stdin.close(); p.wait()
    if p.returncode: sys.exit("ffmpeg lỗi")
    print("Xong:", a.out)


if __name__ == "__main__":
    main()
