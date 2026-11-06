# Yêu cầu: video nhân vật hát trên sân khấu

Người dùng không rành máy tính: giải thích bằng tiếng Việt, ngắn gọn, từng bước, hỏi trước khi cài đặt.

## Mục tiêu
Lyric video 16:9 cho bài "Cười Với Đời Hết Hơi": nhân vật trong ảnh hát nhép theo bài, chuyển động tự nhiên
(đầu, mặt, vai), đứng trên sân khấu như thật có đèn chiếu; chữ lời tiếng Việt chạy khớp giọng hát.
Xuất bản nháp 30 giây (0:18–0:48) để duyệt trước, duyệt xong mới làm cả bài (3:59).

## Dữ liệu (thư mục lyric-video/cuoi-voi-doi/)
- cuoi_voi_doi.m4a: nhạc có giọng hát
- moc_gio_khop.lrc: mốc giờ từng chữ, canh theo giọng hát đã tách
- nhan_vat.png: nhân vật đã tách nền; nhan_vat_goc.jpg: ảnh gốc
- make_video.py: hàm đọc LRC và viết phụ đề ASS karaoke (font trong lyric-video/fonts/)
- make_stage_video.py: bản 2D cũ (chỉ lắc lư), người dùng chê, cần chuyển động thật

## Máy
Windows, card RTX 3060 12GB (kiểm tra bằng nvidia-smi), RAM khoảng 8GB. Nhắc tắt Chrome, Zalo, MT5 khi chạy.

## Cách làm gợi ý
1. Kiểm tra GPU, RAM, ổ đĩa, Python, ffmpeg.
2. Dùng công cụ hát nhép từ ảnh + âm thanh chạy được trên 12GB VRAM: EchoMimic, Hallo hoặc Sonic.
   Tách giọng hát trước cho môi khớp hơn. Làm từng đoạn ngắn cho vừa RAM.
3. Đặt nhân vật lên sân khấu (đèn chiếu, khói), 16:9, phủ phụ đề karaoke từ moc_gio_khop.lrc bằng ffmpeg + libass.
4. Xuất ban_nhap_30s.mp4 và báo người dùng đường dẫn file.

Lưu ý: ảnh là Superman (thương hiệu DC); đăng công khai có thể bị gắn cờ bản quyền.
