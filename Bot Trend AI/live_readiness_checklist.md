# Danh Sách Kiểm Tra Sẵn Sàng Vận Hành Live (Live Readiness Checklist)

Trước khi khởi chạy **Gia Cat Quant Survival Engine (V3)** trên tài khoản thực hoặc tài khoản demo live, bạn bắt buộc phải kiểm tra qua các mục dưới đây để đảm bảo an toàn tuyệt đối cho tài khoản.

---

## 🧪 1. Quy Trình Kiểm Thử Trên Demo (Demo Test Checklist)
- [ ] Chạy EA trên tài khoản Demo ít nhất **2 tuần** để theo dõi hoạt động thực tế.
- [ ] Kiểm tra xem các rổ lệnh có đóng hoàn toàn vào lúc **23:45 Thứ 6** hay không.
- [ ] Xác nhận không có bất kỳ lệnh giao dịch nào được khớp vào cuối tuần hoặc khi thị trường đóng cửa.
- [ ] Kiểm tra xem nhật ký `GiaCat_Audit_Log.csv` và `GiaCat_Audit_Log.json` có ghi chép đúng các sự kiện mở/DCA/trim hay không.

## 📈 2. Quy Trình Kiểm Thử Strategy Tester (Strategy Tester Checklist)
- [ ] Chạy Backtest với phương thức `Every tick based on real ticks` (Đặc biệt để kiểm tra giãn spread và trượt giá).
- [ ] Chạy thử kịch bản sụt giảm tài khoản để kiểm chứng mức cắt lỗ **Force Cut** tại 40% Drawdown hoạt động chính xác.
- [ ] Xác nhận hệ số nhân lot của DCA không vượt quá **1.25x** ở bất kỳ tầng dca nào.

## 🖥️ 3. Quy Trình VPS (VPS Checklist)
- [ ] Sử dụng VPS có thời gian phản hồi (latency) tới máy chủ broker **dưới 10ms**.
- [ ] VPS có tỷ lệ uptime tối thiểu là **99.9%** và có cấu hình tự khởi động MT5 cùng Windows khi VPS reboot.
- [ ] Đã tắt tính năng tự động Windows Update trên VPS để tránh tình trạng reboot ngoài kiểm soát.

## 📥 4. Quy Trình Cấu Hình MT5 Terminal (MT5 Terminal Checklist)
- [ ] Copy file `.env` (hoặc `GiaCat_env.txt`) chứa cấu hình bảo mật vào đúng thư mục `MQL5/Files/` của Terminal.
- [ ] Bật tính năng **Allow Algorithmic Trading** trên thanh công cụ và trong menu Options.
- [ ] Thêm đường dẫn `https://api.telegram.org` vào danh sách **Allow WebRequest for listed URL** (nếu dùng Telegram).
- [ ] Cài đặt đầy đủ các indicator (`SuperTrend.ex5`, `GiaCatCoin_Indi.ex5`) vào thư mục `MQL5/Indicators`.
- [ ] Cài đặt file AI (`trend_detector.onnx`) vào thư mục `MQL5/Files`.

## ⚡ 5. Kiểm Tra Phản Ứng Spread & Slippage (Spread/Slippage Checklist)
- [ ] Kiểm tra xem EA có tự động chặn mở rổ lệnh mới khi spread bị giãn mạnh (lúc mở cửa tuần hoặc chuyển giao phiên) hay không.
- [ ] Xác minh trong nhật ký rằng các lệnh bị trượt giá (Slippage) quá 100 points bị hệ thống cảnh báo hoặc khóa rổ lệnh mới.

## 🛑 6. Kiểm Thử Công Tắc Khẩn Cấp (Kill Switch Test)
- [ ] Mở tab **Global Variables** trong MT5 (phím tắt `F3`) và thay đổi giá trị `GIA_CAT_RUNTIME_MODE` từ `0` (NORMAL) sang `5` (HARD_KILL).
- [ ] Xác nhận EA ngay lập tức đóng sạch toàn bộ các vị thế đang chạy và tự gỡ khỏi biểu đồ chart.

## 🛡️ 7. Kiểm Thử Chế Độ An Toàn (Safe Mode Test)
- [ ] Thay đổi giá trị `GIA_CAT_RUNTIME_MODE` sang `1` (SAFE_MODE).
- [ ] Xác nhận khối lượng lệnh DCA tiếp theo tự động giảm còn 40% so với thông thường và khoảng cách lưới được giãn gấp đôi.

## 📅 8. Kiểm Thử Đóng Lệnh Thứ Sáu (Friday Close Test)
- [ ] Theo dõi biểu đồ lúc 18:00 Thứ 6 (giờ broker) và xác nhận EA dừng mở rổ mới (`NO_NEW_BASKET`).
- [ ] Theo dõi biểu đồ lúc 23:45 Thứ 6 và xác nhận tất cả vị thế âm/dương đều bị tất toán sạch sẽ.

## 📰 9. Kiểm Thử Lọc Tin Tức (News Blackout Test)
- [ ] Kiểm tra xem EA có tự động khóa mở lệnh trước giờ công bố tin tức mạnh (như CPI, FOMC, NFP) 30 phút và mở lại sau đó 30 phút hay không.
- [ ] Kiểm tra tệp tin log xem có xuất hiện lý do dừng giao dịch: `"Tin quan trong ... vao luc ..."` hay không.

## 🔄 10. Kiểm Thử Chỉ Thu Hồi (Recovery-Only Test)
- [ ] Kích hoạt chế độ `RECOVERY_ONLY` bằng cách thay đổi giá trị `GIA_CAT_RUNTIME_MODE` sang `2`.
- [ ] Xác nhận rổ lệnh hiện tại vẫn tiếp tục DCA và chốt lời bình thường, nhưng sau khi chốt lời rổ hiện tại, EA **không mở thêm bất kỳ rổ lệnh mới nào**.
