#!/usr/bin/env python3
"""Bien anh (va doan video AI) thanh video ngan co phu de, giong doc, nhac nen, hieu ung.

Dung:  python3 make_video.py --plan plan.json --out video.mp4 [--no-voice] [--check]

plan.json (xem examples/plan-mau.json):
{
  "canvas": "9:16",                      # "9:16" (TikTok) | "16:9" (YouTube) | "1:1"
  "speakers": {"ke": 1.0, "anh": 1.22, "em": 1.5},   # he so cao do giong (1.0 = giong goc)
  "music": "auto",                       # "auto" (tu tao nhac vui) | duong dan file nhac | null
  "sfx": true,
  "caption_y": 0.68,                     # vi tri phu de (0 = tren cung, 1 = duoi cung)
  "shots": [
    {"image": "anh.jpg", "focus": [790, 1000], "zoom": [1.0, 1.1], "dur": 3.0,
     "label": "", "caption": "Chu hien tren man hinh", "speaker": "ke", "say": "Cau doc thanh tieng",
     "punch": false},
    {"video": "clip_ai.mp4", "dur": 5.0, "caption": "...", "speaker": "em", "say": "..."}
  ]
}
- focus: toa do diem can zoom vao (pixel tren anh goc). Bo trong = giua anh.
- dur: thoi luong toi thieu; tu dai them neu cau doc dai hon.
- punch: true = hieu ung "boing" cho cau chot hai.
"""
import argparse, json, os, subprocess, sys, textwrap, urllib.request, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, '..', 'assets', 'fonts', 'BeVietnamPro-Bold.ttf')
SR, FPS = 44100, 30
CANVAS = {'9:16': (1080, 1920), '16:9': (1920, 1080), '1:1': (1080, 1080)}
CACHE = os.path.expanduser('~/.cache/anh-thanh-video')
VOICE_NAME = 'vi_VN-vais1000-medium'
VOICE_URL = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/'


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def die(msg):
    sys.exit('LOI: ' + msg)


# ---------------------------------------------------------------- giong doc
def voice_model():
    """Tai mo hinh giong tieng Viet (Piper, mien phi) lan dau, sau do dung lai."""
    os.makedirs(CACHE, exist_ok=True)
    onnx = os.path.join(CACHE, VOICE_NAME + '.onnx')
    for ext in ('.onnx', '.onnx.json'):
        p = os.path.join(CACHE, VOICE_NAME + ext)
        if not os.path.exists(p) or os.path.getsize(p) < 1000:
            print(f'  tai giong doc {VOICE_NAME}{ext} ...')
            urllib.request.urlretrieve(VOICE_URL + VOICE_NAME + ext, p)
    return onnx


def ensure_piper():
    try:
        import piper  # noqa: F401
    except ImportError:
        extra = ['--break-system-packages'] if sys.version_info >= (3, 11) else []
        run([sys.executable, '-m', 'pip', 'install', '-q', 'piper-tts', *extra])


def load_audio(path):
    r = run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
            capture_output=True)
    return np.frombuffer(r.stdout, np.float32).copy()


def tts(text, pitch, tmp, model):
    raw, out = tmp + '_raw.wav', tmp + '.wav'
    run([sys.executable, '-m', 'piper', '-m', model, '-f', raw, '--length-scale', '0.95'],
        input=text.encode('utf-8'), capture_output=True)
    if pitch != 1.0:   # tang cao do nhung giu toc do -> giong tre con
        af = f'asetrate={int(22050 * pitch)},aresample={SR},atempo={min(2.0, max(0.5, 1.08 / pitch)):.4f}'
    else:
        af = f'aresample={SR}'
    run(['ffmpeg', '-v', 'error', '-y', '-i', raw, '-af', af + ',loudnorm=I=-16:TP=-1.5',
         '-ar', str(SR), '-ac', '1', out])
    return load_audio(out)


# ---------------------------------------------------------------- nhac & hieu ung
def pluck(freq, dur, amp):
    n, p = int(dur * SR), int(SR / freq)
    buf, out = np.random.uniform(-1, 1, p), np.zeros(int(dur * SR))
    for k in range(n):
        out[k] = buf[k % p]
        buf[k % p] = 0.996 * 0.5 * (buf[k % p] + buf[(k + 1) % p])
    return out * amp


def auto_music(total):
    notes = {'C': 261.6, 'D': 293.7, 'E': 329.6, 'F': 349.2, 'G': 392.0, 'A': 440.0, 'c': 523.3}
    mel = 'C E G E F A c A G E C E D G D G'.split()
    N, music, pos, k = int(total * SR), np.zeros(int(total * SR)), 0.0, 0
    cache = {}
    while pos < total:
        n = mel[k % len(mel)]
        x = cache.setdefault(n, pluck(notes[n], 0.5, 0.3))
        s = int(pos * SR); e = min(N, s + len(x)); music[s:e] += x[:e - s]
        if k % 4 == 0:
            y = cache.setdefault(n + 'b', pluck(notes[n] / 2, 0.9, 0.35))
            e = min(N, s + len(y)); music[s:e] += y[:e - s]
        pos += 0.25; k += 1
    return music / (np.abs(music).max() + 1e-9)


def sweep(f0, f1, dur, amp):
    n = int(dur * SR); t = np.arange(n) / SR
    ph = 2 * np.pi * np.cumsum(np.linspace(f0, f1, n)) / SR
    return amp * np.sin(ph) * np.exp(-t * 6 / dur)


# ---------------------------------------------------------------- hinh
def caption_file(shot, i, work, W):
    width = 24 if W < 1500 else 40
    body = '\n'.join(textwrap.wrap(shot.get('caption', ''), width))
    txt = ((shot['label'] + '\n') if shot.get('label') else '') + body
    if not txt.strip():
        return None
    p = os.path.join(work, f'cap{i}.txt')
    open(p, 'w', encoding='utf-8').write(txt)
    return p


def drawtext(capf, cy, W):
    if not capf:
        return ''
    fs = 64 if W < 1500 else 56
    return (f",drawtext=fontfile='{FONT}':textfile='{capf}':fontsize={fs}:fontcolor=white:borderw=5"
            f":bordercolor=black:line_spacing=20:text_align=C:x=(w-text_w)/2:y=h*{cy}"
            f":box=1:boxcolor=black@0.45:boxborderw=28")


def image_size(path):
    r = run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height',
             '-of', 'csv=p=0', path], capture_output=True, text=True)
    w, h = r.stdout.strip().split(',')[:2]
    return int(w), int(h)


def render_image_shot(shot, dur, out, W, H, capf, cy):
    iw, ih = image_size(shot['image'])
    A = W / H
    fx, fy = shot.get('focus') or [iw / 2, ih / 2]
    if iw / ih > A:                        # anh rong hon khung -> cat ngang quanh tieu diem
        cw, ch = int(ih * A) // 2 * 2, ih
        cx, cy0 = int(min(max(fx - cw / 2, 0), iw - cw)), 0
    else:                                  # anh cao hon khung -> cat doc quanh tieu diem
        cw, ch = iw, int(iw / A) // 2 * 2
        cx, cy0 = 0, int(min(max(fy - ch / 2, 0), ih - ch))
    ffx, ffy = (fx - cx) * 2, (fy - cy0) * 2
    z0, z1 = shot.get('zoom', [1.0, 1.15])
    n = int(round(dur * FPS))
    z = f'{z0}+({z1}-{z0})*on/{max(n - 1, 1)}'
    vf = (f'crop={cw}:{ch}:{cx}:{cy0},scale={cw * 2}:{ch * 2},'
          f"zoompan=z='{z}':x='max(0,min(iw-iw/zoom,{ffx}-iw/zoom/2))'"
          f":y='max(0,min(ih-ih/zoom,{ffy}-ih/zoom/2))':d={n}:s={W}x{H}:fps={FPS}"
          + drawtext(capf, cy, W) + ',format=yuv420p')
    run(['ffmpeg', '-v', 'error', '-y', '-i', shot['image'], '-vf', vf, '-frames:v', str(n),
         '-c:v', 'libx264', '-crf', '18', '-r', str(FPS), out])


def render_video_shot(shot, dur, out, W, H, capf, cy):
    vf = (f'scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},fps={FPS},'
          f'tpad=stop_mode=clone:stop_duration={dur}' + drawtext(capf, cy, W) + ',format=yuv420p')
    run(['ffmpeg', '-v', 'error', '-y', '-i', shot['video'], '-vf', vf, '-t', f'{dur:.3f}', '-an',
         '-c:v', 'libx264', '-crf', '18', '-r', str(FPS), out])


# ---------------------------------------------------------------- chinh
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--plan', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--no-voice', action='store_true', help='chi phu de, khong doc')
    ap.add_argument('--check', action='store_true', help='kiem tra plan va cong cu roi dung')
    a = ap.parse_args()

    plan = json.load(open(a.plan, encoding='utf-8'))
    base = os.path.dirname(os.path.abspath(a.plan))
    W, H = CANVAS.get(plan.get('canvas', '9:16'), CANVAS['9:16'])
    shots = plan.get('shots') or die('plan khong co "shots"')
    for i, s in enumerate(shots):
        key = 'image' if 'image' in s else 'video' if 'video' in s else die(f'canh {i} thieu "image" hoac "video"')
        s[key] = os.path.join(base, s[key]) if not os.path.isabs(s[key]) else s[key]
        if not os.path.exists(s[key]):
            die(f'canh {i}: khong thay file {s[key]}')
    if not os.path.exists(FONT):
        die('thieu font ' + FONT)
    try:
        run(['ffmpeg', '-version'], capture_output=True)
    except Exception:
        die('can cai ffmpeg')
    if a.check:
        print(f'OK: {len(shots)} canh, khung {W}x{H}'); return

    work = os.path.splitext(os.path.abspath(a.out))[0] + '_work'
    os.makedirs(work, exist_ok=True)
    spk = plan.get('speakers', {})

    # 1. giong doc
    clips = [None] * len(shots)
    if not a.no_voice and any(s.get('say') for s in shots):
        try:
            ensure_piper(); model = voice_model()
            for i, s in enumerate(shots):
                if s.get('say'):
                    clips[i] = tts(s['say'], float(spk.get(s.get('speaker', ''), 1.0)), os.path.join(work, f'v{i}'), model)
            print('  giong doc: xong')
        except Exception as e:
            print(f'  CANH BAO: khong tao duoc giong doc ({e}). Video chi co phu de.')
            clips = [None] * len(shots)

    # 2. thoi luong canh
    durs = []
    for s, c in zip(shots, clips):
        d = float(s.get('dur', 2.8))
        if c is not None:
            d = max(d, len(c) / SR + 0.7)
        durs.append(round(d, 2))
    durs[-1] += 0.8
    total = sum(durs); N = int(total * SR)

    # 3. hinh tung canh
    cy = float(plan.get('caption_y', 0.68))
    parts = []
    for i, (s, d) in enumerate(zip(shots, durs)):
        out = os.path.join(work, f'shot{i}.mp4')
        capf = caption_file(s, i, work, W)
        (render_image_shot if 'image' in s else render_video_shot)(s, d, out, W, H, capf, cy)
        parts.append(out)
        print(f'  canh {i + 1}/{len(shots)}: {d:.1f}s')

    # 4. tron am thanh
    voice = np.zeros(N, np.float32); starts, t = [], 0.0
    for d, c in zip(durs, clips):
        starts.append(t)
        if c is not None:
            s0 = int((t + 0.25) * SR); voice[s0:s0 + len(c)] += c[:max(0, N - s0)]
        t += d
    mix = voice * 0.9
    m = plan.get('music', 'auto')
    if m:
        music = auto_music(total) if m == 'auto' else np.resize(load_audio(os.path.join(base, m)), N)
        music = music / (np.abs(music).max() + 1e-9)
        env = np.convolve((np.abs(voice) > 0.02).astype(float), np.ones(4410) / 4410, 'same')
        mix = mix + music * 0.16 * (1 - 0.6 * np.clip(env * 3, 0, 1))
    if plan.get('sfx', True):
        for s, st in zip(shots, starts):
            if s.get('punch'):
                n = int(0.45 * SR)
                x = sweep(180, 520, 0.45, 0.35) * np.sin(2 * np.pi * 12 * np.arange(n) / SR) ** 2
            else:
                x = sweep(900, 300, 0.12, 0.25)
            a0 = int(st * SR); e = min(N, a0 + len(x)); mix[a0:e] += x[:e - a0]
    mix = mix / max(1.0, np.abs(mix).max() / 0.95)
    wav = os.path.join(work, 'mix.wav')
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.repeat(mix[:, None], 2, 1) * 32767).astype(np.int16).tobytes())

    # 5. ghep
    lst = os.path.join(work, 'list.txt')
    open(lst, 'w').write(''.join(f"file '{p}'\n" for p in parts))
    run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', lst, '-i', wav, '-shortest',
         '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', a.out])
    print(f'XONG: {a.out} ({total:.1f} giay, {W}x{H})')


if __name__ == '__main__':
    main()
