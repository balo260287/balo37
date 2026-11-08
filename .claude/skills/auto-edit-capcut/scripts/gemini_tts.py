"""Generate the voiceover with Google Gemini TTS (one WAV per scene), as an alternative to Higgsfield.

usage:
  python3 gemini_tts.py --check
  python3 gemini_tts.py --list-models
  python3 gemini_tts.py --sample "Some corners of the bay are best reached by paddle." --voice Sulafat --out work/<slug>/vo/sample.wav
  python3 gemini_tts.py --script work/<slug>/script.json --dir work/<slug>/vo [--voice Sulafat] [--model auto] [--rpm 3]
then continue exactly as with Higgsfield clips:
  python3 stitch_vo.py --script work/<slug>/script.json --clips work/<slug>/vo/scene01.wav ... --out work/<slug>/vo/voiceover.wav

The API key is read ONLY from the environment variable GEMINI_API_KEY (or GOOGLE_API_KEY). Never pass it on the
command line and never paste it into the chat: set it once in your shell profile (see references/setup.md).

Lessons from real runs:
- Send ONLY the words to be spoken. Style instructions placed in the text ("Read warmly: ...") are read aloud, and
  the TTS models reject system instructions. Pick the voice for the style instead (warm narrators: Sulafat,
  Achird, Vindemiatrix; deeper male: Charon, Algenib; bright: Puck, Aoede).
- Free tier allows about 3 TTS requests per minute. --rpm spaces the calls and 429 errors are retried after the
  delay the API asks for. Long videos: enable billing or keep scenes long (one request per scene).
- Responses come back as a full WAV file (audio/wav) or raw 16-bit PCM (audio/L16;rate=24000); both are handled.
"""
import argparse
import io
import json
import os
import re
import sys
import time
import wave
from pathlib import Path

VOICES = ["Zephyr", "Puck", "Charon", "Kore", "Fenrir", "Leda", "Orus", "Aoede", "Callirrhoe", "Autonoe", "Enceladus",
          "Iapetus", "Umbriel", "Algieba", "Despina", "Erinome", "Algenib", "Rasalgethi", "Laomedeia", "Achernar",
          "Alnilam", "Schedar", "Gacrux", "Pulcherrima", "Achird", "Zubenelgenubi", "Vindemiatrix", "Sadachbia",
          "Sadaltager", "Sulafat"]


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def client():
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        die("GEMINI_API_KEY is not set. Put it in your shell profile (references/setup.md, 'Gemini TTS'), "
            "open a new terminal / restart Claude, then run again. Do not paste the key into the chat.")
    try:
        from google import genai
    except ImportError:
        import subprocess
        for extra in ([], ["--break-system-packages"]):
            if subprocess.run([sys.executable, "-m", "pip", "install", "-q", "google-genai", *extra]).returncode == 0:
                break
        from google import genai
    return genai.Client(api_key=key)


def tts_models(c):
    names = [m.name.split("/")[-1] for m in c.models.list() if "tts" in m.name.lower()]

    def rank(n):  # newest version first, non-preview before preview, flash before pro (faster, cheaper)
        v = [int(x) for x in re.findall(r"\d+", n)[:2]] + [0, 0]
        return (-v[0], -v[1], "preview" in n, "pro" in n, "lite" in n)
    return sorted(names, key=rank)


def pick_model(c, want):
    if want and want != "auto":
        return want
    ms = tts_models(c)
    if not ms:
        die("No TTS model is available for this key.")
    return ms[0]


def to_wav_bytes(data, mime):
    if data[:4] == b"RIFF":
        return data
    rate = int((re.search(r"rate=(\d+)", mime or "") or [None, 24000])[1])
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(data)
    return buf.getvalue()


def speak(c, model, voice, text, rpm_state):
    from google.genai import types, errors
    cfg = types.GenerateContentConfig(
        response_modalities=["AUDIO"],
        speech_config=types.SpeechConfig(voice_config=types.VoiceConfig(
            prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=voice))))
    for attempt in range(6):
        wait = rpm_state["next"] - time.time()
        if wait > 0:
            time.sleep(wait)
        rpm_state["next"] = time.time() + rpm_state["gap"]
        try:
            r = c.models.generate_content(model=model, contents=text, config=cfg)
            d = r.candidates[0].content.parts[0].inline_data
            return to_wav_bytes(d.data, d.mime_type)
        except errors.ClientError as e:
            if e.code != 429:
                raise
            m = re.search(r"retry in ([\d.]+)s", str(e))
            delay = float(m.group(1)) + 2 if m else 35
            print(f"  rate limit, waiting {delay:.0f} s ...")
            time.sleep(delay)
    die("Still rate-limited after several retries. Try again in a minute, lower --rpm, or enable billing.")


def duration(path):
    with wave.open(str(path)) as w:
        return w.getnframes() / w.getframerate()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="check the key, the SDK and list the TTS models")
    ap.add_argument("--list-models", action="store_true")
    ap.add_argument("--list-voices", action="store_true")
    ap.add_argument("--sample", help="speak one line to --out (to audition a voice)")
    ap.add_argument("--script", help="script.json with scenes[].text")
    ap.add_argument("--dir", help="output folder for sceneNN.wav")
    ap.add_argument("--out", help="output file for --sample")
    ap.add_argument("--voice", default="Sulafat")
    ap.add_argument("--model", default="auto")
    ap.add_argument("--rpm", type=float, default=3, help="max requests per minute (free tier: 3)")
    a = ap.parse_args()

    if a.list_voices:
        print("\n".join(VOICES)); return
    if a.voice not in VOICES:
        print(f"note: '{a.voice}' is not in the known voice list; the API will reject it if it does not exist.")
    c = client()
    if a.check or a.list_models:
        ms = tts_models(c)
        print("key: ok · google-genai: ok")
        print("TTS models (best first):", ", ".join(ms) or "none")
        return
    model = pick_model(c, a.model)
    state = {"next": 0.0, "gap": 60.0 / max(a.rpm, 0.1)}
    if a.sample:
        out = Path(a.out or "sample.wav"); out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(speak(c, model, a.voice, a.sample, state))
        print(f"{out} · {duration(out):.2f} s · model {model} · voice {a.voice}")
        return
    if not (a.script and a.dir):
        die("give --script and --dir (or --sample / --check)")
    sc = json.loads(Path(a.script).read_text(encoding="utf-8"))
    out_dir = Path(a.dir); out_dir.mkdir(parents=True, exist_ok=True)
    files = []
    print(f"model {model} · voice {a.voice} · {len(sc['scenes'])} scenes")
    for s in sc["scenes"]:
        n = int(s["n"]); text = s["text"].strip()
        if re.search(r"[\[\]{}<>]|^\s*(read|say|speak)\b.*:", text, re.I):
            print(f"  warning scene {n}: brackets or a spoken instruction in the text will be read aloud")
        f = out_dir / f"scene{n:02d}.wav"
        f.write_bytes(speak(c, model, a.voice, text, state))
        files.append(str(f))
        words = len(text.split())
        d = duration(f)
        print(f"  scene {n:02d}: {d:5.2f} s · {words} words · {words / d * 60:.0f} wpm")
    (out_dir / "gemini_tts.json").write_text(json.dumps({"model": model, "voice": a.voice, "clips": files}, indent=1))
    print("\nnext:\n  python3 scripts/stitch_vo.py --script " + a.script + " --clips " + " ".join(files) +
          " --out " + str(out_dir / "voiceover.wav") + " --target-seconds <seconds>")


if __name__ == "__main__":
    main()
