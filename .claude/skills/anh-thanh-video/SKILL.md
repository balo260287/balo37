---
name: anh-thanh-video
description: Biến ảnh thành video ngắn vui nhộn (TikTok 9:16, YouTube 16:9) có phụ đề tiếng Việt, giọng đọc, nhạc nền, hiệu ứng, và tuỳ chọn làm người trong ảnh cử động thật bằng AI miễn phí. Dùng mỗi khi người dùng gửi ảnh và nói "làm video", "biến ảnh thành video", "cho ảnh chuyển động", "lồng tiếng hài hước", "làm clip TikTok từ ảnh", kể cả khi họ không nhắc tên skill này.
---

# Ảnh thành video

## Nó giúp gì
Một hoặc vài tấm ảnh → video ngắn hoàn chỉnh (zoom/lia camera, lời thoại hài, giọng đọc, nhạc, hiệu ứng), và nếu muốn thì người trong ảnh cử động thật, tất cả MIỄN PHÍ.

## Hai chế độ
| | Chế độ 1: Zoom + lồng tiếng | Chế độ 2: Người cử động thật |
|---|---|---|
| Công cụ | `scripts/make_video.py` (chạy ngay trên máy) | `scripts/ai_motion.py` (AI Wan 2.2 / LTX trên Hugging Face) |
| Chi phí | Miễn phí | Miễn phí, giới hạn lượt/ngày |
| Ảnh có rời máy không | Không | **Có**, gửi lên máy chủ Hugging Face |
| Thời gian | ~1 phút | 1-5 phút mỗi clip, có thể phải xếp hàng |

Mặc định dùng chế độ 1. Chỉ dùng chế độ 2 khi người dùng muốn người/vật cử động thật VÀ đã đồng ý gửi ảnh lên máy chủ bên ngoài.

## Các bước (theo thứ tự thực hiện)
1. **Xem ảnh, tìm toạ độ khuôn mặt/chủ thể** (pixel trên ảnh gốc). Vì zoom phải vào đúng người, không zoom vào khoảng trống.
2. **Viết kịch bản 6-8 cảnh, 2-3,5 giây mỗi cảnh**: mở đầu giới thiệu tình huống, các câu thoại qua lại, câu chốt bất ngờ ở cuối. Vì video ngắn giữ chân người xem nhờ nhịp nhanh và cú chốt.
3. **Cho người dùng duyệt nhanh lời thoại** (liệt kê dạng gạch đầu dòng). Nếu họ đã bảo "làm luôn" thì bỏ qua bước này và làm luôn.
4. **(Chỉ chế độ 2) Hỏi đồng ý gửi ảnh**, rồi chạy:
   `python3 scripts/ai_motion.py --image <anh> --prompt "<mô tả cử động bằng tiếng Anh>" --out work/clip1.mp4 --seconds 4`
   Vì ảnh người thật, nhất là trẻ em, chỉ được rời máy khi chủ ảnh cho phép.
5. **Viết `plan.json`** theo `examples/plan-mau.json` (canh có `"image"` hoặc `"video"`). Kiểm tra: `python3 scripts/make_video.py --plan plan.json --out x.mp4 --check`.
6. **Dựng**: `python3 scripts/make_video.py --plan plan.json --out video.mp4`. Lần đầu tự tải giọng đọc tiếng Việt (Piper, ~60 MB, từ huggingface.co).
7. **Tự kiểm tra**: cắt 5-6 khung hình (`ffmpeg -ss <giây> -i video.mp4 -frames:v 1 ...`), ghép lại và nhìn: phụ đề đủ dấu, không che mặt, zoom đúng người. Sửa plan và dựng lại nếu sai.
8. **Gửi file video** cho người dùng, kèm danh sách lời thoại và một câu hỏi họ muốn đổi gì không.

## Định dạng & đầu ra
- **Độ dài**: 15-30 giây (TikTok), tối đa ~60 giây.
- **Khung**: 9:16 (1080x1920) mặc định; 16:9 nếu người dùng nói YouTube.
- **Giọng điệu lời thoại**: hồn nhiên, trêu đùa nhẹ, gần gũi kiểu gia đình Việt; câu ngắn ≤ 12 từ.
- **Cấu trúc**: cảnh mở (`ke` dẫn chuyện) → thoại qua lại giữa các nhân vật → câu chốt (`"punch": true`).
- **Giọng nhân vật**: `speakers` = hệ số cao độ. Người dẫn 1.0, nam/anh lớn 1.2, bé gái/em nhỏ 1.5.

## Luôn luôn
- Phụ đề tiếng Việt dùng font đi kèm `assets/fonts/BeVietnamPro-Bold.ttf` (script tự làm). Font khác có thể mất dấu.
- Cắt bỏ logo/watermark máy ảnh (vd. "HONOR 400" ở đáy ảnh) bằng cách chọn `focus` sao cho khung cắt tránh chúng.
- Tự xem khung hình kiểm tra trước khi gửi.
- Nói rõ giọng là máy đọc miễn phí, nghe hơi "robot".
- Giữ ảnh/video người dùng trong thư mục làm việc tạm, không đưa lên GitHub hay nơi công khai.

## Không bao giờ
- Không gửi ảnh người thật lên dịch vụ bên ngoài (chế độ 2) khi chưa hỏi và được đồng ý.
- Không dùng dịch vụ trả phí khi người dùng chưa yêu cầu.
- Không viết lời thoại chê bai ngoại hình, nội dung người lớn, hay đặt lời nói xấu/gây hiểu lầm vào miệng người thật có thật ngoài gia đình người dùng.
- Không làm video giả mạo người nổi tiếng hay người khác để lừa người xem.

## Ví dụ
**Đầu ra tốt trông như thế này** (ảnh 2 anh em ăn bánh ở quán cà phê):
- *Dẫn:* "Ra quán với bố mẹ. Mẹ dặn: anh chia bánh cho em nha!"
- *Anh hai:* "Để anh thử xem bánh có ngon không đã..."
- *Em gái:* "Thử một miếng thôi đó nha anh."
- *Anh hai:* "Miếng này hơi chua. Anh thử miếng nữa cho chắc."
- *Kết quả chia bánh:* "Anh 9 phần. Em 1 cái thìa." (punch)
- *Em gái:* "Thôi để em mách mẹ!" (punch)
Zoom luân phiên vào từng bé đúng người đang "nói", 23 giây, có nhạc và tiếng "boing" ở câu chốt.

**Đầu ra yếu trông như thế này:**
- Một cảnh tĩnh 20 giây, phụ đề dài 3 dòng: "Hai anh em đang ăn bánh rất vui vẻ ở quán cà phê cùng gia đình."
Lý do sai: không có nhịp, không có xung đột hay câu chốt, chỉ mô tả lại điều người xem đã thấy.

## Khi không chắc chắn
Hỏi trước khi đoán. Liệt kê câu hỏi, đừng tự điền vào chỗ trống:
- Tên/biệt danh các nhân vật? (để lời thoại thân thiết hơn)
- TikTok (9:16) hay YouTube (16:9)?
- Có muốn người trong ảnh cử động thật không? (cần gửi ảnh lên máy chủ AI miễn phí)
Nếu người dùng nói "làm luôn": dùng mặc định (9:16, chế độ 1, gọi nhân vật theo vai "anh hai", "em gái"...) và nói rõ đã chọn gì.

## Khi lỗi
- **Không tải được giọng đọc** (mạng chặn huggingface.co): video vẫn được tạo, chỉ có phụ đề. Báo người dùng.
- **ai_motion.py thất bại**: thường do hết lượt miễn phí trong ngày hoặc mạng chưa cho phép `<space>.hf.space`. Gợi ý thử lại sau vài giờ, hoặc dùng app CapCut / Gemini trên điện thoại (miễn phí), rồi gửi clip về để ghép bằng chế độ 1.
- **Clip AI méo mặt/tay**: chạy lại (seed ngẫu nhiên) hoặc mô tả cử động nhẹ hơn ("slight smile, small head turn").
