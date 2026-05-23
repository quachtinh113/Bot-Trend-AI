# Quy Trình Kiểm Thử Khôi Phục Runtime (Runtime Recovery Test Guide)

Tài liệu này hướng dẫn cách mô phỏng các sự cố kết nối, giãn spread, sụt giảm ký quỹ và can thiệp thủ công từ xa để kiểm chứng khả năng tự khôi phục an toàn của robot Gia Cat mà không xảy ra lỗi trùng lặp lệnh (duplicate orders) hoặc quá tay nhồi lệnh (DCA overflow).

---

## 🛠️ 1. Mô Phỏng Mất Kết Nối Mạng & Đăng Nhập Lại (Disconnect/Reconnect)
* **Mục tiêu:** Đảm bảo khi mất kết nối mạng và kết nối lại, robot không bị đơ (freeze) và không vào nhầm lệnh cũ.
* **Cách thực hiện:**
  1. Trong khi EA đang chạy và quản lý một rổ lệnh dca (ví dụ có 2-3 lệnh đang mở).
  2. Rút dây mạng PC hoặc ngắt Wifi (hoặc tắt card mạng trên VPS).
  3. Để trạng thái ngắt mạng kéo dài trong **5 phút**. Quan sát xem EA có báo lỗi kết nối trong tab *Journal* của MT5 và tệp `GiaCat_Telemetry.json` có ghi nhận trạng thái `is_online: false` hay không.
  4. Cắm lại dây mạng (hoặc bật lại card mạng).
  5. Đợi MT5 đăng nhập lại thành công.
* **Hành vi kỳ vọng:**
  - Robot tiếp tục theo dõi đúng rổ lệnh hiện có qua Magic Number.
  - Không mở thêm bất kỳ lệnh DCA trùng lặp nào tại mức giá cũ.
  - Số lần ngắt kết nối `disconnect_count` tăng thêm 1 trong báo cáo `daily_forward_report.json`.

---

## 🛠️ 2. Mô Phỏng Biến Động Giãn Spread Mạnh (Spread Spike)
* **Mục tiêu:** Tránh khớp lệnh dca tại các mức giá bất lợi do chênh lệch mua bán quá rộng.
* **Cách thực hiện:**
  - Trong Strategy Tester, cấu hình mức spread cố định tăng cao đột ngột (ví dụ: 600 points).
  - Hoặc trong tài khoản demo, theo dõi thời điểm chuyển giao phiên lúc 4:00 AM - 5:00 AM (giờ Việt Nam) khi các sàn giãn spread mạnh.
* **Hành vi kỳ vọng:**
  - `CPredictiveVolatility` hoặc bộ lọc `InpMaxSpread` phát tín hiệu chặn.
  - EA khóa chức năng mở lệnh mới hoàn toàn.
  - Ghi nhận sự kiện `SPREAD_SPIKE` trong file log.

---

## 🛠️ 3. Kiểm Tra Công Tắc Kìm Cương (SAFE_MODE & HARD_BLOCK)
* **Mục tiêu:** Kiểm tra khả năng can thiệp khẩn cấp tức thời bằng tay thông qua biến toàn cục (Global Variables).
* **Cách thực hiện:**
  1. EA đang chạy ở chế độ bình thường.
  2. Nhấn phím `F3` trên MT5 để mở bảng **Global Variables**.
  3. Tìm từ khóa `GIA_CAT_RUNTIME_MODE` và thay đổi giá trị từ `0` sang `1` (SAFE_MODE).
  4. Đợi nến chạy và quan sát xem khối lượng của lệnh tiếp theo có tự động giảm 60% hay không.
  5. Thay đổi giá trị sang `3` (NO_NEW_BASKET) và xác nhận robot không mở thêm rổ lệnh mới sau khi rổ cũ đã được chốt lời.
  6. Thay đổi giá trị sang `5` (HARD_KILL) và xác nhận toàn bộ vị thế bị thanh lý lập tức và EA tự gỡ.

---

## 🛠️ 4. Mô Phỏng Trùng Tin Tức Lớn (News Blackout)
* **Mục tiêu:** Tránh nhồi lệnh trong các thời điểm ra tin bão có độ biến động và trượt giá cao.
* **Cách thực hiện:**
  - Theo dõi lịch kinh tế (Forex Factory hoặc MT5 Calendar).
  - Trước khi tin ra (ví dụ tin CPI) 30 phút, kiểm tra xem EA có tự động khóa không cho mở lệnh Base (lệnh đầu tiên) hay không.
  - Sau khi tin ra 30 phút, kiểm tra xem EA có tự động mở khóa giao dịch bình thường trở lại hay không.

---

## 🛠️ 5. Mô Phỏng Sụt Giảm Ký Quỹ (Margin Deterioration)
* **Mục tiêu:** Kích hoạt chế độ sinh tồn bảo vệ tài khoản khi ký quỹ cạn kiệt.
* **Cách thực hiện:**
  - Giả lập mở thêm các vị thế tay khối lượng lớn trên biểu đồ khác để ép mức Margin Level tài khoản tụt xuống dưới 300% và 250%.
* **Hành vi kỳ vọng:**
  - Khi Margin Level <= 300%: Trạng thái **SOFT_BLOCK** kích hoạt, chặn mở dca.
  - Khi Margin Level <= 250%: Trạng thái **SAFE_MODE** kích hoạt, chặn rổ mới.
  - Khi Margin Level <= 180%: Trạng thái **HARD_KILL** kích hoạt, cắt sạch lệnh đang chạy.
