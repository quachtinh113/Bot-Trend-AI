#ifndef EQUITY_DEFENSE_MQH
#define EQUITY_DEFENSE_MQH

// === CẤU HÌNH EQUITY DEFENSE ENGINE (PHÒNG NGỰ TÀI KHOẢN) ===

// Định nghĩa các cấp độ phòng vệ khẩn cấp
enum ENUM_DEFENSE_ACTION {
   DEFENSE_NONE = 0,           // Trạng thái an toàn, giao dịch bình thường
   DEFENSE_SOFT_BLOCK = 1,     // Khóa mở thêm lệnh DCA mới của rổ hiện tại
   DEFENSE_HARD_BLOCK = 2,     // Khóa mở rổ mới hoàn toàn (nhưng cho xử lý rổ cũ)
   DEFENSE_EMERGENCY_EXIT = 3, // Cắt lỗ một phần rổ lệnh hoặc tỉa lỗ khẩn cấp
   DEFENSE_HARD_KILL = 4       // Đóng sạch mọi vị thế ngay lập tức và gỡ EA
};

// Cấu trúc giám sát các chỉ số rủi ro thực tế
struct RiskMetrics {
   double dd_velocity;         // Tốc độ tăng trưởng âm tài khoản (% drawdown tăng lên mỗi phút)
   double basket_age_hours;    // Tuổi thọ rổ lệnh hiện tại (tính bằng giờ)
   double margin_drop_speed;   // Tốc độ tụt Margin Level (đơn vị % margin tụt mỗi phút)
   double spread_ratio;        // Tỷ lệ giãn spread hiện tại so với trung bình (ví dụ: 3.5 lần)
   int    slippage_points;     // Độ trượt giá thực tế đo được (points)
};

class CEquityDefense {
private:
   string   m_symbol;
   
   // Các biến theo dõi lịch sử để tính tốc độ thay đổi (Velocity)
   datetime m_last_velocity_time;
   double   m_last_drawdown;
   double   m_last_margin_level;
   
   // Hệ thống tính toán Spread trung bình
   double   m_spread_accumulator;
   int      m_spread_counter;
   
   // Các tham số cấu hình ngưỡng kích hoạt
   double   m_max_dd_velocity;         // Ngưỡng tốc độ DD cực đại (%/phút) - Mặc định 2.0%
   double   m_max_basket_age_hours;    // Tuổi thọ rổ tối đa trước khi cảnh báo (giờ) - Mặc định 48.0 giờ
   double   m_max_margin_drop_speed;   // Ngưỡng tốc độ tụt Margin (%/phút) - Mặc định 100%
   double   m_max_spread_multiplier;   // Ngưỡng giãn spread (lần so với TB) - Mặc định 3.0 lần
   int      m_max_slippage_points;     // Ngưỡng trượt giá tối đa (points) - Mặc định 100 points

public:
   // Constructor
   CEquityDefense() :
      m_symbol(""),
      m_last_velocity_time(0),
      m_last_drawdown(0.0),
      m_last_margin_level(0.0),
      m_spread_accumulator(0.0),
      m_spread_counter(0),
      m_max_dd_velocity(2.0),
      m_max_basket_age_hours(48.0),
      m_max_margin_drop_speed(100.0),
      m_max_spread_multiplier(3.0),
      m_max_slippage_points(100) {}

   // Khởi tạo Equity Defense
   void Init(string symbol, double max_dd_vel, double max_age, double max_margin_drop, double max_spread_mult, int max_slippage) {
      m_symbol = symbol;
      m_max_dd_velocity = max_dd_vel;
      m_max_basket_age_hours = max_age;
      m_max_margin_drop_speed = max_margin_drop;
      m_max_spread_multiplier = max_spread_mult;
      m_max_slippage_points = max_slippage;
      
      m_last_velocity_time = TimeCurrent();
      m_last_drawdown = GetCurrentDrawdown();
      m_last_margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   }

   // Hàm lấy giá trị Drawdown hiện tại của tài khoản (%)
   double GetCurrentDrawdown() {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(balance > 0) {
         return ((balance - equity) / balance) * 100.0;
      }
      return 0.0;
   }

   // Cập nhật và tính toán Spread trung bình động
   void UpdateSpreadAverage(double currentSpread) {
      m_spread_accumulator += currentSpread;
      m_spread_counter++;
      
      // Reset định kỳ tránh tràn bộ nhớ
      if(m_spread_counter > 5000) {
         m_spread_accumulator = m_spread_accumulator / m_spread_counter;
         m_spread_counter = 1;
      }
   }

   double GetAverageSpread() {
      if(m_spread_counter > 0) {
         return m_spread_accumulator / m_spread_counter;
      }
      return SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }

   // Hàm đo lường các chỉ số rủi ro thực tế (Real-time Metrics)
   void MeasureMetrics(datetime firstOrderOpenTime, int lastSlippage, RiskMetrics &metrics) {
      datetime timeCur = TimeCurrent();
      double currentDD = GetCurrentDrawdown();
      double currentMargin = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      double currentSpread = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      
      UpdateSpreadAverage(currentSpread);

      // Tính tốc độ thay đổi (Velocity) theo phút
      double timeDiffMinutes = (double)(timeCur - m_last_velocity_time) / 60.0;
      if(timeDiffMinutes >= 0.1) { // Đo đạc tối thiểu mỗi 6 giây
         metrics.dd_velocity = (currentDD - m_last_drawdown) / timeDiffMinutes;
         metrics.margin_drop_speed = (m_last_margin_level - currentMargin) / timeDiffMinutes;
         
         // Cập nhật mốc so sánh tiếp theo
         m_last_velocity_time = timeCur;
         m_last_drawdown = currentDD;
         m_last_margin_level = currentMargin;
      } else {
         // Giữ nguyên tốc độ đo được từ vòng lặp trước nếu thời gian trôi qua quá ngắn
         metrics.dd_velocity = 0.0;
         metrics.margin_drop_speed = 0.0;
      }

      // Tuổi rổ lệnh
      if(firstOrderOpenTime > 0) {
         metrics.basket_age_hours = (double)(timeCur - firstOrderOpenTime) / 3600.0;
      } else {
         metrics.basket_age_hours = 0.0;
      }

      // Tỷ lệ giãn spread
      double avgSpread = GetAverageSpread();
      metrics.spread_ratio = (avgSpread > 0.0) ? (currentSpread / avgSpread) : 1.0;
      
      // Độ trượt giá thực tế
      metrics.slippage_points = lastSlippage;
   }

   // Hàm quyết định hành động phòng thủ khẩn cấp dựa trên các chỉ số rủi ro
   ENUM_DEFENSE_ACTION EvaluateDefense(datetime firstOrderOpenTime, int lastSlippage, RiskMetrics &metrics, string &reason) {
      MeasureMetrics(firstOrderOpenTime, lastSlippage, metrics);
      
      // 1. KIỂM TRA MỨC ĐỘ NGUY HIỂM 4: HARD_KILL (Đóng sạch và gỡ EA)
      // Tài khoản âm vượt quá 45% drawdown HOẶC Margin level tụt thảm khốc dưới 180%
      double currentMargin = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      double currentDD = GetCurrentDrawdown();
      if(currentDD >= 45.0) {
         reason = StringFormat("Hard Kill: Drawdown cuc dai vuot muc cho phep (DD = %.2f%%)", currentDD);
         return DEFENSE_HARD_KILL;
      }
      if(currentMargin > 0.0 && currentMargin <= 180.0) {
         reason = StringFormat("Hard Kill: Margin Level giam xuong muc nguy hiem (Margin = %.2f%%)", currentMargin);
         return DEFENSE_HARD_KILL;
      }

      // 2. KIỂM TRA MỨC ĐỘ NGUY HIỂM 3: EMERGENCY_EXIT (Cắt lỗ một phần rổ lệnh/Co cụm)
      // Tốc độ tăng trưởng âm vượt ngưỡng, hoặc tuổi rổ quá lâu kèm DD cao
      if(metrics.dd_velocity >= m_max_dd_velocity * 1.5) {
         reason = StringFormat("Emergency Exit: Am tai khoan tang qua nhanh (Velocity = %.2f%%/min)", metrics.dd_velocity);
         return DEFENSE_EMERGENCY_EXIT;
      }
      if(metrics.basket_age_hours >= m_max_basket_age_hours && currentDD >= 20.0) {
         reason = StringFormat("Emergency Exit: Ro lenh bi giu qua lau (Age = %.1f hours, DD = %.2f%%)", metrics.basket_age_hours, currentDD);
         return DEFENSE_EMERGENCY_EXIT;
      }

      // 3. KIỂM TRA MỨC ĐỘ NGUY HIỂM 2: HARD_BLOCK (Cấm mở rổ lệnh mới hoàn toàn)
      // Spread giãn quá mạnh hoặc trượt giá nghiêm trọng liên tục
      if(metrics.spread_ratio >= m_max_spread_multiplier) {
         reason = StringFormat("Hard Block: Spread dang gian no bat thuong (Spread hien tai = %.1f x Avg)", metrics.spread_ratio);
         return DEFENSE_HARD_BLOCK;
      }
      if(metrics.slippage_points >= m_max_slippage_points) {
         reason = StringFormat("Hard Block: Truot gia (Slippage) vuot muc kiem soat (Slippage = %d pts)", metrics.slippage_points);
         return DEFENSE_HARD_BLOCK;
      }

      // 4. KIỂM TRA MỨC ĐỘ NGUY HIỂM 1: SOFT_BLOCK (Tạm khóa mở DCA)
      // Tốc độ tụt Margin quá nhanh hoặc tốc độ tăng trưởng âm vượt ngưỡng bình thường
      if(metrics.margin_drop_speed >= m_max_margin_drop_speed) {
         reason = StringFormat("Soft Block: Margin dang bi dot pha am rat nhanh (Drop = %.2f%%/min)", metrics.margin_drop_speed);
         return DEFENSE_SOFT_BLOCK;
      }
      if(metrics.dd_velocity >= m_max_dd_velocity) {
         reason = StringFormat("Soft Block: Toc do tang DD dang can canh bao (Velocity = %.2f%%/min)", metrics.dd_velocity);
         return DEFENSE_SOFT_BLOCK;
      }

      reason = "Binh thuong";
      return DEFENSE_NONE;
   }
};

#endif
