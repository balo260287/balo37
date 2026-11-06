"""Lyric video sân khấu concert: đèn moving-head quét theo beat, màn LED, khói, khán giả;
nhân vật gật đầu, mấp máy miệng theo giọng hát (giong_hat_30fps.npy), thở và nhún theo beat.

Dựng hình ở 1280x720 rồi phóng lên 1920x1080 trước khi chèn chữ (chữ vẫn nét ở 1080p).
Chạy:  python3 make_concert_video.py --start 18 --duration 30 -o ban_nhap_concert_30s.mp4
       python3 make_concert_video.py -o cuoi_voi_doi_concert.mp4
"""
import argparse, os, subprocess, sys
import numpy as np, cv2
import make_video as mv
from make_stage_video import load_audio, beat_info

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1280, 720, mv.FPS
# toạ độ trên ảnh gốc nhan_vat.png (1264x1590)
MOUTH = (630, 287); CHIN_Y = 335; NECK = (630, 365)
CH = 610   # chiều cao nhân vật trên khung 720p
CTOP = 40
NO_STAND = False   # bản có tay cầm mic thì không vẽ mic đứng


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


class Character:
    def __init__(self, path):
        rgba = cv2.imread(path, cv2.IMREAD_UNCHANGED).astype(np.float32) / 255
        self.s = s = CH / rgba.shape[0]
        self.img = cv2.resize(rgba, (int(rgba.shape[1] * s), CH), interpolation=cv2.INTER_AREA)
        h, w = self.img.shape[:2]
        self.h, self.w = h, w
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        self.xx, self.yy = xx, yy
        mx, my = MOUTH[0] * s, MOUTH[1] * s
        cy, nx, ny = CHIN_Y * s, NECK[0] * s, NECK[1] * s
        self.neck = (nx, ny)
        # vùng đầu (xoay quanh cổ), giảm dần xuống vai
        self.w_head = (1 - smooth(yy, ny - 10, ny + 25)).astype(np.float32)
        # vùng hàm: dưới môi tới cằm, hẹp theo chiều ngang
        gx = np.exp(-((xx - mx) / (16 * s / .377)) ** 2)
        self.w_jaw = (gx * smooth(yy, my - 2, my + 6) * (1 - smooth(yy, cy + 4, ny))).astype(np.float32)
        self.mouth = (mx, my)
        # vùng ngực để "thở"
        self.w_chest = (smooth(yy, ny, ny + 40) * (1 - smooth(yy, h * .62, h * .75))).astype(np.float32)
        self.cx = w / 2

    def render(self, head_ang, nod, jaw_open, breath):
        xx, yy = self.xx, self.yy
        nx, ny = self.neck
        # xoay đầu: lấy mẫu ngược
        a = -np.deg2rad(head_ang) * self.w_head
        dx, dy = xx - nx, yy - ny
        sx = nx + dx * np.cos(a) - dy * np.sin(a)
        sy = ny + dx * np.sin(a) + dy * np.cos(a) - nod * self.w_head
        # há miệng: kéo hàm xuống
        sy = sy - jaw_open * self.w_jaw
        # thở: ngực nở ngang nhẹ
        sx = self.cx + (sx - self.cx) / (1 + breath * self.w_chest)
        out = cv2.remap(self.img, sx.astype(np.float32), sy.astype(np.float32), cv2.INTER_LINEAR,
                        borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        # khoang miệng tối khi há
        if jaw_open > .6:
            mx, my = self.mouth
            m = np.zeros(out.shape[:2], np.float32)
            cv2.ellipse(m, (int(mx), int(my + jaw_open * .45)), (int(7 + jaw_open * .6), max(1, int(jaw_open * .5))),
                        0, 0, 360, 1.0, -1, cv2.LINE_AA)
            m = cv2.GaussianBlur(m, (0, 0), 1.0)[..., None] * .85
            out[..., :3] = out[..., :3] * (1 - m) + np.array([.04, .03, .05], np.float32) * m
        return out


class Concert:
    def __init__(self, char):
        rng = np.random.default_rng(11)
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        u, v = xx / W, yy / H
        self.u, self.v = u, v
        self.base = np.dstack([.02 + .02 * v, .015 + .02 * v, .04 + .03 * v]).astype(np.float32)
        # màn LED phía sau: lưới chấm
        dots = np.zeros((H, W), np.float32)
        for y in range(30, 400, 14):
            for x in range(10, W, 14):
                cv2.circle(dots, (x, y), 3, 1.0, -1, cv2.LINE_AA)
        self.dots = (dots * (1 - smooth(yy, 330, 420))).astype(np.float32)
        # vũng sáng sàn và nón đèn chiếu chính
        self.pool = np.exp(-(((xx - W / 2) / 300) ** 2 + ((yy - 640) / 45) ** 2))[..., None].astype(np.float32)
        half = 40 + (yy + 60) * .28
        self.cone = (np.clip(1 - np.abs(xx - W / 2) / half, 0, 1) ** 1.8 * (yy < 650)).astype(np.float32)[..., None]
        self.floor = smooth(yy, 600, 720)[..., None].astype(np.float32)
        # khói
        fog = cv2.GaussianBlur(rng.random((H // 6, W // 3)).astype(np.float32), (0, 0), 5)
        self.fog = cv2.resize(fog, (W * 2, H), interpolation=cv2.INTER_CUBIC)
        self.fogmask = (smooth(yy, 380, 720) * .9 + .1).astype(np.float32)
        # đèn moving-head trên giàn (tính ở 1/4 độ phân giải)
        self.q = (W // 4, H // 4)
        qy, qx = np.mgrid[0:H // 4, 0:W // 4].astype(np.float32)
        self.qx, self.qy = qx * 4, qy * 4
        self.heads = [(W * k / 7, -10) for k in range(1, 7)]
        self.hcol = [np.array(c, np.float32) for c in
                     [(.3, .5, 1), (1, .3, .7), (1, .75, .3), (1, .75, .3), (1, .3, .7), (.3, .5, 1)]]
        # khán giả: bóng đầu vai ở tiền cảnh
        aud = np.zeros((H + 40, W), np.float32)
        for i in range(70):
            x = rng.uniform(-20, W + 20); y = rng.uniform(H - 40, H + 25); r = rng.uniform(20, 34)
            cv2.ellipse(aud, (int(x), int(y)), (int(r * 1.9), int(r * 1.4)), 0, 180, 360, 1, -1, cv2.LINE_AA)
            cv2.circle(aud, (int(x), int(y - r * 1.5)), int(r * .62), 1, -1, cv2.LINE_AA)
        self.aud = cv2.GaussianBlur(aud, (0, 0), 1.5)
        self.phones = [(rng.uniform(40, W - 40), rng.uniform(H - 120, H - 70), rng.uniform(0, 6.28)) for _ in range(14)]
        self.char = char

    def beams(self, t, cnt, ph, pulse):
        out = np.zeros((H // 4, W // 4, 3), np.float32)
        swing = np.sin(np.pi * (cnt + ph) / 4)
        for k, ((x0, y0), col) in enumerate(zip(self.heads, self.hcol)):
            side = -1 if x0 < W / 2 else 1
            ang = side * (.25 + .30 * swing * (1 if k % 2 else -1)) + .15 * np.sin(t * .4 + k)
            dx, dy = np.sin(ang), np.cos(ang)
            X, Y = self.qx - x0, self.qy - y0
            along = X * dx + Y * dy
            across = np.abs(X * dy - Y * dx)
            b = np.clip(1 - across / (6 + along * .07), 0, 1) ** 2 * (along > 0) * np.exp(-along / 900)
            out += b[..., None] * col
        return cv2.resize(out, (W, H), interpolation=cv2.INTER_LINEAR) * (.10 + .14 * pulse)

    def frame(self, t, ph, cnt, kick, pulse, energy, vocal):
        img = self.base.copy()
        # LED: dải màu chạy ngang, sáng theo nhịp
        hue = (self.u * 1.5 + t * .05) % 1
        led = np.dstack([.5 + .5 * np.cos(6.283 * (hue + 0)), .5 + .5 * np.cos(6.283 * (hue + .33)),
                         .5 + .5 * np.cos(6.283 * (hue + .66))]).astype(np.float32)
        wave = .35 + .65 * (.5 + .5 * np.sin(self.u * 12 - t * 2.5 + self.v * 6))
        img += self.dots[..., None] * led * wave[..., None] * (.10 + .10 * energy + .08 * kick)
        img += self.beams(t, cnt, ph, pulse)
        warm = np.array([1, .85, .62], np.float32)
        spot = .7 + .2 * energy + .25 * kick
        img += self.cone * warm * .13 * spot
        img = img * (1 - self.floor * .4) + self.floor * np.array([.03, .03, .04], np.float32)
        img += self.pool * warm * (.25 + .15 * kick)

        # nhân vật
        bob = 7 * (1 - np.cos(2 * np.pi * ph)) / 2 * (.5 + .5 * energy)
        sway = 1.6 * np.sin(np.pi * (cnt + ph)) * (.6 + .4 * energy)
        head = 3.0 * np.sin(np.pi * (cnt + ph) + .6) + 2.0 * vocal * np.sin(t * 1.7)
        nod = 3.0 * np.sin(2 * np.pi * ph + .4) * (.4 + .6 * energy)
        breath = .012 * (.5 + .5 * np.sin(t * 2.1))
        c = self.char.render(head, nod, 4.0 * vocal, breath)
        chh, chw = c.shape[:2]; offy = (chh - self.char.h) / 2
        Mx = cv2.getRotationMatrix2D((chw / 2, offy + self.char.h * .8), sway, 1.0)
        Mx[0, 2] += W / 2 - chw / 2; Mx[1, 2] += CTOP - offy + bob
        cw = cv2.warpAffine(c, Mx, (W, H), flags=cv2.INTER_LINEAR, borderValue=0)
        a = cw[..., 3:4]
        rim = cv2.GaussianBlur(a, (0, 0), 3)[..., None] - a if a.ndim == 2 else cv2.GaussianBlur(a[..., 0], (0, 0), 3)[..., None] - a
        lit = cw[..., :3][..., ::-1] * (.85 + .25 * spot * self.cone)
        img = img * (1 - a) + lit * a
        img += np.clip(rim, 0, 1) * warm * (.12 + .12 * kick)   # viền sáng ngược sáng

        # micro cầm/đứng trước miệng
        canvas = (np.clip(img, 0, 1) * 255).astype(np.uint8)
        mx, my = self.char.mouth
        mx += (chw - self.char.w) / 2; my += offy
        p = Mx @ np.array([mx + 30, my + 44, 1.0])
        px, py = int(p[0]), int(p[1])
        if not NO_STAND:
            bx = int(W / 2 + 120)
            cv2.line(canvas, (bx, 668), (bx, 360), (26, 26, 30), 6, cv2.LINE_AA)
            cv2.line(canvas, (bx, 360), (px + 12, py + 22), (36, 36, 40), 5, cv2.LINE_AA)
            for d in (-45, 0, 45): cv2.line(canvas, (bx, 655), (bx + d, 675), (22, 22, 25), 6, cv2.LINE_AA)
            cv2.ellipse(canvas, (px + 5, py + 11), (9, 22), -30, 0, 360, (30, 30, 35), -1, cv2.LINE_AA)
            cv2.ellipse(canvas, (px, py), (15, 19), -30, 0, 360, (90, 90, 98), -1, cv2.LINE_AA)
            cv2.ellipse(canvas, (px - 3, py - 4), (7, 8), -30, 0, 360, (210, 200, 185), -1, cv2.LINE_AA)
        img = canvas.astype(np.float32) / 255

        off = int(t * 18) % W
        img += (self.fog[:, off:off + W] * self.fogmask)[..., None] * np.array([.22, .2, .24], np.float32) * (.6 + .4 * energy)
        # khán giả nhún theo beat + đèn điện thoại
        lift = int(5 * (1 - np.cos(2 * np.pi * ph)) / 2 * energy)
        aud = self.aud[20 + lift:20 + lift + H]
        img = img * (1 - aud[..., None] * .96) + aud[..., None] * np.array([.01, .01, .015], np.float32)
        canvas = (np.clip(img, 0, 1) * 255).astype(np.uint8)
        for x, y, p in self.phones:
            bri = int(150 + 100 * (.5 + .5 * np.sin(t * 1.3 + p)))
            xx = int(x + 10 * np.sin(np.pi * (cnt + ph) / 2 + p))
            cv2.circle(canvas, (xx, int(y)), 3, (bri, bri, int(bri * .9)), -1, cv2.LINE_AA)
            cv2.circle(canvas, (xx, int(y)), 9, (bri // 6,) * 3, 1, cv2.LINE_AA)
        return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", default=os.path.join(HERE, "cuoi_voi_doi.m4a"))
    ap.add_argument("--lyrics", default=os.path.join(HERE, "LOI_BAI_HAT.txt"))
    ap.add_argument("--timing", default=os.path.join(HERE, "moc_gio_khop.lrc"))
    ap.add_argument("--char", default=os.path.join(HERE, "nhan_vat.png"))
    ap.add_argument("--start", type=float, default=0)
    ap.add_argument("--duration", type=float, default=None)
    ap.add_argument("-o", "--out", default=os.path.join(HERE, "cuoi_voi_doi_concert.mp4"))
    a = ap.parse_args()

    y, sr = load_audio(a.audio)
    total = len(y) / sr
    t0 = a.start; dur = min(a.duration or total - t0, total - t0)
    n_all = int((t0 + dur) * FPS)
    A = mv.analyze(a.audio, n_all)
    tempo, phase, count = beat_info(y, sr, n_all)
    voc = np.load(os.path.join(HERE, "giong_hat_30fps.npy"))
    voc = np.pad(voc, (0, max(0, n_all - len(voc))))[:n_all]
    lines = mv.attach_sections(mv.read_timing(a.timing), a.lyrics)
    ass = os.path.splitext(a.out)[0] + ".ass"
    mv.write_ass(lines, ass, t0 + dur, y_sing=930, y_next=1012, y_title=150, sing_size=68)

    cut = a.duration is not None and t0 + dur < total
    vf = (f"scale=1920:1080:flags=lanczos,setpts=PTS+{t0}/TB,ass='{ass}':fontsdir='{mv.FONTS}',"
          f"setpts=PTS-STARTPTS,fade=t=in:st=0:d=0.8")
    af = "afade=t=in:st=0:d=0.5" if t0 else "anull"
    if cut or t0:
        vf += f",fade=t=out:st={dur - 1}:d=1"; af += f",afade=t=out:st={dur - 1}:d=1"
    cmd = ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
           "-i", "-", "-ss", f"{t0:.3f}", "-t", f"{dur:.3f}", "-i", a.audio, "-vf", vf, "-af", af,
           "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest", a.out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    st = Concert(Character(a.char))
    f0 = int(t0 * FPS)
    for f in range(f0, f0 + int(dur * FPS)):
        p.stdin.write(st.frame(f / FPS, phase[f], count[f], A["kick"][f], A["pulse"][f], A["energy"][f], voc[f]).tobytes())
        if (f - f0) % (FPS * 10) == 0: print(f"  {(f - f0) / FPS:5.0f}s / {dur:.0f}s", file=sys.stderr)
    p.stdin.close(); p.wait()
    if p.returncode: sys.exit("ffmpeg lỗi")
    print("Xong:", a.out)


if __name__ == "__main__":
    main()
