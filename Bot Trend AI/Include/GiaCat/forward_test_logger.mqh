#ifndef FORWARD_TEST_LOGGER_MQH
#define FORWARD_TEST_LOGGER_MQH

// === CẤU HÌNH FORWARD TEST LOGGER (GIÁM SÁT VẬN HÀNH 24/7) ===

class CForwardTestLogger {
private:
   string   m_symbol;
   datetime m_start_time;              // Thời gian khởi chạy EA
   int      m_disconnect_count;        // Số lần ngắt kết nối mạng
   bool     m_last_connect_status;     // Trạng thái kết nối vòng trước
   int      m_max_spread_recorded;     // Spread lớn nhất ghi nhận được (points)
   int      m_mode_change_count;       // Số lần chuyển đổi trạng thái EA
   int      m_last_runtime_mode;       // Chế độ runtime vòng trước
   double   m_last_survival_score;     // Điểm sinh tồn vòng trước
   datetime m_last_report_time;        // Lần cuối xuất báo cáo ngày

public:
   // Constructor
   CForwardTestLogger() :
      m_symbol(""),
      m_start_time(0),
      m_disconnect_count(0),
      m_last_connect_status(true),
      m_max_spread_recorded(0),
      m_mode_change_count(0),
      m_last_runtime_mode(0),
      m_last_survival_score(100.0),
      m_last_report_time(0) {}

   // Khởi tạo Logger
   void Init(string symbol) {
      m_symbol = symbol;
      m_start_time = TimeCurrent();
      m_last_report_time = TimeCurrent();
      m_last_connect_status = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      m_max_spread_recorded = (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      
      Print(StringFormat("GiaCat ForwardLogger: Khởi chạy giám sát 24/7 cho %s lúc %s", 
                         m_symbol, TimeToString(m_start_time, TIME_DATE|TIME_SECONDS)));
   }

   // Hàm cập nhật trạng thái thời gian thực (gọi mỗi Tick hoặc Timer)
   void Update(int currentSpread, int currentMode, double currentScore) {
      datetime timeCur = TimeCurrent();
      
      // 1. Giám sát kết nối Internet (Connection status monitoring)
      bool isConnected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      if(isConnected != m_last_connect_status) {
         if(!isConnected) {
            m_disconnect_count++;
            Print("GiaCat ForwardLogger: [WARNING] Mất kết nối internet tới máy chủ Broker!");
         } else {
            Print("GiaCat ForwardLogger: Kết nối internet đã được khôi phục.");
         }
         m_last_connect_status = isConnected;
      }

      // 2. Giám sát biến động Spread đột ngột
      if(currentSpread > m_max_spread_recorded) {
         m_max_spread_recorded = currentSpread;
      }

      // 3. Giám sát thay đổi trạng thái EA (Runtime Mode Transitions)
      if(currentMode != m_last_runtime_mode) {
         m_mode_change_count++;
         m_last_runtime_mode = currentMode;
         Print(StringFormat("GiaCat ForwardLogger: Thay đổi chế độ Runtime sang: %d", currentMode));
      }

      // 4. Lưu điểm sinh tồn
      m_last_survival_score = currentScore;

      // 5. Tự động xuất báo cáo hàng ngày (24 giờ một lần)
      if(timeCur - m_last_report_time >= 86400) {
         WriteDailyReport();
         m_last_report_time = timeCur;
         m_max_spread_recorded = currentSpread; // Reset spread max cho ngày mới
      }
   }

   // Lấy thời gian chạy liên tục (Uptime)
   long GetUptimeSeconds() {
      return (long)(TimeCurrent() - m_start_time);
   }

   // Hàm xuất báo cáo ngày (Daily Report) ra các tệp JSON và MD
   void WriteDailyReport() {
      long uptime = GetUptimeSeconds();
      double uptime_hours = (double)uptime / 3600.0;
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
      
      // GHI BÁO CÁO MD (daily_forward_report.md)
      int md_handle = FileOpen("daily_forward_report.md", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(md_handle != INVALID_HANDLE) {
         FileWrite(md_handle, "# Báo Cáo Vận Hành Thử Nghiệm 24/7 (Daily Forward Report)");
         FileWrite(md_handle, StringFormat("> Ngày báo cáo: **%s**", timestamp));
         FileWrite(md_handle, "");
         FileWrite(md_handle, "## 📊 THÔNG SỐ VẬN HÀNH THỰC TẾ");
         FileWrite(md_handle, StringFormat("- **Thời gian chạy liên tục (Uptime):** `%.2f giờ`", uptime_hours));
         FileWrite(md_handle, StringFormat("- **Số lần gián đoạn kết nối:** `%d lần`", m_disconnect_count));
         FileWrite(md_handle, StringFormat("- **Mức giãn Spread lớn nhất:** `%d points`", m_max_spread_recorded));
         FileWrite(md_handle, StringFormat("- **Số lần thay đổi trạng thái EA:** `%d lần`", m_mode_change_count));
         FileWrite(md_handle, StringFormat("- **Điểm số sinh tồn hiện tại:** `%.1f/100.0`", m_last_survival_score));
         FileWrite(md_handle, StringFormat("- **Kết nối hiện tại:** `%s`", m_last_connect_status ? "ONLINE" : "OFFLINE"));
         FileWrite(md_handle, "");
         FileWrite(md_handle, "## 🛠️ ĐÁNH GIÁ ĐỘ ỔN ĐỊNH RUNTIME");
         if(m_disconnect_count > 5) {
            FileWrite(md_handle, "> [!WARNING]");
            FileWrite(md_handle, "> **KẾT NỐI MẠNG KÉM ỔN ĐỊNH.** Phát hiện nhiều lần rớt kết nối mạng trong ngày. Vui lòng kiểm tra đường truyền mạng hoặc liên hệ bên cung cấp VPS.");
         } else {
            FileWrite(md_handle, "> [!TIP]");
            FileWrite(md_handle, "> **HỆ THỐNG VẬN HÀNH ỔN ĐỊNH.** Tỷ lệ uptime cao và số lần ngắt mạng ở mức tối thiểu.");
         }
         FileClose(md_handle);
      }

      // GHI BÁO CÁO JSON (daily_forward_report.json)
      int json_handle = FileOpen("daily_forward_report.json", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(json_handle != INVALID_HANDLE) {
         string json_content = StringFormat(
            "{\n"
            "  \"report_time\": \"%s\",\n"
            "  \"uptime_hours\": %.2f,\n"
            "  \"disconnect_count\": %d,\n"
            "  \"max_spread_points\": %d,\n"
            "  \"mode_changes\": %d,\n"
            "  \"last_survival_score\": %.2f,\n"
            "  \"is_online\": %s\n"
            "}",
            timestamp,
            uptime_hours,
            m_disconnect_count,
            m_max_spread_recorded,
            m_mode_change_count,
            m_last_survival_score,
            m_last_connect_status ? "true" : "false"
         );
         FileWrite(json_handle, json_content);
         FileClose(json_handle);
      }
   }
};

#endif
