"""Bản concert có khung xương 2D: tách 2 tay khỏi thân. Tay phải (phía phải màn hình) đưa lên
cầm mic sát miệng, tay trái đánh nhịp/vẫy theo beat, thân uốn éo, đầu gật, miệng mấp máy.
Ảnh gốc không có chân (phần dưới tan vào khói) nên không có chân.

Chạy:  python3 make_dance_video.py --start 18 --duration 30 -o ban_nhap_nhay_30s.mp4
"""
import argparse, os, subprocess, sys
import numpy as np, cv2
import make_video as mv
import make_concert_video as mc
from make_stage_video import load_audio, beat_info

HERE = os.path.dirname(os.path.abspath(__file__))
# khớp xương trên ảnh gốc 1264x1590
R_SH, R_EL, R_FI = (930, 470), (1000, 820), (1040, 1140)
L_SH, L_EL, L_FI = (335, 470), (275, 820), (230, 1100)
R_UP = [(1015, 395), (885, 420), (850, 520), (862, 700), (875, 880), (1095, 880), (1060, 700), (1040, 560)]
R_LO = [(870, 760), (1095, 760), (1110, 980), (1110, 1230), (975, 1230), (935, 1000)]
L_UP = [(250, 395), (380, 420), (415, 520), (402, 700), (390, 880), (170, 880), (205, 700), (225, 560)]
L_LO = [(395, 760), (170, 760), (150, 980), (150, 1180), (290, 1180), (330, 1000)]
MIC_TARGET = (700, 400)   # vị trí nắm tay khi cầm mic (mic chĩa lên miệng)


def ang(v): return np.arctan2(v[1], v[0])


def affine(theta, p, pn):
    c, s = np.cos(theta), np.sin(theta)
    R = np.array([[c, -s], [s, c]])
    t = np.array(pn) - R @ np.array(p)
    return np.hstack([R, t[:, None]]).astype(np.float32)


def ik(S, T, L1, L2, bend=1):
    S, T = np.array(S, float), np.array(T, float)
    d = np.clip(np.linalg.norm(T - S), 1, L1 + L2 - 1)
    a = np.arccos(np.clip((L1 ** 2 + d ** 2 - L2 ** 2) / (2 * L1 * d), -1, 1))
    base = ang(T - S)
    e_ang = base + bend * a
    return S + L1 * np.array([np.cos(e_ang), np.sin(e_ang)])


class Rig(mc.Character):
    def __init__(self, path):
        super().__init__(path)
        s = self.s
        h, w = self.h, self.w
        self.pad = pad = 120
        sc = lambda p: (p[0] * s + pad, p[1] * s + pad)
        big = np.zeros((h + 2 * pad, w + 2 * pad, 4), np.float32)
        big[pad:pad + h, pad:pad + w] = self.img
        self.big = big
        def mask(poly):
            m = np.zeros(big.shape[:2], np.float32)
            cv2.fillPoly(m, [np.array([sc(p) for p in poly], np.int32)], 1.0)
            return cv2.GaussianBlur(m, (0, 0), 1.2)
        self.parts = {}
        arm_all = np.zeros(big.shape[:2], np.float32)
        for name, poly in (("r_up", R_UP), ("r_lo", R_LO), ("l_up", L_UP), ("l_lo", L_LO)):
            m = mask(poly); arm_all = np.maximum(arm_all, m)
            part = big.copy(); part[..., 3] *= m
            self.parts[name] = part
        # thân: bỏ tay, vá vùng tối phía sau bằng inpaint
        torso = big.copy()
        hole = (arm_all > .5) & (big[..., 3] > .3)
        rgb8 = (np.clip(torso[..., :3], 0, 1) * 255).astype(np.uint8)
        filled = cv2.inpaint(rgb8, hole.astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA).astype(np.float32) / 255
        torso[..., :3] = filled
        torso[..., 3] *= (1 - arm_all)
        self.torso_big = torso
        self.j = {k: np.array(sc(v)) for k, v in
                  dict(rs=R_SH, re=R_EL, rf=R_FI, ls=L_SH, le=L_EL, lf=L_FI, mic=MIC_TARGET).items()}
        self.Lr = (np.linalg.norm(self.j["re"] - self.j["rs"]), np.linalg.norm(self.j["rf"] - self.j["re"]))
        self.Ll = (np.linalg.norm(self.j["le"] - self.j["ls"]), np.linalg.norm(self.j["lf"] - self.j["le"]))
        H2, W2 = big.shape[:2]
        yy, xx = np.mgrid[0:H2, 0:W2].astype(np.float32)
        self.bxx, self.byy = xx, yy
        # trọng số đầu/hàm/ngực trên khung lớn
        ox = lambda a: np.pad(a, pad)
        self.bw_head, self.bw_jaw, self.bw_chest = ox(self.w_head), ox(self.w_jaw), ox(self.w_chest)
        self.bneck = (self.neck[0] + pad, self.neck[1] + pad)
        self.bmouth = (self.mouth[0] + pad, self.mouth[1] + pad)
        self.hip_y = h * .8 + pad
        self.pose = dict(shear=0, pump=0, wave=0, micbob=0)

    def render(self, head_ang, nod, jaw_open, breath):
        P = self.pose; pad = self.pad
        xx, yy = self.bxx, self.byy
        nx, ny = self.bneck
        a = -np.deg2rad(head_ang) * self.bw_head
        dx, dy = xx - nx, yy - ny
        sx = nx + dx * np.cos(a) - dy * np.sin(a)
        sy = ny + dx * np.sin(a) + dy * np.cos(a) - nod * self.bw_head
        sy = sy - jaw_open * self.bw_jaw
        cx = self.big.shape[1] / 2
        sx = cx + (sx - cx) / (1 + breath * self.bw_chest)
        sx = sx + P["shear"] * (self.hip_y - yy)          # uốn thân: trên lệch nhiều, hông đứng yên
        out = cv2.remap(self.torso_big, sx.astype(np.float32), sy.astype(np.float32), cv2.INTER_LINEAR,
                        borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        shift = lambda p: np.array([p[0] - P["shear"] * (self.hip_y - p[1]), p[1]])   # khớp vai theo thân

        def put(img, M):
            nonlocal out
            w = cv2.warpAffine(img, M, (out.shape[1], out.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)
            al = w[..., 3:4]
            out[..., :3] = out[..., :3] * (1 - al) + w[..., :3] * al
            out[..., 3:4] = np.maximum(out[..., 3:4], al)

        j = self.j
        # tay trái: đánh nhịp
        ls = shift(j["ls"])
        th_u = np.deg2rad(18 + 22 * P["pump"])
        Mu = affine(th_u, j["ls"], ls)
        le_new = Mu[:, :2] @ j["le"] + Mu[:, 2]
        th_l = th_u + np.deg2rad(-35 - 55 * P["wave"])
        put(self.parts["l_lo"], affine(th_l, j["le"], le_new))   # cẳng tay vẽ trước, bắp tay đè lên che khớp
        put(self.parts["l_up"], Mu)
        # tay phải: cầm mic sát miệng (IK)
        rs = shift(j["rs"])
        mouth_now = np.array(self.bmouth)
        T = j["mic"] + np.array([0, 6 * P["micbob"]]) + (shift(mouth_now) - mouth_now)
        E = ik(rs, T, *self.Lr, bend=-1)
        th1 = ang(E - rs) - ang(j["re"] - j["rs"])
        th2 = ang(T - E) - ang(j["rf"] - j["re"])
        put(self.parts["r_up"], affine(th1, j["rs"], rs))
        put(self.parts["r_lo"], affine(th2, j["re"], E))
        self.fist = T; self.fore_dir = (T - E) / (np.linalg.norm(T - E) + 1e-6)
        # mic trong nắm tay, chĩa về miệng
        canvas = out
        tip = T + (mouth_now + np.array([0, 10]) - T) * .78
        m = np.zeros(canvas.shape[:2], np.float32)
        cv2.line(m, tuple(T.astype(int)), tuple(tip.astype(int)), 1.0, 11, cv2.LINE_AA)
        body = cv2.GaussianBlur(m, (0, 0), .8)[..., None]
        canvas[..., :3] = canvas[..., :3] * (1 - body) + np.array([.10, .10, .12], np.float32) * body
        head = np.zeros(canvas.shape[:2], np.float32)
        cv2.circle(head, tuple(tip.astype(int)), 15, 1.0, -1, cv2.LINE_AA)
        hl = cv2.GaussianBlur(head, (0, 0), .8)[..., None]
        canvas[..., :3] = canvas[..., :3] * (1 - hl) + np.array([.55, .55, .6], np.float32) * hl
        canvas[..., 3:4] = np.maximum(canvas[..., 3:4], np.maximum(body, hl))
        return canvas


class DanceConcert(mc.Concert):
    def frame(self, t, ph, cnt, kick, pulse, energy, vocal):
        ch = self.char
        beat = np.pi * (cnt + ph)
        ch.pose = dict(shear=.035 * np.sin(beat) * (.5 + .5 * energy),
                       pump=.5 + .5 * np.sin(2 * np.pi * ph),
                       wave=.5 + .5 * np.sin(beat / 2),
                       micbob=np.sin(2 * np.pi * ph))
        return super().frame(t, ph, cnt, kick, pulse, energy, vocal)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", default=os.path.join(HERE, "cuoi_voi_doi.m4a"))
    ap.add_argument("--lyrics", default=os.path.join(HERE, "LOI_BAI_HAT.txt"))
    ap.add_argument("--timing", default=os.path.join(HERE, "moc_gio_khop.lrc"))
    ap.add_argument("--char", default=os.path.join(HERE, "nhan_vat.png"))
    ap.add_argument("--start", type=float, default=0)
    ap.add_argument("--duration", type=float, default=None)
    ap.add_argument("-o", "--out", default=os.path.join(HERE, "cuoi_voi_doi_nhay.mp4"))
    a = ap.parse_args()
    sys.argv = [sys.argv[0], "--audio", a.audio, "--lyrics", a.lyrics, "--timing", a.timing, "--char", a.char,
                "--start", str(a.start), "-o", a.out] + (["--duration", str(a.duration)] if a.duration else [])
    mc.Concert = DanceConcert
    mc.Character = Rig
    mc.NO_STAND = True
    mc.main()


if __name__ == "__main__":
    main()
