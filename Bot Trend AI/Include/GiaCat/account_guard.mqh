#ifndef ACCOUNT_GUARD_MQH
#define ACCOUNT_GUARD_MQH

// === CẤU HÌNH ACCOUNT SAFETY GUARD (KIỂM SOÁT TÀI KHOẢN VÀ KÝ QUỸ) ===

// Các trạng thái xác thực tài khoản
enum ENUM_GUARD_STATE {
   ACCOUNT_OK = 0,               // Tài khoản hợp lệ, an toàn
   ACCOUNT_MISMATCH = 1,         // Sai số tài khoản giao dịch
   REAL_TRADING_BLOCKED = 2,     // Chặn giao dịch tài khoản thực (ALLOW_REAL_TRADING=false)
   MARGIN_UNSAFE = 3,            // Mức ký quỹ không an toàn
   SERVER_MISMATCH = 4           // Sai máy chủ giao dịch (Broker Server)
};

class CAccountGuard {
private:
   // Cấu hình đọc từ .env
   long     m_env_login;
   string   m_env_server;
   string   m_env_mode;          // "DEMO" hoặc "REAL"
   bool     m_allow_real;        // true/false
   
   // Các biến mặt nạ dùng cho logging bảo mật
   string   m_masked_login;
   string   m_masked_token;

   // Hàm loại bỏ khoảng trắng thừa
   string StringTrim(string text) {
      // MQL5 có sẵn hàm StringTrimLeft và StringTrimRight
      StringTrimLeft(text);
      StringTrimRight(text);
      return text;
   }

   // Hàm loại bỏ dấu nháy đơn/kép bao quanh giá trị
   string CleanQuotes(string text) {
      text = StringTrim(text);
      int len = StringLen(text);
      if(len >= 2) {
         if((StringSubstr(text, 0, 1) == "\"" && StringSubstr(text, len - 1, 1) == "\"") ||
            (StringSubstr(text, 0, 1) == "'" && StringSubstr(text, len - 1, 1) == "'")) {
            return StringSubstr(text, 1, len - 2);
         }
      }
      return text;
   }

   // Mã hóa số tài khoản để in log bảo mật
   string MaskLoginValue(long login) {
      string s = IntegerToString(login);
      if(StringLen(s) <= 8) {
         return StringSubstr(s, 0, 2) + "****" + StringSubstr(s, StringLen(s) - 2);
      }
      return StringSubstr(s, 0, 4) + "****" + StringSubstr(s, StringLen(s) - 4);
   }

   // Mã hóa Token Telegram để in log bảo mật
   string MaskTelegramToken(string token) {
      if(StringLen(token) <= 10) return "******";
      return StringSubstr(token, 0, 6) + "******" + StringSubstr(token, StringLen(token) - 4);
   }

public:
   // Constructor
   CAccountGuard() :
      m_env_login(0),
      m_env_server(""),
      m_env_mode("DEMO"),
      m_allow_real(false),
      m_masked_login("[NOT_LOADED]"),
      m_masked_token("[NOT_LOADED]") {}

   // Đọc và phân tích tệp .env hoặc GiaCat_env.txt từ thư mục MQL5/Files
   bool LoadEnvConfig(string &telegramToken, string &telegramChatID) {
      telegramToken = "";
      telegramChatID = "";
      
      // Mở file cấu hình
      int file_handle = FileOpen(".env", FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(file_handle == INVALID_HANDLE) {
         // Fallback sang tên file .txt thông thường phòng trường hợp MT5 không nhận file ẩn .env
         file_handle = FileOpen("GiaCat_env.txt", FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      }

      if(file_handle == INVALID_HANDLE) {
         Print("GiaCat AccountGuard: [WARNING] Khong thay file cấu hinh .env hoac GiaCat_env.txt trong MQL5/Files!");
         return false;
      }

      while(!FileIsEnding(file_handle)) {
         string line = FileReadString(file_handle);
         
         // Loại bỏ phần comment bắt đầu bằng dấu #
         int hash_pos = StringFind(line, "#");
         if(hash_pos >= 0) {
            line = StringSubstr(line, 0, hash_pos);
         }
         
         line = StringTrim(line);
         if(StringLen(line) == 0) continue;

         // Tìm dấu gán =
         int eq_pos = StringFind(line, "=");
         if(eq_pos <= 0) continue;

         string key = StringSubstr(line, 0, eq_pos);
         string val = StringSubstr(line, eq_pos + 1);

         key = StringTrim(key);
         val = CleanQuotes(val);

         if(key == "MT5_LOGIN") {
            m_env_login = StringToInteger(val);
            m_masked_login = MaskLoginValue(m_env_login);
         }
         else if(key == "MT5_SERVER") {
            m_env_server = val;
         }
         else if(key == "ENV_MODE") {
            m_env_mode = val;
            StringToUpper(m_env_mode);
         }
         else if(key == "ALLOW_REAL_TRADING") {
            m_allow_real = (val == "true" || val == "1");
         }
         else if(key == "TELEGRAM_BOT_TOKEN") {
            telegramToken = val;
            m_masked_token = MaskTelegramToken(val);
         }
         else if(key == "TELEGRAM_CHAT_ID") {
            telegramChatID = val;
         }
      }

      FileClose(file_handle);
      Print("GiaCat AccountGuard: Đọc file cấu hinh an toan thanh cong.");
      Print("-> Logged Account Masked  : ", m_masked_login);
      Print("-> Configured Server      : ", m_env_server);
      Print("-> Execution Env Mode     : ", m_env_mode);
      Print("-> Allow Real Money Trading: ", m_allow_real ? "TRUE" : "FALSE");
      return true;
   }

   // Hàm xác thực tính an toàn của tài khoản hiện tại
   ENUM_GUARD_STATE VerifyAccount(string &errorMsg) {
      long active_login = AccountInfoInteger(ACCOUNT_LOGIN);
      string active_server = AccountInfoString(ACCOUNT_SERVER);
      ENUM_ACCOUNT_TRADE_MODE trade_mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
      
      // 1. Kiểm tra khớp số tài khoản (MT5 Login verification)
      if(m_env_login > 0 && active_login != m_env_login) {
         errorMsg = StringFormat("Sai lech tai khoan: Active=%d vs Env=%d", active_login, m_env_login);
         return ACCOUNT_MISMATCH;
      }

      // 2. Kiểm tra khớp máy chủ giao dịch (Server verification)
      // Sử dụng tìm kiếm chuỗi con để linh hoạt (ví dụ Exness-MT5Trial và Exness-MT5Trial1)
      if(StringLen(m_env_server) > 0 && StringFind(active_server, m_env_server) < 0) {
         errorMsg = StringFormat("Sai lech Server: Active='%s' vs Env='%s'", active_server, m_env_server);
         return SERVER_MISMATCH;
      }

      // 3. Quy tắc bảo vệ tài khoản Thực (Real Account Protection)
      bool isRealAccount = (trade_mode == ACCOUNT_TRADE_MODE_REAL);
      if(isRealAccount) {
         // Nếu cấu hình ENV_MODE chỉ định chạy DEMO nhưng chạy trên tài khoản thật -> VETO!
         if(m_env_mode == "DEMO") {
            errorMsg = "Chan giao dich: Bot dang o che do ENV_MODE=DEMO nhung chay tren TAI KHOAN REAL!";
            return REAL_TRADING_BLOCKED;
         }
         // Nếu chạy tài khoản thật nhưng ALLOW_REAL_TRADING = false -> VETO!
         if(!m_allow_real) {
            errorMsg = "Chan giao dich: Chay tai khoan REAL nhung ALLOW_REAL_TRADING=false!";
            return REAL_TRADING_BLOCKED;
         }
      }

      // 4. Kiểm tra mức ký quỹ an toàn (Margin Safety Check)
      double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(margin_level > 0.0 && margin_level <= 300.0) { // SOFT_BLOCK = 300%
         errorMsg = StringFormat("Ký quy khong an toan: Margin Level = %.2f%% <= 300%%", margin_level);
         return MARGIN_UNSAFE;
      }

      errorMsg = "Tai khoan hop le va an toan.";
      return ACCOUNT_OK;
   }

   // Hàm xác thực nhanh mức cảnh báo/phòng vệ dựa trên Margin Level (Governance Rule 1)
   void CheckMarginThresholds(double marginLevel, bool &warning, bool &softBlock, bool &safeMode, bool &hardKill) {
      warning = false;
      softBlock = false;
      safeMode = false;
      hardKill = false;

      if(marginLevel > 0.0) {
         if(marginLevel <= 180.0) { // HARD_KILL = 180%
            hardKill = true;
            safeMode = true;
            softBlock = true;
         }
         else if(marginLevel <= 250.0) { // SAFE_MODE = 250%
            safeMode = true;
            softBlock = true;
         }
         else if(marginLevel <= 300.0) { // SOFT_BLOCK = 300%
            softBlock = true;
         }
         else if(marginLevel <= 500.0) { // WARNING = 500%
            warning = true;
         }
      }
   }
};

#endif
