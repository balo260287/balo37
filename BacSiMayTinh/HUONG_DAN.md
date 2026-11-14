# 🩺 Bác Sĩ Máy Tính

Bấm một cái là máy tự quét virus, dọn rác, kiểm tra sức khoẻ. Gmail cũng tự dọn thư rác mỗi ngày.

## Phần 1: Khám PC (Windows 10/11)

1. Tải cả thư mục `BacSiMayTinh` về máy, để chung các file với nhau.
2. Bấm đúp file:
   - **`1-KhamNhanh.bat`**: khoảng 5–10 phút, nên chạy mỗi tuần.
   - **`2-KhamKy.bat`**: 30–90 phút, quét toàn bộ ổ đĩa và sửa file Windows bị hỏng. Nên chạy mỗi tháng, hoặc khi máy lỗi hay chậm bất thường.
3. Windows hỏi *"Cho phép ứng dụng này thay đổi thiết bị?"* thì bấm **Yes**.
4. Chạy xong, file báo cáo `BacSiMayTinh_BaoCao_....txt` sẽ nằm ngoài **Desktop**.

Nếu Windows hiện màn hình xanh *"Windows protected your PC"* thì bấm **More info**, rồi **Run anyway**. Lý do là file tự tạo, chưa có chữ ký số.

### Bác sĩ làm những gì
| Bước | Việc làm |
|---|---|
| 1. Diệt virus | Cập nhật Windows Defender, quét, rồi tự cách ly hoặc xoá virus tìm thấy |
| 2. Dọn rác | File tạm, cache Windows Update, cache trình duyệt (Chrome, Edge, Cốc Cốc, Firefox), thùng rác |
| 3. Mạng | Xoá cache DNS |
| 4. Sức khoẻ | Báo ổ đĩa sắp đầy, ổ cứng sắp hỏng, RAM, các app ngốn RAM, các app tự chạy khi khởi động |
| 5. (Khám kỹ) | DISM và SFC: sửa file hệ thống Windows bị hỏng |

**Không đụng tới:** mật khẩu, lịch sử, bookmark trình duyệt, tài liệu, ảnh, game.

### Tự khám MỖI NGÀY (nút BẬT / TẮT)
Bấm đúp `4-BAT-TAT-TuDong.bat` rồi bấm **Yes**. Ngoài Desktop sẽ có biểu tượng:
- **Bac Si May Tinh - DANG BAT**: máy tự khám mỗi ngày lúc 12 giờ trưa (lúc đó máy tắt thì lần bật máy kế tiếp sẽ khám bù).
- **Bac Si May Tinh - DANG TAT**: không tự khám nữa.

Muốn đổi qua lại giữa BẬT và TẮT thì bấm đúp vào biểu tượng đó.

## Phần 2: Gmail tự dọn rác (cài 1 lần, ~3 phút)

1. Vào **https://script.google.com** (đăng nhập Gmail của bạn) và bấm **New project**.
2. Xoá hết code mẫu, dán toàn bộ nội dung file `GmailDonRac.gs` vào, bấm 💾 **Save**.
3. Ở ô chọn hàm trên thanh công cụ, chọn **`donRacGmail`** rồi bấm **Run**.
   - Google sẽ hỏi quyền. Bấm **Review permissions**, chọn tài khoản, rồi **Advanced**, **Go to project (unsafe)**, **Allow**.
     (Google ghi "unsafe" chỉ vì đây là script bạn tự viết, chưa đăng ký với Google. Script chỉ chạy trong tài khoản của bạn.)
4. Chọn hàm **`batTuDongMoiNgay`** rồi bấm **Run**. Từ giờ Gmail tự dọn mỗi ngày lúc ~3h sáng.

### Script dọn những gì (sửa được ở đầu file)
- Thư **Spam**
- **Quảng cáo** cũ hơn 14 ngày
- **Mạng xã hội** cũ hơn 30 ngày
- **Thông báo** cũ hơn 60 ngày
- Thư **có gắn sao ⭐ hoặc Quan trọng thì không bao giờ bị xoá**
- Thư chỉ bị chuyển vào **Thùng rác**, trong 30 ngày vẫn khôi phục được.

Muốn tắt: chạy hàm `tatTuDong`.
