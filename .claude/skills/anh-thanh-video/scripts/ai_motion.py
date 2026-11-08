#!/usr/bin/env python3
"""Lam nguoi/vat trong anh CU DONG THAT - MIEN PHI, qua ung dung AI cong dong tren Hugging Face.

Mac dinh dung Wan 2.2 (image-to-video). Du phong: LTX-Video.
- Mien phi, khong can tai khoan, nhung CO GIOI HAN luot dung moi ngay (GPU dung chung).
- Anh se duoc GUI LEN may chu Hugging Face cua nguoi khac. Hoi nguoi dung truoc khi gui anh
  co nguoi that, nhat la tre em.
- Can cho phep mang toi: huggingface.co va <ten-space>.hf.space

Dung:
  python3 ai_motion.py --image anh.jpg --prompt "the boy eats cake, the girl smiles" --out clip.mp4 [--seconds 4]
Prompt nen viet bang TIENG ANH, mo ta cu dong nhe nhang, tu nhien.
Ket qua dua vao plan.json cua make_video.py: {"video": "clip.mp4", ...}
"""
import argparse, shutil, subprocess, sys

SPACES = [
    # (space, ham goi)
    'zerogpu-aoti/wan2-2-fp8da-aoti-faster',
    'Lightricks/ltx-video-distilled',
]
NEG = ('static, still image, blurry, low quality, distorted face, deformed hands, extra fingers, '
       'subtitles, text, watermark')


def ensure_client():
    try:
        import gradio_client  # noqa: F401
    except ImportError:
        extra = ['--break-system-packages'] if sys.version_info >= (3, 11) else []
        subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'gradio_client', *extra], check=True)


def call_wan(Client, handle_file, image, prompt, seconds):
    c = Client(SPACES[0], verbose=False)
    v, _ = c.predict(handle_file(image), prompt, 6, NEG, float(seconds), 1, 1, 42, True,
                     api_name='/generate_video')
    return v['video'] if isinstance(v, dict) else v


def call_ltx(Client, handle_file, image, prompt, seconds):
    c = Client(SPACES[1], verbose=False)
    # LTX co nhieu endpoint; tim cai nhan anh dau vao
    api = c.view_api(return_format='dict', print_info=False)
    names = list(api.get('named_endpoints', {}))
    ep = next((n for n in names if 'image' in n.lower()), None)
    if not ep:
        raise RuntimeError(f'khong thay endpoint image-to-video trong {names}')
    params = api['named_endpoints'][ep]['parameters']
    kw = {}
    for p in params:
        n = p['parameter_name']
        if 'image' in n and not any('image' in k for k in kw):
            kw[n] = handle_file(image)
        elif n == 'prompt':
            kw[n] = prompt
        elif 'negative' in n:
            kw[n] = NEG
        elif 'duration' in n:
            kw[n] = float(seconds)
    res = c.predict(api_name=ep, **kw)
    first = res[0] if isinstance(res, (list, tuple)) else res
    return first['video'] if isinstance(first, dict) else first


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--image', required=True)
    ap.add_argument('--prompt', required=True, help='mo ta cu dong, bang tieng Anh')
    ap.add_argument('--out', required=True)
    ap.add_argument('--seconds', type=float, default=4.0, help='do dai clip (2-5 giay)')
    a = ap.parse_args()

    ensure_client()
    from gradio_client import Client, handle_file
    errors = []
    for name, fn in (('Wan 2.2', call_wan), ('LTX-Video', call_ltx)):
        try:
            print(f'Dang tao video bang {name} (1-5 phut, tuy hang doi)...')
            path = fn(Client, handle_file, a.image, a.prompt, a.seconds)
            shutil.copy(path, a.out)
            print('XONG:', a.out)
            return
        except Exception as e:
            msg = str(e).splitlines()[0][:200]
            errors.append(f'{name}: {msg}')
            print('  that bai:', msg)
    print('\nLOI: ca 2 ung dung mien phi deu khong tao duoc video.')
    print('Ly do thuong gap: het luot mien phi trong ngay (ZeroGPU quota), hang doi day, '
          'hoac mang chua cho phep host *.hf.space.')
    print('Cach khac mien phi: app CapCut (muc "Anh thanh video AI") hoac app Gemini tren dien thoai.')
    sys.exit(1)


if __name__ == '__main__':
    main()
