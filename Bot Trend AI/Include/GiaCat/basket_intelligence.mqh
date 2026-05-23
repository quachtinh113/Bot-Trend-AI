#ifndef BASKET_INTELLIGENCE_MQH
#define BASKET_INTELLIGENCE_MQH

// === CẤU HÌNH BASKET INTELLIGENCE ENGINE (TỰ Ý THỨC RỔ LỆNH) ===

// Định nghĩa trạng thái tự nhận thức của rổ lệnh
enum ENUM_BASKET_STATE {
   BASKET_HEALTHY = 0,     // Rổ lệnh khỏe mạnh (Số lệnh ít, DD thấp)
   BASKET_STRESSED = 1,    // Rổ lệnh chịu áp lực (Số lệnh trung bình, DD tăng)
   BASKET_CRITICAL = 2,    // Rổ lệnh nguy cấp (Số lệnh nhiều, biến động lớn)
   BASKET_RECOVERY = 3,    // Rổ lệnh đang hồi phục (Tín hiệu hồi rõ rệt, thu hẹp DD)
   BASKET_TERMINAL = 4     // Rổ lệnh quá hạn sinh tồn (Tuổi thọ quá dài, lỗ vượt kiểm soát)
};

// Cấu trúc đo lường hiệu năng rổ lệnh
struct BasketTelemetry {
   int      order_count;           // Số lệnh hiện tại trong rổ
   double   floating_loss_cent;    // Số tiền âm hiện tại (Cent)
   double   adverse_excursion;     // Mức trôi ngược lớn nhất đo được (points)
   double   distance_to_be_pts;    // Khoảng cách từ giá hiện tại đến điểm hòa vốn (points)
   double   recovery_velocity;     // Tốc độ hồi phục tài khoản (points/phút)
   double   efficiency_ratio;      // Tỷ lệ hiệu quả (Realized Profit / Floating Loss)
   double   age_hours;             // Tuổi thọ rổ lệnh (giờ)
};

class CBasketIntelligence {
private:
   string   m_symbol;
   
   // Các biến lưu vết hành trình rổ lệnh
   double   m_max_adverse_excursion;   // Mức trôi ngược cực đại (Adverse Excursion)
   double   m_last_distance_to_be;     // Khoảng cách BE vòng trước để đo tốc độ hồi
   datetime m_last_velocity_time;      
   
   // Các ngưỡng kích hoạt chuyển trạng thái rổ lệnh
   int      m_stressed_orders;         // Ngưỡng lệnh Stress (ví dụ: >= 5 lệnh)
   int      m_critical_orders;         // Ngưỡng lệnh Nguy cấp (ví dụ: >= 10 lệnh)
   double   m_max_age_limit_hours;     // Ngưỡng tuổi thọ giới hạn của rổ (giờ)
   double   m_stressed_dd_pct;         // Drawdown báo động stress (%)

public:
   // Constructor
   CBasketIntelligence() :
      m_symbol(""),
      m_max_adverse_excursion(0.0),
      m_last_distance_to_be(0.0),
      m_last_velocity_time(0),
      m_stressed_orders(5),
      m_critical_orders(10),
      m_max_age_limit_hours(48.0),
      m_stressed_dd_pct(10.0) {}

   // Khởi tạo Basket Intelligence
   void Init(string symbol, int stressed_ord, int critical_ord, double max_age_hours, double stressed_dd) {
      m_symbol = symbol;
      m_stressed_orders = stressed_ord;
      m_critical_orders = critical_ord;
      m_max_age_limit_hours = max_age_hours;
      m_stressed_dd_pct = stressed_dd;
      
      m_max_adverse_excursion = 0.0;
      m_last_distance_to_be = 0.0;
      m_last_velocity_time = TimeCurrent();
   }

   // Reset các chỉ số khi rổ lệnh mới bắt đầu
   void ResetTelemetry() {
      m_max_adverse_excursion = 0.0;
      m_last_distance_to_be = 0.0;
      m_last_velocity_time = TimeCurrent();
   }

   // Đo lường và đánh giá các chỉ số telemetry của rổ lệnh
   void MeasureTelemetry(int orderCount, 
                         double currentLossCent, 
                         double currentDD, 
                         double currentDistToBE, 
                         double realizedProfitCent, 
                         datetime firstOrderOpenTime, 
                         BasketTelemetry &telemetry) 
   {
      datetime timeCur = TimeCurrent();
      telemetry.order_count = orderCount;
      telemetry.floating_loss_cent = currentLossCent;
      
      // 1. Cập nhật Adverse Excursion (Mức trôi ngược lớn nhất)
      if(currentDistToBE > m_max_adverse_excursion) {
         m_max_adverse_excursion = currentDistToBE;
      }
      telemetry.adverse_excursion = m_max_adverse_excursion;
      telemetry.distance_to_be_pts = currentDistToBE;
      
      // 2. Tính tuổi rổ lệnh
      if(firstOrderOpenTime > 0) {
         telemetry.age_hours = (double)(timeCur - firstOrderOpenTime) / 3600.0;
      } else {
         telemetry.age_hours = 0.0;
      }

      // 3. Tính tốc độ hồi phục (Recovery Velocity - Pts/phút)
      double timeDiffMin = (double)(timeCur - m_last_velocity_time) / 60.0;
      if(timeDiffMin >= 0.1) {
         // Nếu khoảng cách đến BE giảm xuống -> rổ đang hồi phục về điểm hòa vốn
         double distDelta = m_last_distance_to_be - currentDistToBE;
         telemetry.recovery_velocity = distDelta / timeDiffMin;
         
         m_last_distance_to_be = currentDistToBE;
         m_last_velocity_time = timeCur;
      } else {
         telemetry.recovery_velocity = 0.0;
      }

      // 4. Tính tỷ lệ hiệu quả (Efficiency Ratio)
      // Realized profit chia cho mức âm hiện tại
      if(currentLossCent > 0.0) {
         telemetry.efficiency_ratio = realizedProfitCent / currentLossCent;
      } else {
         telemetry.efficiency_ratio = 1.0;
      }
   }

   // Đánh giá Trạng thái rổ lệnh (Basket State)
   ENUM_BASKET_STATE EvaluateState(const BasketTelemetry &telemetry, double currentDD) {
      // 1. TERMINAL: Tuổi thọ quá lớn (đã bị giam rổ quá 48 tiếng) kèm mức sụt giảm nặng nề
      if(telemetry.age_hours >= m_max_age_limit_hours && currentDD >= 15.0) {
         return BASKET_TERMINAL;
      }

      // 2. RECOVERY: Rổ lệnh có số lệnh nhiều nhưng tốc độ hồi phục đang dương mạnh (giá quay đầu về BE nhanh)
      if(telemetry.order_count >= m_stressed_orders && telemetry.recovery_velocity > 50.0) {
         return BASKET_RECOVERY;
      }

      // 3. CRITICAL: Số lệnh vượt ngưỡng nguy cấp hoặc tài khoản bị Drawdown nặng (> 20%)
      if(telemetry.order_count >= m_critical_orders || currentDD >= 20.0) {
         return BASKET_CRITICAL;
      }

      // 4. STRESSED: Số lệnh chạm ngưỡng stressed hoặc Drawdown chạm mức Stress cảnh báo
      if(telemetry.order_count >= m_stressed_orders || currentDD >= m_stressed_dd_pct) {
         return BASKET_STRESSED;
      }

      // 5. HEALTHY: Trạng thái bình thường
      return BASKET_HEALTHY;
   }

   // Quyết định hành vi DCA tương ứng với Trạng thái rổ lệnh (Governance Rule 4)
   bool IsDCAAllowed(ENUM_BASKET_STATE state) {
      // HEALTHY & STRESSED được phép DCA.
      // CRITICAL & TERMINAL cấm DCA hoàn toàn, chỉ cho phép thoát/tỉa rổ.
      // RECOVERY tạm dừng mở mới để giá tự hồi về BE.
      if(state == BASKET_HEALTHY || state == BASKET_STRESSED) {
         return true;
      }
      return false;
   }

   // Điều tiết các thông số của Lưới theo sức khỏe rổ
   void GetGridAdjustments(ENUM_BASKET_STATE state, double &lotScale, double &spacingMultiplier, bool &recoveryOnly, bool &triggerTrim) {
      lotScale = 1.0;
      spacingMultiplier = 1.0;
      recoveryOnly = false;
      triggerTrim = false;

      switch(state) {
         case BASKET_HEALTHY:
            lotScale = 1.0;
            spacingMultiplier = 1.0;
            break;

         case BASKET_STRESSED:
            lotScale = 0.75;           // Giảm 25% khối lượng DCA để phòng ngự
            spacingMultiplier = 1.5;   // Giãn khoảng cách lưới 1.5 lần
            break;

         case BASKET_RECOVERY:
            lotScale = 0.0;           // Khóa mở thêm lệnh dca mới
            spacingMultiplier = 2.0;
            recoveryOnly = true;      // Chuyển sang chế độ chỉ thu hồi
            break;

         case BASKET_CRITICAL:
            lotScale = 0.0;           // Khóa mở thêm dca mới
            spacingMultiplier = 3.0;
            recoveryOnly = true;      // Chuyển sang chế độ chỉ thu hồi
            triggerTrim = true;       // Kích hoạt Trim Manager để tỉa lệnh
            break;

         case BASKET_TERMINAL:
            lotScale = 0.0;           // Khóa dca
            spacingMultiplier = 4.0;
            recoveryOnly = true;
            triggerTrim = true;       // Bắt buộc tỉa lệnh khẩn cấp giải phóng margin
            break;
      }
   }
};

#endif
