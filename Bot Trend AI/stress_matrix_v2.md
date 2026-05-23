# Ma Trận Kiểm Thử Căng Thẳng (Stress Test Matrix V2) — Gia Cat Quant V2

Tài liệu này cung cấp các kịch bản mô phỏng đa chiều để kiểm chứng sự hoạt động của **Gia Cat Quant Survival Engine (V2)** trên trình giả lập Strategy Tester của MetaTrader 5. Khác với phiên bản V1, V2 tập trung kiểm thử các rủi ro liên thị trường (portfolio-wide), sự sụt giảm thanh khoản và các thay đổi trong mối tương quan tài sản.

---

## 📊 Bảng Ma Trận Các Kịch Bản Cực Đoan

| Kịch Bản | Yếu Tố Kích Hoạt (Shocks) | Cơ Chế Phòng Ngự Kỳ Vọng | Tiêu Chí Kiểm Thử Đạt (Pass Criteria) |
| :--- | :--- | :--- | :--- |
| **1. Correlation Breakdown**<br>*(Đứt gãy tương quan)* | EURUSD Buy và USDCHF Buy đồng loạt tăng khối lượng (mất tính tương quan nghịch mặc định). | `CPortfolioEngine` phát hiện tổng khối lượng tương quan nghịch bị phá vỡ, kích hoạt **Scale Down** (giảm lot 30-50% cho các lệnh mới). | Khối lượng các lệnh tiếp theo của cả hai cặp tự động giảm đi rõ rệt để bảo vệ tài khoản khỏi rủi ro tập trung. |
| **2. Volatility Compression Shock**<br>*(Bung nén Breakout)* | Bollinger Band Width M15 < 0.0010 (nén rất chặt) -> Sau đó có tin chạy mạnh quét 300 pips. | `CPredictiveVolatility` nhận diện nén BB và phát tín hiệu **Breakout Warning** -> Khóa mở DCA mới trước khi giá chạy, giãn cách lưới 2.0x. | EA không nhồi DCA ở các mức giá bất lợi đầu sóng. Chờ giá ổn định mới mở DCA tiếp theo. |
| **3. Liquidity Vacuum**<br>*(Tin bão quét sạch thanh khoản)* | Spread giãn nở từ 20 points lên 150 points trong 10 ticks, tần suất tick giảm xuống còn < 3 ticks/5s. | `CPredictiveVolatility` phát hiện **Liquidity Vacuum** -> Kích hoạt **HARD_BLOCK** ngăn mở rổ lệnh mới. | Không có vị thế mới nào được mở trong thời điểm thanh khoản rỗng. Tránh hoàn toàn việc trượt giá (slippage) xấu. |
| **4. Global Margin Concentration Squeeze**<br>*(Kẹt ký quỹ toàn cục)* | Nhiều rổ lệnh trên các cặp tiền khác nhau hoạt động cùng lúc -> Tổng Ký quỹ sử dụng vượt quá 15% vốn tài khoản. | `CPortfolioEngine` và `CSurvivalScoreEngine` kích hoạt **SAFE_MODE** -> Block mở rổ mới, chuyển toàn bộ EA sang chế độ chỉ thu hồi (recovery). | Ngăn chặn việc mở thêm cặp tiền mới khi danh mục đang gánh khối lượng lớn. Bảo vệ an toàn tuyệt đối Margin Call. |
| **5. Multi-Day Aging Squeeze**<br>*(Rổ lệnh bị giam giữ dài ngày)* | Rổ lệnh EURUSD bị giam giữ vượt quá **48.0 giờ** và Drawdown hiện tại >= 15.0%. | `CBasketIntelligence` đánh giá trạng thái là **BASKET_TERMINAL** -> Kích hoạt **Emergency Trim** và cấm DCA. | EA dừng nhồi lệnh DCA. Trim Manager sử dụng tiền lãi từ các giao dịch ngắn hạn khác để tỉa bớt phần lệnh lỗ của rổ bị kẹt. |
| **6. Weekly Drawdown Thresholds**<br>*(Chạm giới hạn tuần theo Equity)* | Vốn tài khoản bị sụt giảm theo thứ tự: 3%, 5%, và 8% so với vốn đầu tuần (Weekly Starting Equity). | `CSurvivalScoreEngine` hạ điểm sinh tồn và thực thi:<br>- Âm 3%: **SOFT_BLOCK**<br>- Âm 5%: **SAFE_MODE**<br>- Âm 8%: **HARD_KILL** và dừng giao dịch. | EA tự động đóng sạch toàn bộ lệnh khi chạm mức âm 8% vốn đầu tuần, gọi hàm `ExpertRemove()` để dừng chạy. |

---

## 🛠️ Hướng Dẫn Thiết Lập Kiểm Thử

Để chạy các kịch bản này trên MT5 Strategy Tester:
1. **Thiết lập đứt gãy tương quan (Kịch bản 1):** Chọn chạy Strategy Tester chế độ **Multi-symbol** (nếu sàn EXNESS hỗ trợ test nhiều cặp). Khai báo chạy EA đồng thời trên cả EURUSD và USDCHF.
2. **Thiết lập nén Volatility (Kịch bản 2):** Chọn khoảng thời gian thị trường đi ngang dài trước các đợt phát biểu lớn (ví dụ: Tin FOMC lúc 1:00 AM) để kiểm tra xem cảnh báo Breakout có được bật trước khi tin ra không.
3. **Thiết lập kiểm tra sụt giảm tuần (Kịch bản 6):** Sử dụng tính năng nạp vốn ảo nhỏ trên Strategy Tester và ép rổ lệnh đi ngược xu hướng để đo lường chính xác các mức sụt giảm Equity đầu tuần:
   - Xác nhận log ghi nhận `SOFT_BLOCK` khi âm 3% equity đầu tuần.
   - Xác nhận log ghi nhận `SAFE_MODE` khi âm 5% equity đầu tuần.
   - Xác nhận toàn bộ vị thế bị thanh lý và EA tự gỡ khỏi biểu đồ khi âm 8% equity đầu tuần.
