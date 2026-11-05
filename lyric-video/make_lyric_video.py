"""Lyric video 16:9 cho "Sinh nhật anh Ủn 9 tuổi".

- Lời lấy từ LOI_BAI_HAT.md, thời điểm từng chữ lấy từ giai điệu trong make_beat.py
  (120 BPM, mỗi câu 2 ô nhịp = 4 giây), nên chữ đổi màu đúng lúc chuông ngân nốt đó.
- Nền vẽ bằng numpy/Pillow, chuyển động theo onset, độ to và phổ âm thanh (librosa).
- Chữ render bằng libass (ffmpeg) với font Be Vietnam Pro, dấu tiếng Việt chuẩn.

Chạy:  python3 make_lyric_video.py --duration 30 -o ban_nhap_30s.mp4   (bản nháp)
       python3 make_lyric_video.py -o lyric_video.mp4                  (cả bài)
"""
import argparse, colorsys, os, re, subprocess, sys
import numpy as np
import librosa
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1920, 1080, 30
BEAT = 0.5          # 120 BPM
BAR = 4 * BEAT

# Giai điệu (vị trí nốt, tính bằng phách từ đầu câu) — chép từ make_beat.py
VERSE_MEL = [[0, .5, 1, 2, 3], [0, .5, 1, 2, 3], [0, .5, 1, 1.5, 2, 3, 4], [0, .5, 1, 2, 3]]
VERSE_DUR = [[.5, .5, 1, 1, 3], [.5, .5, 1, 1, 3], [.5, .5, .5, .5, 1, 1, 2], [.5, .5, 1, 1, 3]]
CHORUS_MEL = [[0, .5, 1, 2, 3], [0, .5, 1, 2, 3], [0, .5, 1, 1.5, 2, 3, 4], [0, .5, 1, 2, 4]]
CHORUS_DUR = [[.5, .5, 1, 1, 3], [.5, .5, 1, 1, 3], [.5, .5, .5, .5, 1, 1, 2], [.5, .5, 1, 2, 4]]
SECTION_START = {"Đoạn 1": 8, "Đoạn 2": 24, "Đoạn 3": 40, "Điệp khúc": 56, "Điệp khúc (lần 2)": 72}
OUTRO = 88

# Màu nền từng phần (hue 0..1)
PALETTE = [(0, .78), (8, .92), (24, .55), (40, .08), (56, .86), (72, .95), (88, .12)]


# ---------------------------------------------------------------- lời & thời gian
def parse_lyrics(md_path):
    rows = {}
    for line in open(md_path, encoding="utf-8"):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 3 and cells[1] in SECTION_START:
            rows[cells[1]] = cells[2]
    if "(" in rows.get("Điệp khúc (lần 2)", "("):
        rows["Điệp khúc (lần 2)"] = rows["Điệp khúc"]
    return rows


def syllable_times(words, starts, durs, t0):
    """Ghép từng chữ (âm tiết) với nốt nhạc. Thừa nốt -> chữ cuối ngân dài;
    thiếu nốt -> chia đều nốt cuối cho các chữ còn lại."""
    n, m = len(words), len(starts)
    end = starts[-1] + durs[-1]
    if n <= m:
        on = list(starts[:n])
    else:
        k = n - m + 1
        on = list(starts[:m - 1]) + [starts[-1] + durs[-1] * j / k for j in range(k)]
    off = on[1:] + [end]
    return [(w, t0 + s * BEAT, t0 + e * BEAT) for w, s, e in zip(words, on, off)]


def build_lines(md_path):
    rows = parse_lyrics(md_path)
    lines = []
    for sec, t0 in SECTION_START.items():
        chorus = sec.startswith("Điệp")
        mel, dur = (CHORUS_MEL, CHORUS_DUR) if chorus else (VERSE_MEL, VERSE_DUR)
        for i, text in enumerate([s.strip() for s in rows[sec].split("/")]):
            tl = t0 + i * 2 * BAR
            lines.append(dict(section=sec, text=text, start=tl, end=tl + 2 * BAR,
                              syl=syllable_times(text.split(), mel[i], dur[i], tl)))
    # Kết: "Một, hai, ba, thổi nến nào!" theo trống dồn, rồi câu hô
    a = "Một, hai, ba, thổi nến nào!".split()
    lines.append(dict(section="Kết", text=" ".join(a), start=OUTRO, end=OUTRO + 4,
                      syl=[(w, OUTRO + i * .5, OUTRO + i * .5 + .5) for i, w in enumerate(a[:-1])]
                      + [(a[-1], OUTRO + 2.5, OUTRO + 4)]))
    b = "Anh Ủn chín tuổi! Yeah yeah yeah!".split()
    lines.append(dict(section="Kết", text=" ".join(b), start=OUTRO + 4, end=OUTRO + 11,
                      syl=[(w, OUTRO + 4 + i * .35, OUTRO + 4 + i * .35 + .35) for i, w in enumerate(b)]))
    return lines


# ---------------------------------------------------------------- phụ đề ASS
def ass_time(t):
    t = max(t, 0); cs = int(round(t * 100))
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def write_ass(lines, path, duration):
    head = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Sing,Be Vietnam Pro ExtraBold,104,&H0040E0FF,&H00FFFFFF,&H00501A2E,&H96000000,0,0,0,0,100,100,1,0,1,7,4,5,80,80,0,1
Style: Next,Be Vietnam Pro,62,&H50FFFFFF,&H50FFFFFF,&H70301020,&H00000000,1,0,0,0,100,100,1,0,1,4,0,5,80,80,0,1
Style: Title,Be Vietnam Pro ExtraBold,128,&H00FFFFFF,&H00FFFFFF,&H00501A2E,&H96000000,0,0,0,0,100,100,2,0,1,8,5,5,80,80,0,1
Style: Sub,Be Vietnam Pro,54,&H0040E0FF,&H0040E0FF,&H00501A2E,&H00000000,1,0,0,0,100,100,6,0,1,4,0,5,80,80,0,1
Style: Tag,Be Vietnam Pro,36,&H30FFFFFF,&H30FFFFFF,&H00301020,&H00000000,1,0,0,0,100,100,8,0,1,2,0,7,60,60,50,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    ev = []
    # Tiêu đề trong phần dạo đầu (0 -> 7.5s), nhún theo phách
    ev.append(f"Dialogue: 2,{ass_time(.3)},{ass_time(7.4)},Title,,0,0,0,,"
              r"{\pos(960,470)\fad(500,400)\t(0,600,\fscx100\fscy100)\fscx70\fscy70}Sinh nhật anh Ủn")
    ev.append(f"Dialogue: 2,{ass_time(1.0)},{ass_time(7.4)},Sub,,0,0,0,,"
              r"{\pos(960,610)\fad(500,400)}CHÍN TUỔI  •  LYRIC VIDEO")
    lead = .35
    for i, L in enumerate(lines):
        st = L["start"] - lead
        en = lines[i + 1]["start"] - lead if i + 1 < len(lines) else L["end"]
        if st > duration: break
        # câu đang hát: hiệu ứng tô màu theo từng chữ (\kf), xuất hiện bật nảy
        parts, cur = [], st
        for w, s, e in L["syl"]:
            if s > cur:
                parts.append(f"{{\\k{int(round((s - cur) * 100))}}}")
            parts.append(f"{{\\kf{int(round((e - s) * 100))}}}{w} ")
            cur = e
        txt = "".join(parts).rstrip()
        ev.append(f"Dialogue: 1,{ass_time(st)},{ass_time(en)},Sing,,0,0,0,,"
                  r"{\pos(960,540)\fad(180,160)\fscx92\fscy92\t(0,220,\fscx100\fscy100)}" + txt)
        # câu tiếp theo (mờ, nhỏ) để người xem chuẩn bị hát
        if i + 1 < len(lines):
            ev.append(f"Dialogue: 0,{ass_time(st)},{ass_time(en)},Next,,0,0,0,,"
                      r"{\pos(960,680)\fad(250,160)}" + lines[i + 1]["text"])
        # nhãn phần ở góc
        if i == 0 or lines[i - 1]["section"] != L["section"]:
            send = max(l["end"] for l in lines if l["section"] == L["section"])
            ev.append(f"Dialogue: 0,{ass_time(st)},{ass_time(send - lead)},Tag,,0,0,0,,"
                      r"{\fad(300,300)}" + L["section"].upper())
    open(path, "w", encoding="utf-8").write(head + "\n".join(ev) + "\n")


# ---------------------------------------------------------------- phân tích âm thanh
def analyze(audio, n_frames):
    y, sr = librosa.load(audio, sr=22050, mono=True)
    hop = sr // FPS  # ~1 khung hình
    onset = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
    rms = librosa.feature.rms(y=y, hop_length=hop)[0]
    mel = librosa.power_to_db(librosa.feature.melspectrogram(y=y, sr=sr, hop_length=hop, n_mels=48, fmax=9000), ref=np.max)
    low = librosa.power_to_db(librosa.feature.melspectrogram(y=y, sr=sr, hop_length=hop, n_mels=48, fmax=9000)[:5].sum(0) + 1e-9)

    def fit(x):
        x = np.asarray(x, float)
        x = np.pad(x, (0, max(0, n_frames - len(x))), mode="edge")[:n_frames]
        return x

    def norm(x):
        lo, hi = np.percentile(x, 5), np.percentile(x, 98)
        return np.clip((x - lo) / (hi - lo + 1e-9), 0, 1)

    onset, rms, low = norm(fit(onset)), norm(fit(rms)), norm(fit(low))
    spec = np.clip((mel + 60) / 60, 0, 1)
    spec = np.stack([fit(r) for r in spec])  # (48, n)
    # đường "đập": bật lên ở phách, tắt dần (attack nhanh, release chậm)
    pulse = np.zeros(n_frames); kick = np.zeros(n_frames); v = k = 0
    for i in range(n_frames):
        v = max(onset[i], v * .82); pulse[i] = v
        k = max(low[i] ** 2, k * .80); kick[i] = k
    # làm mượt phổ theo thời gian
    for i in range(1, n_frames):
        spec[:, i] = np.maximum(spec[:, i], spec[:, i - 1] * .85)
    return dict(pulse=pulse, kick=kick, rms=rms, spec=spec)


# ---------------------------------------------------------------- nền chuyển động
def hsv(h, s, v):
    return np.array(colorsys.hsv_to_rgb(h % 1, s, v)) * 255


def hue_at(t):
    for (t0, h0), (t1, h1) in zip(PALETTE, PALETTE[1:]):
        if t < t1:
            x = np.clip((t - (t1 - 1.0)) / 1.0, 0, 1)  # chuyển màu trong 1 giây trước khi sang phần mới
            d = (h1 - h0 + .5) % 1 - .5
            return h0 + d * x
    return PALETTE[-1][1]


def glow_sprite(r):
    yy, xx = np.mgrid[-r:r, -r:r]
    a = np.clip(1 - np.sqrt(xx ** 2 + yy ** 2) / r, 0, 1) ** 2.2
    return a


class Background:
    def __init__(self, seed=9):
        rng = np.random.default_rng(seed)
        self.yy = np.linspace(0, 1, H)[:, None, None]
        xs, ys = np.mgrid[0:H // 4, 0:W // 4]
        self.rad = np.sqrt(((ys - W / 8) / (W / 4)) ** 2 + ((xs - H / 8) / (H / 4)) ** 2)[..., None]
        # bóng bay / bokeh bay lên
        n = 46
        self.px = rng.uniform(0, W, n); self.py = rng.uniform(0, H, n)
        self.pr = rng.uniform(14, 70, n); self.ps = rng.uniform(25, 90, n)
        self.ph = rng.uniform(0, 1, n); self.pw = rng.uniform(0, 6.28, n)
        self.sprites = {}
        # ngôi sao lấp lánh
        m = 90
        self.sx = rng.uniform(0, W, m); self.sy = rng.uniform(0, H * .8, m); self.sp = rng.uniform(0, 6.28, m)

    def sprite(self, r):
        r = int(r)
        if r not in self.sprites:
            self.sprites[r] = glow_sprite(r)
        return self.sprites[r]

    def frame(self, t, f, A):
        pulse, kick, rms = A["pulse"][f], A["kick"][f], A["rms"][f]
        h = hue_at(t)
        top = hsv(h, .75, .18 + .10 * rms)
        bot = hsv(h + .08, .85, .38 + .22 * rms)
        img = (top * (1 - self.yy) + bot * self.yy).repeat(W, 1)
        # quầng sáng trung tâm phình theo kick
        halo = np.clip(1 - self.rad / (0.55 + .25 * kick), 0, 1) ** 2 * (.35 + .55 * kick)
        halo = np.kron(halo, np.ones((4, 4, 1)))[:H, :W]
        img += halo * hsv(h + .5, .45, 1)[None, None] * .55
        img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))

        layer = np.zeros((H, W), np.float32); col = np.zeros((H, W, 3), np.float32)
        # bóng bay bokeh: bay lên, lắc lư, nảy to theo nhịp
        for i in range(len(self.px)):
            y = (self.py[i] - t * self.ps[i] * (1 + .6 * rms)) % (H + 200) - 100
            x = self.px[i] + 40 * np.sin(t * .7 + self.pw[i])
            r = self.pr[i] * (1 + .45 * kick)
            s = self.sprite(r); x0, y0 = int(x - r), int(y - r)
            xa, ya, xb, yb = max(x0, 0), max(y0, 0), min(x0 + s.shape[1], W), min(y0 + s.shape[0], H)
            if xa >= xb or ya >= yb: continue
            a = s[ya - y0:yb - y0, xa - x0:xb - x0] * (.25 + .35 * pulse)
            c = hsv(h + .25 + self.ph[i] * .5, .55, 1) / 255
            layer[ya:yb, xa:xb] += a
            col[ya:yb, xa:xb] += a[..., None] * c
        # sao lấp lánh nháy theo onset
        tw = np.clip(.5 + .5 * np.sin(t * 3 + self.sp) , 0, 1) * (.3 + .7 * pulse)
        for x, y, a in zip(self.sx.astype(int), self.sy.astype(int), tw):
            col[max(y - 1, 0):y + 2, max(x - 1, 0):x + 2] += a
        base = np.asarray(img, np.float32) / 255
        out = base * (1 - np.clip(layer, 0, 1)[..., None] * .5) + col
        # chớp sáng nhẹ trên mỗi phách mạnh
        out += (kick ** 3) * .07
        img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))

        # thanh phổ ở đáy + vạch gương phía trên
        d = ImageDraw.Draw(img, "RGBA")
        spec = A["spec"][:, f]; nb = len(spec); bw = W / (nb * 2)
        vals = np.concatenate([spec[::-1], spec])
        c = tuple(int(v) for v in hsv(h + .5, .35, 1))
        for k, v in enumerate(vals):
            bh = 8 + v ** 1.6 * 190
            x0 = k * bw + bw * .18
            d.rounded_rectangle([x0, H - 30 - bh, x0 + bw * .64, H - 30], radius=int(bw * .3), fill=c + (150,))
        # vòng tròn nhịp quanh lời bài hát
        R = 330 + 60 * kick
        d.ellipse([W / 2 - R * 1.6, H / 2 - R * .62, W / 2 + R * 1.6, H / 2 + R * .62],
                  outline=c + (int(30 + 90 * kick),), width=3)
        return img


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", default=os.path.join(HERE, "sinh_nhat_anh_Un.mp3"))
    ap.add_argument("--lyrics", default=os.path.join(HERE, "LOI_BAI_HAT.md"))
    ap.add_argument("--duration", type=float, default=None, help="chỉ xuất N giây đầu (bản nháp)")
    ap.add_argument("-o", "--out", default=os.path.join(HERE, "lyric_video.mp4"))
    a = ap.parse_args()

    total = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                           "-of", "csv=p=0", a.audio]).strip())
    dur = min(a.duration or total, total)
    n = int(dur * FPS)
    print(f"Phân tích âm thanh… ({dur:.1f}s, {n} khung hình)")
    A = analyze(a.audio, n)
    lines = build_lines(a.lyrics)
    ass = os.path.splitext(a.out)[0] + ".ass"
    write_ass(lines, ass, dur)

    fonts = os.path.join(HERE, "fonts")
    vf = f"ass='{ass}':fontsdir='{fonts}',fade=t=in:st=0:d=0.6"
    if a.duration and a.duration < total:
        vf += f",fade=t=out:st={dur - .8}:d=0.8"
    af = f"afade=t=out:st={dur - .8}:d=0.8" if a.duration and a.duration < total else "anull"
    cmd = ["ffmpeg", "-y", "-v", "error",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-i", a.audio, "-t", f"{dur:.3f}",
           "-vf", vf, "-af", af,
           "-map", "0:v", "-map", "1:a",
           "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", a.out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    bg = Background()
    for f in range(n):
        p.stdin.write(bg.frame(f / FPS, f, A).tobytes())
        if f % (FPS * 5) == 0:
            print(f"  {f / FPS:5.1f}s / {dur:.1f}s", file=sys.stderr)
    p.stdin.close(); p.wait()
    if p.returncode:
        sys.exit("ffmpeg lỗi")
    print("Xong:", a.out)


if __name__ == "__main__":
    main()
