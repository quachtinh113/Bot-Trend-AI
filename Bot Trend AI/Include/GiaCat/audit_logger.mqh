#ifndef AUDIT_LOGGER_MQH
#define AUDIT_LOGGER_MQH

// === CẤU HÌNH AUDIT & TELEMETRY LOGGER (GHI NHẬT KÝ ĐỒNG BỘ) ===

class CAuditLogger {
private:
   string m_csv_filename;
   string m_json_filename;
   
   // Kiểm tra xem file đã tồn tại chưa để viết Header cho CSV
   bool FileExists(string filename) {
      int handle = FileOpen(filename, FILE_READ|FILE_BIN);
      if(handle != INVALID_HANDLE) {
         FileClose(handle);
         return true;
      }
      return false;
   }

   // Tạo Header cho file CSV nếu chưa tồn tại
   void CheckAndCreateHeaders() {
      if(!FileExists(m_csv_filename)) {
         int handle = FileOpen(m_csv_filename, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
         if(handle != INVALID_HANDLE) {
            FileWrite(handle, 
               "Timestamp", 
               "EventType", 
               "Regime", 
               "ATR_H1", 
               "ADX_H1", 
               "Spread", 
               "FloatingDD_Pct", 
               "MarginLevel", 
               "BasketAgeSeconds", 
               "ReasonCode"
            );
            FileClose(handle);
         }
      }
      
      // Khởi tạo file JSON nếu chưa tồn tại (tạo file rỗng hoặc mảng trống)
      if(!FileExists(m_json_filename)) {
         int handle = FileOpen(m_json_filename, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
         if(handle != INVALID_HANDLE) {
            // Chúng ta ghi định dạng JSON Lines (mỗi dòng là một JSON object độc lập)
            // để tối ưu tốc độ ghi đè, ghi nối đuôi (append) không bị gián đoạn hoặc lỗi cú pháp
            FileClose(handle);
         }
      }
   }

public:
   // Constructor
   CAuditLogger() :
      m_csv_filename("GiaCat_Audit_Log.csv"),
      m_json_filename("GiaCat_Audit_Log.json") {}

   // Hàm ghi Log chi tiết một sự kiện giao dịch
   void LogEvent(string eventType,          // Loại sự kiện (ENTRY, DCA, TRIM, EMERGENCY_ACTION, CLOSE)
                 string regimeName,         // Tên trạng thái thị trường (Trending, Ranging, Transition)
                 double atrVal,             // Giá trị ATR H1 hiện tại
                 double adxVal,             // Giá trị ADX H1 hiện tại
                 int spreadVal,             // Giá trị spread hiện tại (points)
                 double floatingDDPct,      // % sụt giảm tài khoản hiện tại
                 double marginLevelVal,     // Mức margin level hiện tại (%)
                 long basketAgeSeconds,     // Tuổi rổ lệnh (giây)
                 string reasonCode)         // Mã lý do (ví dụ: "DCA Spacing Triggered", "Manual Friday Close") 
   {
      CheckAndCreateHeaders();
      
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      
      // 1. GHI VÀO FILE CSV
      int csv_handle = FileOpen(m_csv_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
      if(csv_handle != INVALID_HANDLE) {
         FileSeek(csv_handle, 0, SEEK_END);
         FileWrite(csv_handle, 
            timestamp, 
            eventType, 
            regimeName, 
            DoubleToString(atrVal, 5), 
            DoubleToString(adxVal, 2), 
            IntegerToString(spreadVal), 
            DoubleToString(floatingDDPct, 2), 
            DoubleToString(marginLevelVal, 2), 
            IntegerToString(basketAgeSeconds), 
            reasonCode
         );
         FileClose(csv_handle);
      } else {
         Print("GiaCat AuditLogger: Khong the mo file CSV de ghi log!");
      }
      
      // 2. GHI VÀO FILE JSON (Định dạng JSON Lines)
      int json_handle = FileOpen(m_json_filename, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(json_handle != INVALID_HANDLE) {
         FileSeek(json_handle, 0, SEEK_END);
         
         // Tạo chuỗi JSON object thủ công
         string json_record = StringFormat(
            "{\"timestamp\":\"%s\",\"event_type\":\"%s\",\"regime\":\"%s\",\"atr_h1\":%.5f,\"adx_h1\":%.2f,\"spread\":%d,\"floating_dd_pct\":%.2f,\"margin_level\":%.2f,\"basket_age_sec\":%d,\"reason_code\":\"%s\"}",
            timestamp, 
            eventType, 
            regimeName, 
            atrVal, 
            adxVal, 
            spreadVal, 
            floatingDDPct, 
            marginLevelVal, 
            basketAgeSeconds, 
            reasonCode
         );
         
         FileWrite(json_handle, json_record);
         FileClose(json_handle);
      } else {
         Print("GiaCat AuditLogger: Khong the mo file JSON de ghi log!");
      }
   }
};

#endif
