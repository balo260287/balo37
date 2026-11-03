# WyckoffGold: EA vàng theo phương pháp Wyckoff (MT5)

## Bot làm gì

1. **Tìm vùng đi ngang (Trading Range):** dùng 40 nến gần nhất. Vùng phải rộng từ 2 đến 8 lần ATR, và giá phải chạm cả đỉnh lẫn đáy vùng ít nhất 2 lần.
2. **BUY khi có Spring:** nến vừa đóng có râu đâm xuống dưới đáy vùng, nhưng đóng cửa lại bên trong vùng, ở nửa trên của thân nến, và volume cao hơn 1,3 lần trung bình. Đây là dấu hiệu "rũ bỏ" người bán.
3. **SELL khi có Upthrust:** ngược lại với Spring, râu nến đâm lên trên đỉnh vùng rồi bị đạp xuống.
4. **Stop Loss** đặt ngay ngoài râu nến tín hiệu. **Take Profit** đặt ở cạnh đối diện của vùng. Nếu tỉ lệ lời/lỗ (RR) dưới 1,5 thì bot bỏ qua lệnh.
5. Khi lãi bằng 1R, bot dời SL về giá vào lệnh (hoà vốn). Mỗi lúc chỉ có 1 lệnh, mỗi ngày tối đa 2 lệnh, và bot không vào lệnh khi spread cao.

## Cài vào MT5 (cần PC)

1. Mở MT5, vào **File → Open Data Folder → MQL5 → Experts**, rồi chép file `WyckoffGold.mq5` vào đó.
2. Mở **MetaEditor** (phím F4), mở file vừa chép và bấm **Compile** (F7). Nếu có lỗi, chụp màn hình gửi Claude.
3. Trong MT5, kéo **WyckoffGold** từ Navigator vào biểu đồ **XAUUSDm H1**, rồi bật nút **Algo Trading**.

> App MT5 trên điện thoại **không chạy được EA**. Bot phải chạy trên PC hoặc VPS và để máy bật liên tục.

## BẮT BUỘC: kiểm thử trước khi chạy tiền thật

1. Mở **Strategy Tester** (Ctrl+R), chọn WyckoffGold, XAUUSDm, H1, chế độ "Every tick based on real ticks", và chạy trên ít nhất 1–2 năm dữ liệu.
2. Xem kết quả: Profit Factor, Max Drawdown, số lệnh. Nếu Profit Factor dưới 1,2 hoặc số lệnh quá ít thì chưa nên dùng.
3. Tiếp theo, chạy trên **tài khoản demo** ít nhất 2–4 tuần.
4. Lúc mới chạy tiền thật, để `InpRiskPercent` ở mức **0,5–1%**.

## Tham số nên thử chỉnh

| Tham số | Mặc định | Ý nghĩa |
|---|---|---|
| InpRangeBars | 40 | Số nến dùng để xác định vùng đi ngang |
| InpVolMult | 1.3 | Volume nến tín hiệu phải cao hơn trung bình bao nhiêu lần |
| InpMinRR | 1.5 | Tỉ lệ lời/lỗ tối thiểu để vào lệnh |
| InpRiskPercent | 1.0 | % tài khoản chấp nhận mất mỗi lệnh |
| InpMaxSpreadPoints | 50 | Spread tối đa, cần chỉnh theo sàn |

## Giới hạn cần biết

- Wyckoff gốc còn có nhiều bước khác như Selling Climax, Test, Sign of Strength, LPS. Bot này chỉ tự động hoá phần Spring và Upthrust, phần dễ lập trình nhất.
- Volume trên MT5 là **tick volume** (số lần giá thay đổi), không phải khối lượng giao dịch thật của vàng.
- Không có bot nào thắng mãi. Hãy luôn kiểm thử và quản lý vốn.
