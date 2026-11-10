#!/usr/bin/env bash
# Đọc bài giảng (file .txt tiếng Việt) thành file .mp3 bằng giọng Piper vi_VN-vais1000.
# Cách dùng: doc-bai-giang.sh <bai-giang.txt> <ket-qua.mp3>
# Biến tuỳ chọn: TOC_DO (mặc định 1.12; lớn hơn = chậm hơn), NGAT_CAU (giây nghỉ giữa câu, mặc định 0.6)
set -euo pipefail
IN="${1:?Thiếu file văn bản .txt}"; OUT="${2:?Thiếu tên file .mp3}"
VOICE_DIR="${VOICE_DIR:-$HOME/.cache/giao-vien-lop-4}"
VOICE="vi_VN-vais1000-medium"
TOC_DO="${TOC_DO:-1.12}"; NGAT_CAU="${NGAT_CAU:-0.6}"

python3 -c "import piper" 2>/dev/null || pip install -q piper-tts
command -v ffmpeg >/dev/null || { echo "Cần cài ffmpeg"; exit 1; }
mkdir -p "$VOICE_DIR"
for ext in onnx onnx.json; do
  [ -s "$VOICE_DIR/$VOICE.$ext" ] || curl -sSfL -o "$VOICE_DIR/$VOICE.$ext" \
    "https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/$VOICE.$ext"
done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# Bỏ dòng trống thừa; mỗi dòng là một câu/nhịp đọc.
grep -v '^[[:space:]]*$' "$IN" > "$TMP/in.txt"
python3 -m piper -m "$VOICE_DIR/$VOICE.onnx" -f "$TMP/out.wav" \
  --length-scale "$TOC_DO" --noise-scale 0.7 --noise-w-scale 0.9 \
  --sentence-silence "$NGAT_CAU" < "$TMP/in.txt" 2>/dev/null
# Làm ấm giọng nhẹ, chuẩn hoá âm lượng, thêm 0.5 giây lặng ở đầu.
ffmpeg -y -loglevel error -i "$TMP/out.wav" \
  -af "adelay=500,highpass=f=70,lowpass=f=9000,equalizer=f=220:t=q:w=1:g=2,loudnorm=I=-16:TP=-1.5" \
  -ar 22050 -b:a 96k "$OUT"
echo "Đã tạo: $OUT"
