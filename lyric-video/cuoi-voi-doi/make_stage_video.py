"""Lyric video sân khấu: nhân vật đứng trước mic, nhún và đung đưa theo beat dưới đèn chiếu.

Dùng lại phần đọc mốc giờ và phụ đề của make_video.py.
Chạy:  python3 make_stage_video.py --start 18 --duration 30 -o ban_nhap_san_khau_30s.mp4
       python3 make_stage_video.py -o cuoi_voi_doi_san_khau.mp4
"""
import argparse, os, subprocess, sys
import numpy as np, cv2, librosa
import make_video as mv

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = mv.W, mv.H, mv.FPS
CHAR_H = 1000          # chiều cao nhân vật trên khung hình
CHAR_TOP = 30


def load_audio(path, sr=22050):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy(), sr


def beat_info(y, sr, n):
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr, units="time")
    beats = np.asarray(beats, float)
    t = np.arange(n) / FPS
    k = np.clip(np.searchsorted(beats, t) - 1, 0, len(beats) - 2)
    span = beats[k + 1] - beats[k]
    phase = np.where(t < beats[0], 0, np.clip((t - beats[k]) / span, 0, 1))   # 0..1 trong mỗi phách
    count = np.where(t < beats[0], 0, k)                                       # số thứ tự phách
    return float(np.atleast_1d(tempo)[0]), phase, count


class Stage:
    def __init__(self, char_png):
        rgba = cv2.imread(char_png, cv2.IMREAD_UNCHANGED)
        s = CHAR_H / rgba.shape[0]
        rgba = cv2.resize(rgba, (int(rgba.shape[1] * s), CHAR_H), interpolation=cv2.INTER_AREA)
        self.rgb = rgba[..., :3][..., ::-1].astype(np.float32) / 255
        self.a = (rgba[..., 3].astype(np.float32) / 255)[..., None]
        self.cw = rgba.shape[1]
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        self.xx, self.yy = xx, yy
        u, v = xx / W, yy / H
        # nền: tường tối, quầng sáng sau lưng
        self.base = np.dstack([.035 + .02 * v, .03 + .02 * v, .05 + .03 * v]).astype(np.float32)
        self.backglow = np.exp(-(((u - .5) / .28) ** 2 + ((v - .42) / .38) ** 2))[..., None].astype(np.float32)
        # đèn chiếu chính từ trên xuống, toả hình nón
        apex_y = -80
        half = 60 + (yy - apex_y) * .30
        cone = np.clip(1 - np.abs(xx - W / 2) / half, 0, 1) ** 1.6
        self.cone = (cone * np.clip((yy - apex_y) / 600, 0, 1) * (yy < 960)).astype(np.float32)[..., None]
        # vũng sáng trên sàn
        self.pool = np.exp(-(((xx - W / 2) / 430) ** 2 + ((yy - 960) / 70) ** 2)).astype(np.float32)[..., None]
        # sàn sân khấu
        self.floor = np.clip((yy - 900) / 180, 0, 1)[..., None].astype(np.float32)
        # sương mù dưới chân
        rng = np.random.default_rng(3)
        fog = cv2.GaussianBlur(rng.random((H // 8, W // 4)).astype(np.float32), (0, 0), 6)
        self.fog = cv2.resize(fog, (W * 2, H), interpolation=cv2.INTER_CUBIC)
        self.fogmask = np.clip((yy - 760) / 260, 0, 1).astype(np.float32)
        n = 140
        self.px, self.py = rng.uniform(W * .25, W * .75, n), rng.uniform(0, 950, n)
        self.pz, self.pp = rng.uniform(.3, 1, n), rng.uniform(0, 6.28, n)

    def side_beam(self, x0, angle, width):
        # tia đèn màu từ góc trên, xoay theo angle (radian)
        dx, dy = np.sin(angle), np.cos(angle)
        X, Y = self.xx - x0, self.yy + 40
        along = X * dx + Y * dy
        across = np.abs(X * dy - Y * dx)
        return (np.clip(1 - across / (width + along * .12), 0, 1) ** 2 * np.clip(along / 400, 0, 1)
                * np.exp(-along / 1500)).astype(np.float32)

    def frame(self, t, ph, cnt, kick, pulse, energy):
        img = self.base.copy()
        img += self.backglow * np.array([.10, .07, .05], np.float32) * (.6 + .6 * energy)
        spot = .55 + .25 * energy + .30 * kick
        warm = np.array([1.0, .82, .58], np.float32)
        img += self.cone * warm * .16 * spot
        # 2 tia đèn màu quét chậm theo nhịp (đổi hướng mỗi 2 phách)
        sw = np.sin(np.pi * (cnt + ph) / 2)
        b1 = self.side_beam(260, -.55 + .22 * sw, 26)
        b2 = self.side_beam(W - 260, .55 + .22 * sw, 26)
        img += b1[..., None] * np.array([.25, .45, 1.0], np.float32) * (.10 + .12 * pulse)
        img += b2[..., None] * np.array([1.0, .45, .25], np.float32) * (.10 + .12 * pulse)
        # sàn
        img = img * (1 - self.floor * .3) + self.floor * np.array([.05, .045, .05], np.float32)
        img += self.pool * warm * (.22 + .18 * kick)

        # nhân vật: nhún xuống ở mỗi phách, đung đưa trái phải theo 2 phách, lắc nhẹ đầu
        bob = 14 * (1 - np.cos(2 * np.pi * ph)) / 2 * (.6 + .4 * energy)
        ang = 2.4 * np.sin(np.pi * (cnt + ph)) * (.7 + .3 * energy)
        cx = W / 2 + 8 * np.sin(np.pi * (cnt + ph))
        piv = (self.cw / 2, CHAR_H * .78)
        M = cv2.getRotationMatrix2D(piv, ang, 1 + .006 * kick)
        M[0, 2] += cx - self.cw / 2
        M[1, 2] += CHAR_TOP + bob
        rgb = cv2.warpAffine(self.rgb, M, (W, H), flags=cv2.INTER_LINEAR, borderValue=(0, 0, 0))
        a = cv2.warpAffine(self.a, M, (W, H), flags=cv2.INTER_LINEAR, borderValue=0)[..., None]
        # ánh đèn chiếu lên người: sáng hơn ở trên, viền cam
        lit = rgb * (.80 + .30 * spot * self.cone) + rgb * warm * .10 * kick
        img = img * (1 - a) + lit * a

        # micro đứng: đầu mic bám theo miệng nhân vật (đung đưa cùng), chân đế cố định
        mouth = np.array([self.cw * .487, CHAR_H * .175, 1.0])
        mx, my = (M @ mouth).astype(int); mx += 14; my += 22
        canvas = (np.clip(img, 0, 1) * 255).astype(np.uint8)
        bx = int(W / 2 + 190)
        cv2.line(canvas, (bx, 1010), (bx, 520), (28, 28, 32), 10, cv2.LINE_AA)
        cv2.line(canvas, (bx, 520), (mx + 20, my + 34), (40, 40, 44), 8, cv2.LINE_AA)
        for dx in (-70, 0, 70):
            cv2.line(canvas, (bx, 990), (bx + dx, 1022), (24, 24, 27), 9, cv2.LINE_AA)
        cv2.ellipse(canvas, (mx + 8, my + 16), (14, 34), -32, 0, 360, (35, 35, 40), -1, cv2.LINE_AA)
        cv2.ellipse(canvas, (mx, my), (24, 30), -32, 0, 360, (95, 95, 102), -1, cv2.LINE_AA)
        cv2.ellipse(canvas, (mx - 5, my - 7), (11, 13), -32, 0, 360, (200, 192, 180), -1, cv2.LINE_AA)
        img = canvas.astype(np.float32) / 255

        # sương mù trôi + bụi bay trong luồng sáng
        off = int(t * 22) % W
        fog = self.fog[:, off:off + W] * self.fogmask
        img += fog[..., None] * np.array([.30, .27, .26], np.float32) * (.5 + .3 * energy)
        dust = np.zeros((H, W), np.float32)
        for i in range(len(self.px)):
            x = int((self.px[i] + 15 * np.sin(t * .3 + self.pp[i])) % W)
            y = int((self.py[i] - t * 12 * self.pz[i]) % 950)
            r = 1 + int(3 * self.pz[i])
            cv2.circle(dust, (x, y), r, float(self.pz[i] * (.3 + .7 * pulse)), -1, cv2.LINE_AA)
        dust = cv2.GaussianBlur(dust, (0, 0), 1.2) * (self.cone[..., 0] + .15)
        img += dust[..., None] * warm * .9
        # viền tối
        return (np.clip(img, 0, 1) * 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", default=os.path.join(HERE, "cuoi_voi_doi.m4a"))
    ap.add_argument("--lyrics", default=os.path.join(HERE, "LOI_BAI_HAT.txt"))
    ap.add_argument("--timing", default=os.path.join(HERE, "moc_gio_khop.lrc"))
    ap.add_argument("--char", default=os.path.join(HERE, "nhan_vat.png"))
    ap.add_argument("--start", type=float, default=0)
    ap.add_argument("--duration", type=float, default=None)
    ap.add_argument("-o", "--out", default=os.path.join(HERE, "cuoi_voi_doi_san_khau.mp4"))
    a = ap.parse_args()

    y, sr = load_audio(a.audio)
    total = len(y) / sr
    t0 = a.start; dur = min(a.duration or total - t0, total - t0)
    n_all = int((t0 + dur) * FPS)
    A = mv.analyze(a.audio, n_all)
    tempo, phase, count = beat_info(y, sr, n_all)
    print(f"tempo ≈ {tempo:.1f} BPM")
    lines = mv.attach_sections(mv.read_timing(a.timing), a.lyrics)
    ass = os.path.splitext(a.out)[0] + ".ass"
    mv.write_ass(lines, ass, t0 + dur, y_sing=925, y_next=1010, y_title=140, sing_size=70)

    cut = a.duration is not None and t0 + dur < total
    vf = f"setpts=PTS+{t0}/TB,ass='{ass}':fontsdir='{mv.FONTS}',setpts=PTS-STARTPTS,fade=t=in:st=0:d=0.8"
    af = "afade=t=in:st=0:d=0.5" if t0 else "anull"
    if cut or t0:
        vf += f",fade=t=out:st={dur - 1}:d=1"; af += f",afade=t=out:st={dur - 1}:d=1"
    cmd = ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
           "-i", "-", "-ss", f"{t0:.3f}", "-t", f"{dur:.3f}", "-i", a.audio, "-vf", vf, "-af", af,
           "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "22", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", a.out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    st = Stage(a.char)
    f0 = int(t0 * FPS)
    for f in range(f0, f0 + int(dur * FPS)):
        p.stdin.write(st.frame(f / FPS, phase[f], count[f], A["kick"][f], A["pulse"][f], A["energy"][f]).tobytes())
        if (f - f0) % (FPS * 10) == 0: print(f"  {(f - f0) / FPS:5.0f}s / {dur:.0f}s", file=sys.stderr)
    p.stdin.close(); p.wait()
    if p.returncode: sys.exit("ffmpeg lỗi")
    print("Xong:", a.out)


if __name__ == "__main__":
    main()
