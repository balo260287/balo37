# Hướng dẫn: PC tự ngủ ban đêm, tự thức buổi sáng, tự mở MT5

Sau khi cài xong, mỗi ngày máy sẽ tự chạy như sau:

- **23:00:** máy tự **ngủ** (Sleep). Nếu bot còn lệnh đang mở, máy **chờ** đến khi lệnh đóng xong mới ngủ (chờ tối đa 3 tiếng).
- **06:00:** máy tự **thức dậy**. MT5 vẫn mở sẵn từ hôm trước và bot chạy tiếp.
- **Ban ngày:** máy không tự ngủ.
- **Khi khởi động lại hoặc mất điện:** MT5 tự mở khi bạn đăng nhập Windows.

Giờ ngủ và giờ thức bạn chọn được lúc cài.

---

## BƯỚC 1: Tải file về PC (2 phút)

1. Trên PC, mở trình duyệt (Chrome hoặc Edge) và vào link:
   **https://github.com/balo260287/balo37/archive/refs/heads/claude/toan-bo-cai-dat-s03ai9.zip**
   (Nếu GitHub bắt đăng nhập thì đăng nhập tài khoản `balo260287`.)
2. Một file `.zip` sẽ được tải về thư mục **Downloads** (Tải xuống).
3. Mở thư mục Downloads, **chuột phải** vào file zip và chọn **Extract All…** (Giải nén tất cả), rồi bấm **Extract**.
4. Mở thư mục vừa giải nén, sau đó mở thư mục **`tu-dong-pc`**. Bên trong có 3 file:
   - `1-CAI-DAT.bat`
   - `2-THU-NGHIEM.bat`
   - `3-GO-BO.bat`

## BƯỚC 2: Cập nhật bot trong MT5 (bắt buộc, 3 phút)

Bot mới có thêm chức năng báo cho máy biết "còn lệnh, đừng ngủ".

1. Mở MT5, bấm menu **File** và chọn **Open Data Folder**.
2. Mở thư mục **MQL5**, rồi thư mục **Experts**.
3. Chép file **`WyckoffGold.mq5`** (nằm trong thư mục vừa giải nén ở Bước 1) vào đây. Nếu Windows hỏi có ghi đè không thì chọn **Replace** (Thay thế).
4. Quay lại MT5 và bấm **F4** để mở MetaEditor. Trong cột bên trái, mở **Experts** và bấm đúp vào **WyckoffGold**.
5. Bấm **F7** (Compile). Dòng dưới cùng phải hiện **0 errors**. Nếu báo lỗi, chụp màn hình gửi Claude.
6. Quay lại MT5 và kéo **WyckoffGold** từ khung Navigator vào biểu đồ **XAUUSDm, H1**.
7. Trong cửa sổ hiện ra, sang tab **Common**, tick **Allow Algo Trading**, rồi bấm **OK**.
8. Bấm nút **Algo Trading** trên thanh công cụ của MT5 cho nút chuyển sang màu **xanh**.

## BƯỚC 3: Cài đặt tự động (2 phút)

1. **Bấm đúp** vào **`1-CAI-DAT.bat`**.
2. Nếu hiện màn hình xanh **"Windows protected your PC"**, bấm chữ **More info**, rồi bấm **Run anyway**.
3. Khi Windows hỏi **"Do you want to allow this app to make changes?"**, bấm **Yes**.
4. Một cửa sổ đen hiện ra:
   - Nếu trên máy có **nhiều MT5**, gõ số thứ tự của MT5 đang chạy bot rồi bấm **Enter**.
   - Khi hỏi **giờ NGỦ**: bấm **Enter** để dùng giờ mặc định 23:00, hoặc gõ giờ khác (ví dụ `22:30`) rồi Enter.
   - Khi hỏi **giờ THỨC**: bấm **Enter** để dùng 06:00, hoặc gõ giờ khác.
5. Khi thấy chữ xanh **XONG** là đã cài xong. Bấm phím bất kỳ để đóng cửa sổ.

## BƯỚC 4: Thử nghiệm (5 phút, rất quan trọng)

Bước này để chắc chắn máy của bạn **tự thức dậy được**. Không phải máy nào cũng làm được.

1. Lưu lại những gì đang làm dở trên máy.
2. Bấm đúp vào **`2-THU-NGHIEM.bat`** và bấm **Yes** khi Windows hỏi.
3. Bấm **Enter**. Máy sẽ **ngủ ngay** (màn hình tắt).
4. **Không chạm** vào chuột hay bàn phím. Chờ 3–4 phút.
5. Xem kết quả:
   - **Máy tự sáng lên:** sau khi đăng nhập lại, cửa sổ đen hiện chữ xanh **THÀNH CÔNG**. Vậy là xong, mọi thứ đã chạy tự động.
   - **Máy không tự sáng:** bấm nút nguồn để bật lại, rồi làm theo mục bên dưới.

### Nếu thử nghiệm THẤT BẠI

Máy của bạn không cho phép tự thức dậy từ chế độ ngủ (hay gặp ở laptop đời mới). Có 2 cách:

- **Cách A, đơn giản nhất:** để máy **chạy suốt** và không cho ngủ. Chạy `3-GO-BO.bat` để gỡ chế độ tự động, rồi mở **Settings → System → Power** (Cài đặt → Hệ thống → Nguồn) và đặt **Sleep = Never** (Không bao giờ).
- **Cách B:** **thuê VPS** (máy chủ Windows chạy 24/7, khoảng 5–15 USD/tháng). Sàn Exness có VPS miễn phí khi tài khoản đủ điều kiện, xem trong Personal Area → **VPS**. Đây là cách dân chạy bot hay dùng nhất.

---

## Xem máy đã làm gì

Mở **File Explorer**, gõ `C:\WyckoffAuto` lên thanh địa chỉ rồi bấm Enter, sau đó mở file **`nhat-ky.txt`**. Ví dụ nội dung:

```
2026-11-08 23:00  Con 1 lenh/lenh cho -> doi 10 phut
2026-11-08 23:10  Khong con lenh -> cho may NGU
2026-11-09 06:00  May thuc, bat che do giu thuc
```

## Muốn đổi giờ

Chạy lại **`1-CAI-DAT.bat`** và nhập giờ mới. Lịch cũ sẽ bị thay thế.

## Muốn tắt hết chế độ tự động

Bấm đúp **`3-GO-BO.bat`** và bấm **Yes**. Máy trở lại bình thường.

---

## Lưu ý

- **Phải cắm sạc** nếu dùng laptop.
- **Không tắt nguồn hẳn (Shut down)** máy. Chỉ để máy tự ngủ. Nếu tắt hẳn thì máy không tự bật lại được.
- **Windows Update** có thể tự khởi động lại máy. Để tránh việc này, vào **Settings → Windows Update → Advanced options → Active hours** và đặt giờ hoạt động từ 6:00 đến 23:00.
- Khi máy ngủ, **lệnh trên sàn vẫn còn** và SL/TP vẫn hoạt động bình thường. Chỉ có bot tạm ngừng, nên không vào lệnh mới và không dời SL về hoà vốn được.
- Máy sẽ không ngủ nếu **bất kỳ lệnh nào** trên tài khoản đang mở, kể cả lệnh bạn tự vào bằng tay, miễn là bot WyckoffGold đang chạy trên MT5.
