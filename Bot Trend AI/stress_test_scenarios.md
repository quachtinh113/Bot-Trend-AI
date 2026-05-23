# Kịch Bản Kiểm Thử Căng Thẳng (Stress Test) — Gia Cat Institutional Upgrade

Tài liệu này xác định các kịch bản kiểm thử căng thẳng trong **MetaTrader 5 Strategy Tester** nhằm kiểm chứng các cơ chế tự bảo vệ và phòng thủ của bot hoạt động đúng kỳ vọng trước các điều kiện thị trường cực đoan.

---

## 🎬 Kịch Bản 1: Tin Tức Giật Mạnh & Tốc Độ Drawdown Cao (Flash Crash)
* **Mục tiêu:** Kiểm tra phản ứng của `CEquityDefense` khi xảy ra biến động mạnh đột ngột (Tin NFP, CPI hoặc sự cố Flash Crash).
* **Thiết lập Strategy Tester:**
  - Cặp tiền: **Gold (XAUUSD)** hoặc **GBPUSD**.
  - Thời gian: Chọn khoảng thời gian có tin mạnh (Ví dụ: Tuần đầu tháng 5/2026 hoặc sự kiện bầu cử/lãi suất cụ thể).
  - Phương thức mô phỏng: `Every tick based on real ticks` (để mô phỏng chính xác spread và tốc độ chạy giá).
* **Các chỉ số kích hoạt kỳ vọng:**
  - Tốc độ Drawdown vượt ngưỡng `InpMaxDDVelocity = 2.0%` mỗi phút.
  - Chỉ báo ATR H1 tăng vọt > 1.8 lần so với trung bình.
* **Hành vi kỳ vọng (Hành động của EA):**
  1. Chuyển đổi Market Regime ngay lập tức sang `REGIME_TRENDING`.
  2. Kích hoạt trạng thái `DEFENSE_EMERGENCY_EXIT` (do tốc độ sụt giảm tài khoản tăng nhanh).
  3. Dừng mở thêm lệnh DCA mới hoàn toàn để giảm thiểu độ chịu rủi ro.
  4. Bật chế độ co cụm/tỉa bớt lệnh bằng Trim Manager.
* **Tiêu chuẩn Vượt qua (Pass):**
  - Không có bất kỳ lệnh DCA mới nào được mở trong suốt chu kỳ giá quét mạnh.
  - Các sự kiện cấm giao dịch và chuyển chế độ được ghi nhận chính xác trong file `GiaCat_Audit_Log.csv`.

---

## 🎬 Kịch Bản 2: Xu Hướng Đi Một Chiều Kéo Dài (High Trend / Grid Squeeze)
* **Mục tiêu:** Kiểm tra khả năng giãn cách lưới thông minh và cơ chế chuyển đổi Sinh Tồn khi xu hướng đi một chiều kéo dài không hồi.
* **Thiết lập Strategy Tester:**
  - Cặp tiền: **EURUSD** hoặc **GBPUSD** chạy trong giai đoạn có xu hướng dốc (ví dụ: Thị trường sụt giảm hoặc tăng liên tục > 400 - 500 pips không hồi).
* **Các chỉ số kích hoạt kỳ vọng:**
  - ADX H1 > 25.
  - Số lượng lệnh mở trong rổ tăng lên nhanh chóng.
  - Tài khoản bắt đầu chạm ngưỡng cảnh báo sụt giảm vốn `SurvivalDDPct = 25%` hoặc Margin Level tụt xuống dưới `SurvivalMarginLevel = 250%`.
* **Hành vi kỳ vọng (Hành động của EA):**
  1. Market Regime được nhận diện là `REGIME_TRENDING`, hệ số nhân khoảng cách được tăng lên gấp 3 lần (`grid_spacing_multiplier = 3.0`).
  2. Khi lệnh rổ đạt 7 lệnh, Trim Manager kích hoạt tỉa lệnh đầu lưới âm nhiều nhất bằng tiền lãi từ lệnh thuận xu hướng.
  3. Khi Margin Level tụt dưới 250%, trạng thái Sinh Tồn (Survival Mode) được kích hoạt và khóa chặt tính năng DCA.
  4. Nếu giá tiếp tục đi ngược xu hướng, rổ lệnh sẽ tự động bị cắt lỗ khẩn cấp (Force Cut) ở mức **40.0% Drawdown** hoặc **180% Margin Level** nhằm giữ lại 60% vốn cho tài khoản.
* **Tiêu chuẩn Vượt qua (Pass):**
  - Tài khoản không bị cháy (Margin Call / Stop Out về 0).
  - EA thực hiện Force Cut đúng thời điểm thiết lập và dừng hoạt động.

---

## 🎬 Kịch Bản 3: Giao Dịch Trong Phiên Á & London (Session Transition)
* **Mục tiêu:** Kiểm tra tính năng phân biệt phiên giao dịch và điều tiết khối lượng lệnh tự động.
* **Thiết lập Strategy Tester:**
  - Chạy mô phỏng liên tục trong 5 ngày bình thường.
* **Hành vi kỳ vọng (Hành động của EA):**
  - Trong **Phiên Á** (22:00 - 07:00 GMT): Lot size mở lệnh mới tự động giảm còn 60% (`lotScale = 0.6`), cho phép giao dịch đảo chiều.
  - Trong **Phiên Âu** (07:00 - 12:00 GMT): Lot size khôi phục 100% (`lotScale = 1.0`), các bộ lọc hướng đi theo xu hướng bắt buộc bật.
  - Trong **Phiên Trùng** (12:00 - 16:00 GMT): Lot size tự động siết chặt còn 50% (`lotScale = 0.5`) do thị trường có thanh khoản và biến động rất lớn.
* **Tiêu chuẩn Vượt qua (Pass):**
  - Khối lượng của các lệnh Base (lệnh đầu tiên) khớp chính xác theo tỷ lệ quy định tại các thời điểm giờ GMT tương ứng.

---

## 🎬 Kịch Bản 4: Giãn Spread & Trượt Giá Mạnh (Spread & Slippage Anomalies)
* **Mục tiêu:** Kiểm tra phản ứng bảo vệ của hệ thống trước tình trạng thanh khoản kém từ sàn giao dịch (nhất là lúc chuyển giao phiên hoặc ra tin).
* **Thiết lập Strategy Tester:**
  - Chọn phương thức mô phỏng `Every tick based on real ticks` hoặc thiết lập spread cố định tăng cao trong Strategy Tester (ví dụ: Spread = 150 points).
* **Hành vi kỳ vọng (Hành động của EA):**
  - Khi spread hiện tại vượt quá 3 lần trung bình lịch sử (`spread_ratio >= 3.0`): Kích hoạt `DEFENSE_HARD_BLOCK`, ngăn cấm hoàn toàn việc mở rổ lệnh mới.
  - Khi phát hiện lệnh giao dịch thực tế bị trượt giá quá `InpMaxSlippagePoints = 100 points`: Khóa mở rổ mới để bảo vệ tài khoản khỏi tình trạng khớp giá xấu.
* **Tiêu chuẩn Vượt qua (Pass):**
  - Hệ thống ghi nhận trạng thái Block và không thực thi lệnh giao dịch nào cho tới khi spread thu hẹp trở lại bình thường.

---

## 🎬 Kịch Bản 5: Giao Thức Thứ Sáu (Friday Close System)
* **Mục tiêu:** Kiểm soát rủi ro giữ vị thế qua tuần (tránh Gap thứ 2 đầu tuần).
* **Thiết lập Strategy Tester:**
  - Chạy mô phỏng qua nhiều tuần liên tiếp.
* **Hành vi kỳ vọng (Hành động của EA):**
  - Khi đồng hồ Broker chỉ 18:00 ngày Thứ 6: Bot dừng mở các rổ lệnh mới hoàn toàn.
  - Khi đồng hồ Broker chỉ 23:45 ngày Thứ 6: Bot tự động đóng sạch toàn bộ các lệnh Buy & Sell đang chạy của rổ hiện tại (bất kể đang lãi hay lỗ).
* **Tiêu chuẩn Vượt qua (Pass):**
  - Không có vị thế nào được giữ lại qua 24:00 ngày Thứ 6. Nhật ký ghi nhận lý do đóng lệnh: `"Friday Close Target"`.
