# Quy Trình Thiết Lập Hệ Thống Chạy 24/7 Trên PC (PC Runtime Checklist)

Tài liệu này hướng dẫn cách cấu hình hệ điều hành Windows và phần mềm MetaTrader 5 trên máy tính cá nhân để đảm bảo robot hoạt động liên tục 24/7 ổn định, không bị ngắt quãng do chế độ ngủ (sleep) hoặc tự động cập nhật hệ thống.

---

## 💻 1. Cấu Hình Hệ Điều Hành Windows (OS Hardening)

### 🚫 Tắt Chế Độ Ngủ (Disable Sleep & Hibernate)
Windows mặc định sẽ tự động chuyển sang chế độ ngủ sau một khoảng thời gian không tương tác. Bạn cần tắt hoàn toàn:
- Mở PowerShell bằng quyền Administrator và chạy lệnh sau để tắt Hibernate:
  `powercfg -h off`
- Thay đổi thiết lập Power Plan sang **High Performance**:
  - Vào *Control Panel -> Power Options -> Chọn High Performance*.
  - Nhấp vào *Change plan settings* -> Chọn **Never** ở các mục *Turn off the display* và *Put the computer to sleep*.

### 🚫 Tắt USB Selective Suspend
Tính năng này có thể ngắt nguồn các cổng USB/thiết bị ngoại vi gây mất kết nối mạng (nếu dùng USB Wifi/Ethernet):
- Trong mục *Change plan settings* -> Chọn *Change advanced power settings*.
- Tìm tới mục *USB settings -> USB selective suspend setting* -> Chuyển thành **Disabled**.

### 🚫 Ngăn Windows Update Tự Động Khởi Động Lại Máy (Block Auto-Reboot)
Windows Update tự động tải bản vá và reboot máy là nguyên nhân hàng đầu gây sập EA chạy trên PC:
- **Cách 1 (Group Policy - Windows Pro/Enterprise):**
  - Nhấn `Win + R`, nhập `gpedit.msc` và nhấn Enter.
  - Tìm đường dẫn: *Computer Configuration -> Administrative Templates -> Windows Components -> Windows Update -> Legacy Policies* (hoặc *Manage end user experience*).
  - Bật tính năng: **No auto-restart with logged on users for scheduled automatic updates installations** -> Chọn **Enabled**.
- **Cách 2 (Services):**
  - Nhấn `Win + R`, nhập `services.msc` và nhấn Enter.
  - Tìm service **Windows Update** -> Nhấp đúp -> Chuyển *Startup type* thành **Manual** hoặc **Disabled** (Lưu ý: Bạn phải tự cập nhật thủ công định kỳ vào cuối tuần để đảm bảo bảo mật).

---

## 📊 2. Cấu Hình MetaTrader 5 Terminal (MT5 Hardening)

### 🔑 Tự Động Đăng Nhập Lại (Auto-Login Verification)
- Khi mở MT5, hãy chắc chắn đã tích chọn ô **Keep personal settings** (hoặc **Save password**) khi điền thông tin đăng nhập tài khoản demo.
- Kiểm tra xem MT5 có tự động đăng nhập thành công khi tắt đi bật lại phần mềm hay không.

### 🕒 Đồng Bộ Hóa Thời Gian Hệ Thống (Clock Synchronization)
Sai lệch thời gian trên PC có thể làm sai lệch logic lọc tin tức News Blackout:
- Vào *Settings -> Time & Language -> Date & time*.
- Nhấp vào nút **Sync now** trong mục *Synchronize your clock* để đồng bộ với máy chủ thời gian `time.windows.com`.

### 🔄 Tự Khởi Động MT5 Khi PC Khởi Động (Startup Recovery)
Đề phòng trường hợp PC bị mất điện đột ngột hoặc tự khởi động lại:
- Nhấn `Win + R`, nhập `shell:startup` và nhấn Enter. Thư mục Startup của Windows sẽ mở ra.
- Tạo một Shortcut của phần mềm **MetaTrader 5 EXNESS** (hoặc terminal bạn dùng) và kéo thả vào thư mục Startup này. Khi Windows khởi động, MT5 sẽ tự chạy.

---

## 🧹 3. Dọn Dẹp Nhật Ký & Tài Nguyên Đĩa (Maintenance & Space)

### 🧹 Dọn dẹp Logs Terminal (Journal Cleanup)
Nhật ký của MT5 (Journal) có thể phình to lên tới hàng chục GB sau thời gian dài chạy tick liên tục:
- Định kỳ vào cuối tuần, mở MT5 -> Vào tab *Journal* -> Nhấp chuột phải -> Chọn *Open* để mở thư mục log của terminal.
- Xóa các tệp tin log cũ (các tuần trước đó) để giải phóng dung lượng đĩa cứng.

### 💽 Kiểm Tra Dung Lượng Bộ Nhớ Đĩa Trống (Disk Space Monitoring)
- Đảm bảo ổ đĩa cài đặt MT5 và lưu trữ data (thường là ổ C:) luôn còn trống tối thiểu **10 GB** dung lượng để ghi file log và tệp tin telemetry.
