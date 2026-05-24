#ifndef RUNTIME_CONTROL_MQH
#define RUNTIME_CONTROL_MQH

// === CẤU HÌNH RUNTIME CONTROL (HỆ THỐNG KÌM CƯƠNG PHÒNG VỆ) ===

// Định nghĩa các chế độ chạy Runtime
enum ENUM_RUNTIME_MODE {
   RUN_NORMAL = 0,             // Vận hành bình thường theo thuật toán
   RUN_SAFE_MODE = 1,          // Chế độ an toàn (Giảm lot, giãn grid)
   RUN_RECOVERY_ONLY = 2,      // Chế độ chỉ thu hồi (Không mở rổ mới)
   RUN_NO_NEW_BASKET = 3,      // Tạm ngưng mở rổ mới (Vẫn cho phép DCA rổ cũ)
   RUN_CLOSE_ALL = 4,          // Đóng toàn bộ các vị thế đang chạy lập tức
   RUN_HARD_KILL = 5           // Đóng sạch vị thế và gỡ EA khỏi đồ thị
};

class CRuntimeControl {
private:
   string   m_symbol;
   string   m_gv_key;          // Tên biến toàn cục của Terminal (Global Variable)
   string   m_control_file;    // Đường dẫn tệp điều khiển cục bộ (MQL5/Files)

   // Đọc chế độ điều khiển từ tệp control file cục bộ nếu có
   int ReadControlFile() {
      int file_handle = FileOpen(m_control_file, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
      if(file_handle != INVALID_HANDLE) {
         string content = FileReadString(file_handle);
         FileClose(file_handle);
         
         StringTrimLeft(content);
         StringTrimRight(content);
         
         // Phân tích cú pháp chế độ
         if(content == "NORMAL") return RUN_NORMAL;
         if(content == "SAFE_MODE") return RUN_SAFE_MODE;
         if(content == "RECOVERY_ONLY") return RUN_RECOVERY_ONLY;
         if(content == "NO_NEW_BASKET") return RUN_NO_NEW_BASKET;
         if(content == "CLOSE_ALL") return RUN_CLOSE_ALL;
         if(content == "HARD_KILL") return RUN_HARD_KILL;
         
         // Hoặc ở định dạng số
         int mode_num = (int)StringToInteger(content);
         if(mode_num >= 0 && mode_num <= 5) {
            return mode_num;
         }
      }
      return -1; // Không tồn tại tệp hoặc nội dung không hợp lệ
   }

public:
   // Constructor
   CRuntimeControl() :
      m_symbol(""),
      m_gv_key("GIA_CAT_RUNTIME_MODE"),
      m_control_file("GiaCat_Control.txt") {}

   // Khởi tạo Runtime Control
   void Init(string symbol) {
      m_symbol = symbol;
      
      // Nếu biến toàn cục chưa tồn tại, khởi tạo mặc định là RUN_NORMAL (0)
      if(!GlobalVariableCheck(m_gv_key)) {
         GlobalVariableSet(m_gv_key, (double)RUN_NORMAL);
      }
   }

   // Hàm lấy Chế độ Runtime hiện tại (kết hợp cả Global Variable và Control File)
   ENUM_RUNTIME_MODE GetRuntimeMode() {
      // 1. Kiểm tra Global Variable trước (được ưu tiên)
      double gv_val = GlobalVariableGet(m_gv_key);
      ENUM_RUNTIME_MODE activeMode = (ENUM_RUNTIME_MODE)((int)gv_val);
      
      // 2. Kiểm tra tệp điều khiển cục bộ (dùng làm cơ chế override thủ công)
      int file_mode = ReadControlFile();
      if(file_mode != -1) {
         activeMode = (ENUM_RUNTIME_MODE)file_mode;
         
         // Đồng bộ giá trị vào Global Variable để đồng nhất trạng thái
         GlobalVariableSet(m_gv_key, (double)file_mode);
         
         // Xóa tệp điều khiển sau khi đọc để tránh lặp lại hoặc xóa override nếu muốn dùng GV làm mặc định
         // Thường ta giữ nguyên để người dùng chỉnh sửa file, nhưng có thể xóa nếu cần một lệnh một lần (One-shot)
         // Ở đây chúng ta giữ lại tệp để người dùng có thể duy trì cấu hình qua file txt.
      }
      
      // Đảm bảo chế độ trả về hợp lệ trong biên độ [0, 5]
      if(activeMode < RUN_NORMAL || activeMode > RUN_HARD_KILL) {
         activeMode = RUN_NORMAL;
      }
      
      return activeMode;
   }

   // Hàm thay đổi Chế độ Runtime thủ công/tự động bằng mã nguồn
   void SetRuntimeMode(ENUM_RUNTIME_MODE mode) {
      GlobalVariableSet(m_gv_key, (double)mode);
      Print("GiaCat RuntimeControl: Đã thay đổi trạng thái hoạt động sang: ", EnumToString(mode));
   }

   // Chuyển đổi tên Enum sang dạng String thân thiện để in Log
   string GetModeName(ENUM_RUNTIME_MODE mode) {
      switch(mode) {
         case RUN_NORMAL:        return "NORMAL";
         case RUN_SAFE_MODE:     return "SAFE_MODE";
         case RUN_RECOVERY_ONLY: return "RECOVERY_ONLY";
         case RUN_NO_NEW_BASKET: return "NO_NEW_BASKET";
         case RUN_CLOSE_ALL:     return "CLOSE_ALL";
         case RUN_HARD_KILL:     return "HARD_KILL";
      }
      return "UNKNOWN";
   }
};

#endif
