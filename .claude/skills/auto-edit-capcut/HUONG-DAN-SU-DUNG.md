# Hướng dẫn sử dụng Auto Edit CapCut

Để Claude tự viết kịch bản, lồng tiếng (Google Gemini TTS hoặc Higgsfield), tạo ảnh và **dựng sẵn timeline trong CapCut**: cắt cảnh khớp giọng đọc, zoom nhẹ, hiệu ứng âm thanh, nhạc nền, phụ đề tiếng Việt hoặc tiếng Anh. Làm được video ngang 16:9 (YouTube) và dọc 9:16 (TikTok, Reels, Shorts).

> Có thêm giọng đọc Google Gemini TTS và hướng dẫn tiếng Việt. Dựa trên skill *auto-edit-capcut* gốc; font đi kèm giữ nguyên giấy phép trong `assets/fonts/`.

---

## 1. Bạn cần chuẩn bị

| Thứ cần có | Ghi chú |
| :--- | :--- |
| **Claude** (app máy tính hoặc Claude Code) | Bật quyền chạy code / tạo file (Settings → Capabilities → *Code execution and file creation*). |
| **CapCut bản máy tính** (Mac hoặc Windows) | Không dùng được bản điện thoại hay bản web. Bản CapCut Trung Quốc (JianYing) khoá file dự án nên không dùng được. |
| **Giọng đọc**: chọn 1 trong 2 | **Google Gemini TTS** (có gói miễn phí, cần API key — mục 3) hoặc **Higgsfield** (trả bằng credit). |
| **Hình ảnh** | Tạo bằng Higgsfield, hoặc dùng ảnh/video của chính bạn. |
| Thư viện nhạc + hiệu ứng âm thanh (tuỳ chọn) | Một thư mục bất kỳ trên máy. Không có thì bỏ qua. |
| Python 3 | Máy Mac thường có sẵn. Skill tự cài các thư viện còn thiếu (numpy, Pillow, scipy, ffmpeg). |

## 2. Cài skill

**Claude Code / app máy tính có thư mục dự án:** chép nguyên thư mục `auto-edit-capcut` vào

- `~/.claude/skills/auto-edit-capcut/` (dùng cho mọi dự án), hoặc
- `<thư mục dự án>/.claude/skills/auto-edit-capcut/` (chỉ dự án đó).

**Claude.ai (web / app):** nén thư mục thành `auto-edit-capcut.zip` rồi tải lên tại *Settings → Capabilities → Skills → Upload skill*.

Kiểm tra: gõ cho Claude *"Kiểm tra môi trường cho skill auto-edit-capcut"*. Claude chạy `scripts/check_env.py` và báo thiếu gì.

## 3. Lấy và cài API key Gemini (cho giọng đọc)

1. Vào **aistudio.google.com** → đăng nhập Google → **Get API key** → **Create API key**. Chép key.
2. Đặt key vào máy (làm **một lần**). **Không dán key vào khung chat**, vì key sẽ nằm lại trong lịch sử trò chuyện.
   - **Mac:** mở Terminal, chạy (thay `KEY_CUA_BAN`):
     ```bash
     echo 'export GEMINI_API_KEY="KEY_CUA_BAN"' >> ~/.zshrc
     ```
   - **Windows:** mở PowerShell, chạy:
     ```powershell
     setx GEMINI_API_KEY "KEY_CUA_BAN"
     ```
3. Thoát hẳn rồi mở lại app Claude (hoặc mở Terminal mới).
4. Nhờ Claude: *"Chạy gemini_tts.py --check"*. Kết quả đúng: `key: ok` và danh sách model TTS.

**Giới hạn gói miễn phí:** khoảng 3 lượt tạo giọng mỗi phút (mỗi cảnh = 1 lượt). Script tự chờ khi chạm giới hạn, nên video dài sẽ lâu hơn một chút. Làm nhiều hoặc dùng cho quảng cáo thương mại: bật thanh toán (billing) cho key trong Google AI Studio.

Nếu lỡ dán key vào chat: vào AI Studio **xoá key đó** và tạo key mới.

## 4. Quy trình làm một video (Claude dẫn bạn từng bước)

| Bước | Claude làm | Bạn làm |
| :--- | :--- | :--- |
| 0 | Kiểm tra máy, key, CapCut | Đọc báo cáo, bổ sung cái còn thiếu |
| 1 | Hỏi: ngôn ngữ, khổ 16:9 / 9:16, độ dài, phong cách hình, chủ đề, Mac/Windows, thư mục nhạc | Trả lời |
| 2 | Viết kịch bản có nguồn, đếm chữ, ước thời lượng | **Duyệt kịch bản** |
| 3 | Đọc thử 2–3 giọng Gemini → tạo giọng từng cảnh → ghép → khớp thời gian từng chữ | Nghe thử, **chọn giọng** |
| 4 | Lập bảng cảnh theo giọng đọc | Xem bảng |
| 5 | Tạo bảng nhân vật (2 phương án) | **Chọn 1 phương án** (bắt buộc) |
| 6 | Tạo ảnh từng cảnh, tự soát và làm lại ảnh lỗi | Xem contact sheet |
| 7 | Chọn nhạc + hiệu ứng từ thư viện của bạn | Có thể đổi nhạc |
| 8 | Đưa media vào thư mục `CapCut Automation/<Tên video>/` | **Tạo dự án CapCut → Import → Thoát CapCut → nhắn "xong"** |
| 9 | Dựng timeline, kiểm tra, xuất bản xem trước MP4 | Xem bản xem trước |
| 10 | Ghi timeline vào dự án (có sao lưu) | **Giữ CapCut đóng**, xong thì mở dự án |
| 11 | (Tuỳ chọn) thumbnail, tiêu đề, mô tả, chương | — |

### Mẫu câu lệnh bắt đầu

```
Dùng skill auto-edit-capcut làm video [9:16 TikTok / 16:9 YouTube], [60 giây],
tiếng [Việt / Anh], chủ đề: [chủ đề]. Phong cách hình: [hoạt hình phẳng / ...].
Giọng đọc dùng Gemini TTS. Máy Mac, thư mục nhạc: [~/Music/SFX].
```

### Chọn giọng Gemini

Claude đọc thử câu đầu kịch bản bằng 2–3 giọng để bạn nghe. Gợi ý:

- **Ấm, kể chuyện:** Sulafat, Achird, Vindemiatrix
- **Trầm, nam:** Charon, Algenib
- **Tươi, trẻ:** Puck, Aoede

Muốn đọc chậm hay nhanh hơn: nói Claude viết câu ngắn hơn hoặc dài hơn, hoặc chỉnh tốc độ ở bước ghép (tối đa nhanh hơn khoảng 15%). **Đừng chèn lời dặn kiểu "đọc chậm thôi:" vào kịch bản**, vì giọng đọc sẽ đọc luôn câu đó.

## 5. Bước bàn giao CapCut (quan trọng)

1. Mở CapCut → **Tạo dự án mới**.
2. **Import** toàn bộ file trong thư mục `CapCut Automation/<Tên video>/`. Chỉ cần nằm trong kho media, không cần kéo vào timeline.
3. Đổi tên dự án **đúng như tên video** Claude đưa (phân biệt hoa thường, dấu cách).
4. **Thoát hẳn CapCut** (Mac: Cmd+Q; Windows: đóng cả ở khay hệ thống).
5. Nhắn Claude **"xong"**.

Sau khi Claude ghi xong timeline, mở CapCut và bấm vào dự án. Bản cũ được sao lưu trong thư mục dự án (`_backup_before_cca_...`).

**Lưu ý:**

- Không mở CapCut trong lúc Claude đang ghi: CapCut sẽ ghi đè timeline khi thoát.
- Sau khi nhận timeline, bạn chỉnh tay thoải mái trong CapCut. Nếu nhờ Claude dựng lại, phần chỉnh tay sẽ bị ghi đè (vẫn có bản sao lưu).
- Video tiếng Việt: Claude đặt font **Be Vietnam Pro** vào `CapCut Automation/_fonts/` để phụ đề hiện đủ dấu.

## 6. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
| :--- | :--- |
| `GEMINI_API_KEY is not set` | Làm lại mục 3, nhớ mở lại app Claude sau khi đặt key. |
| `429 RESOURCE_EXHAUSTED` | Gói miễn phí hết lượt trong phút: script tự chờ. Hết lượt trong ngày: chờ hôm sau hoặc bật billing. |
| Giọng đọc đọc luôn câu dặn dò | Xoá mọi chữ trong ngoặc / lời dặn khỏi kịch bản, chỉ để lời thoại. |
| Không tìm thấy dự án CapCut | Tên dự án phải trùng tuyệt đối; mở dự án một lần, đổi tên, thoát rồi thử lại. |
| "Locked format" / file không bắt đầu bằng `{` | Bản CapCut này khoá dự án (thường là JianYing). Dùng CapCut quốc tế, hoặc dựng tay theo bảng cảnh và bản xem trước MP4. |
| Phụ đề tiếng Việt mất dấu | Kiểm tra `CapCut Automation/_fonts/BeVietnamPro-Bold.ttf` có trên máy. |
| Âm thanh quá to / nhỏ | Nhờ Claude chỉnh mức hiệu ứng (`level`) hoặc nhạc nền (`target_lufs`). |

## 7. Bảo mật và bản quyền

- API key chỉ đặt trong máy (biến môi trường), không dán vào chat, không ghi vào file dự án.
- Chỉ dùng nhạc, hiệu ứng, ảnh, video bạn có quyền sử dụng. Người xuất hiện rõ mặt trong video cần đồng ý.
- Âm thanh Gemini có watermark SynthID (không nghe thấy), theo chính sách của Google.
- Font: Be Vietnam Pro (SIL OFL), Metropolis (public domain): xem `assets/fonts/`.

## 8. Bộ câu lệnh mẫu từng bước

Chép lần lượt từng câu, thay phần trong [ngoặc vuông]. So với file *Tư liệu hướng dẫn.pdf* bản gốc:

- bước lồng tiếng dùng **Gemini TTS** thay ElevenLabs;
- bước khớp mốc thời gian skill **tự làm** (`align_vo.py`), không cần ra lệnh riêng;
- có thêm cách **dùng ảnh/video thật** thay cho ảnh AI.

Các câu còn lại của bản gốc vẫn dùng được.

### Bước 0 — Kiểm tra

```
Dùng skill auto-edit-capcut. Kiểm tra môi trường (check_env) và key Gemini (gemini_tts.py --check),
báo mình còn thiếu gì trước khi làm.
```

### Bước 1 — Kịch bản

```
Viết kịch bản [9:16 TikTok / 16:9 YouTube] dài khoảng [60 giây], tiếng [Việt / Anh], chủ đề [chủ đề],
nhân vật chính [tên nhân vật], kênh nói về [chủ đề kênh], giọng văn [gần gũi, câu ngắn].
Trình bày bảng: Cảnh | Hình ảnh | Lời thoại, kèm số chữ và thời lượng ước tính.
Lời thoại chỉ gồm câu sẽ đọc, không ghi chú hay ngoặc.
```

Nếu muốn nhịp nhanh hơn:

```
Chia nhỏ cảnh hơn, mỗi cảnh khoảng [2] giây, giữ nguyên lời thoại.
Mỗi cảnh mới có hình khác cảnh trước.
```

### Bước 2 — Lồng tiếng bằng Gemini TTS

```
Đọc thử câu đầu kịch bản bằng 3 giọng Gemini: [Sulafat, Charon, Achird], gửi mình nghe.
```

```
Mình chọn giọng [tên giọng]. Tạo giọng đọc toàn bộ kịch bản, mỗi cảnh một file,
rồi ghép và khớp mốc thời gian từng chữ. Gặp lỗi thì dừng và báo mình, không tự chạy lại.
```

### Bước 3 — Hình ảnh

**Cách A: ảnh AI (Higgsfield).** Như bản gốc: tạo ảnh khoá nhân vật trước, rồi bảng đạo cụ, rồi ảnh từng cảnh.

```
Tạo bảng nhân vật cho [tên nhân vật], phong cách [minh hoạ 2D / hoạt hình phẳng], 2 phương án để mình chọn.
Sau khi mình chọn, tạo ảnh từng cảnh khổ [9:16 / 16:9], không có chữ trong ảnh.
Báo tổng số ảnh và credit, đợi mình đồng ý rồi mới chạy.
```

**Cách B: ảnh/video thật.**

```
Không tạo ảnh AI. Dùng ảnh/video trong thư mục [đường dẫn]: xem từng file,
chọn cảnh khớp từng câu thoại, cắt khung [9:16 / 16:9], gửi mình bảng cảnh để duyệt.
```

### Bước 4 — Dựng trong CapCut

```
Đưa media vào thư mục CapCut Automation/[Tên video]/ và hướng dẫn mình tạo dự án.
```

Làm theo mục 5: tạo dự án đúng tên, Import, thoát hẳn CapCut. Sau đó gửi:

```
Xong. Dựng video "[Tên video]" bằng cách ghi thẳng vào file dự án, không mở CapCut.
Nhạc nền: [tên file nhạc hoặc "không"]. Cắt cảnh theo từng câu thoại, zoom nhẹ;
nhạc nhỏ hơn giọng và nhỏ dần ở cuối; chữ ý chính đặt trong vùng an toàn.
Trước khi ghi: gửi bản xem trước MP4, hỏi mình đã thoát CapCut chưa, sao lưu dự án.
```

### Nếu CapCut báo đỏ "mất kết nối" media

Chuột phải vào clip → **Liên kết lại (Relink)** → trỏ tới thư mục `CapCut Automation/[Tên video]/`.
