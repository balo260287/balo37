# Lyric video – Sinh nhật anh Ủn 9 tuổi

- `ban_nhap_30s.mp4`: bản nháp 30 giây (1920×1080, 30fps, H.264 + AAC) để duyệt.
- `make_lyric_video.py`: script dựng video. Thời điểm từng chữ lấy theo giai điệu của beat
  (120 BPM, mỗi câu 4 giây); nền đập theo onset, độ to và phổ âm thanh (librosa).
- `fonts/`: Be Vietnam Pro (giấy phép SIL OFL), font thiết kế cho tiếng Việt.
- Nguồn: `sinh_nhat_anh_Un.mp3` và `LOI_BAI_HAT.md`, lấy từ branch `ccr-75c0b697-dphsox`.

Cần: ffmpeg (có libass), `pip install librosa pillow numpy`.

```
python3 make_lyric_video.py --duration 30 -o ban_nhap_30s.mp4   # bản nháp
python3 make_lyric_video.py -o lyric_video.mp4                  # cả bài (~1:39, mất ~7 phút)
```
