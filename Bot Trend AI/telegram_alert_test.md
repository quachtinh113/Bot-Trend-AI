# Ma Trận Kiểm Thử Cảnh Báo Telegram (Telegram Alert Test Matrix)

Tài liệu này dùng để xác thực định dạng và độ tin cậy của hệ thống thông báo Telegram gửi đi từ robot Gia Cat. Do đây là đợt thử nghiệm forward test trên tài khoản demo, toàn bộ các cảnh báo này cần được kiểm thử gửi đi thành công.

---

## 📋 Bảng Kiểm Thử Các Sự Kiện Cảnh Báo

| Kịch Bản Kiểm Thử | Hành Động Kích Hoạt Trong MT5 | Nội Dung Cảnh Báo Kỳ Vọng Gửi Về Telegram | Trạng Thái |
| :--- | :--- | :--- | :---: |
| **1. Kích hoạt SAFE_MODE** | Mở tab *Global Variables* (nhấn F3) -> Sửa `GIA_CAT_RUNTIME_MODE` sang `1`. | ⚠️ **CẢNH BÁO RISK STATE CHANGE**<br>Robot GiaCat vừa chuyển sang trạng thái: **SAFE_MODE**.<br>Lý do: Thay đổi thủ công bằng biến toàn cục.<br>*Hành động: Lot size giảm 60%, giãn khoảng cách lưới 2 lần, tạm dừng mở rổ mới.* | [ ] |
| **2. Kích hoạt HARD_BLOCK** | Đặt spread cố định trong Strategy Tester hoặc gặp lúc spread giãn > 3x trung bình. | 🛑 **CẢNH BÁO HỆ THỐNG GIA CÁT**<br>Trạng thái: **HARD_BLOCK** (Khóa cứng mở rổ lệnh mới).<br>Lý do: Spread giãn nở đột biến vượt ngưỡng (Spread = 150 pts vs Avg = 45 pts). | [ ] |
| **3. Kích hoạt HARD_KILL** | Chỉnh sửa biến toàn cục `GIA_CAT_RUNTIME_MODE` sang `5` HOẶC sút giảm ngày vượt 8%. | 🚨 **BÁO ĐỘNG ĐÓNG KHẨN CẤP (HARD_KILL)**<br>Hệ thống đã thực hiện thanh lý toàn bộ vị thế giao dịch đang có.<br>Lý do: Chạm mức sụt giảm tuần cực đại 8% hoặc lệnh cưỡng chế Kill Switch.<br>*Hành động: Đóng sạch mọi lệnh và tự động gỡ EA khỏi biểu đồ chart.* | [ ] |
| **4. Cảnh báo Ký Quỹ (Margin Warning)** | Vào lệnh khối lượng lớn làm Margin Level tụt xuống dưới 500%. | ⚠️ **CẢNH BÁO KÝ QUỸ YẾU (MARGIN WARNING)**<br>Tài khoản: 4633****0450<br>Mức ký quỹ hiện tại: **450.0%** (Dưới mức khuyến nghị 500%).<br>*Hành động: Gửi thông tin khẩn cấp đến người dùng.* | [ ] |
| **5. Cảnh báo Giãn Spread** | Spread hiện tại lớn hơn `InpMaxSpread = 500 pts`. | ⚠️ **CẢNH BÁO THANH KHOẢN KÉM (SPREAD SPIKE)**<br>Spread hiện tại trên Symbol XAUUSD đang giãn rộng: **550 points**.<br>*Hành động: EA tạm ngưng tất cả hoạt động mở lệnh cho tới khi spread thu hẹp.* | [ ] |
| **6. Cảnh báo Breakout Sớm** | M15 Bollinger Band width co hẹp cực đại và ATR H1 bắt đầu tăng tốc. | 🌪️ **CẢNH BÁO TIÊN ĐOÁN BIẾN ĐỘNG (BREAKOUT WARNING)**<br>Hệ thống phát hiện thị trường đang nén nến mạnh kèm theo sự tăng tốc của ATR.<br>Lý do: BB Width M15 = 0.0008, ATR Acceleration = 12.0 pts.<br>*Hành động: Tạm thời khóa DCA để tránh breakout.* | [ ] |
| **7. Rổ Lệnh Đạt Cấp Độc Terminal** | Giữ rổ lệnh quá 48.0 giờ kèm sụt giảm Drawdown > 15.0%. | 💀 **BÁO ĐỘNG RỔ LỆNH LÂU NĂM (BASKET TERMINAL)**<br>Rổ lệnh cặp EURUSD đã hoạt động vượt quá thời hạn sinh tồn.<br>Tuổi rổ: **52.3 giờ**.<br>Mức âm hiện tại: **-185.00 Cent** (DD = 16.5%).<br>*Hành động: Cấm DCA tiếp tục, kích hoạt Trim Manager để tỉa lệnh giải cứu rổ.* | [ ] |

---

## 🛠️ Quy Trình Gửi Thử Thông Báo (Mock Request Test)

Để kiểm tra định dạng tin nhắn mà không cần đợi sự kiện thực tế xảy ra, bạn có thể gọi trực tiếp hàm của EA trong hàm `OnInit()` để gửi test:

```mql5
// Đoạn mã nhúng tạm thời trong OnInit() của EA để test gửi tin nhắn:
if(InpUseTelegram) {
   string testMsg = "🤖 **GIA CAT TEST ALERT**\nĐầu nối Telegram hoạt động thành công.\nChúc bạn kiểm thử Demo Forward Test thuận lợi!";
   SendTelegramMessage(testMsg); 
}
```

Nếu tin nhắn hiển thị đầy đủ và đẹp mắt trên ứng dụng Telegram của bạn, bài test được xác nhận là **PASS**.
