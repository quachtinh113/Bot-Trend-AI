#ifndef VOLATILITY_ENGINE_MQH
#define VOLATILITY_ENGINE_MQH

// === CẤU HÌNH VOLATILITY ENGINE (ATR DYNAMIC GRID SPACING) ===

class CVolatilityEngine {
private:
   string            m_symbol;          // Cặp tiền tệ đang giao dịch
   ENUM_TIMEFRAMES   m_tf;              // Khung thời gian ATR (M15)
   int               m_atr_handle;      // Handle chỉ báo ATR
   
   bool              m_enabled;         // Bật/tắt tính năng Grid động theo ATR
   double            m_multiplier;      // Hệ số nhân ATR (InpATRMultiplier)
   int               m_min_points;      // Khoảng cách tối thiểu (InpMinGridPoints)
   int               m_max_points;      // Khoảng cách tối đa (InpMaxGridPoints)

public:
   // Constructor
   CVolatilityEngine() :
      m_symbol(""),
      m_tf(PERIOD_M15),
      m_atr_handle(INVALID_HANDLE),
      m_enabled(true),
      m_multiplier(1.5),
      m_min_points(150),
      m_max_points(1200) {}

   // Destructor giải phóng tài nguyên
   ~CVolatilityEngine() {
      if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
   }

   // Hàm khởi tạo Volatility Engine
   bool Init(string symbol, bool enabled, double multiplier, int min_points, int max_points) {
      m_symbol = symbol;
      m_tf = PERIOD_M15;
      m_enabled = enabled;
      m_multiplier = multiplier;
      m_min_points = min_points;
      m_max_points = max_points;
      
      m_atr_handle = iATR(m_symbol, m_tf, 14);
      if(m_atr_handle == INVALID_HANDLE) {
         Print("GiaCat VolatilityEngine: Lỗi khởi tạo chỉ báo ATR M15!");
         return false;
      }
      return true;
   }

   // Hàm tính toán khoảng cách cho lệnh tiếp theo
   int CalculateSpacing(int orderIndex, double baseDistPoints, double stepMultiplier, double regimeMultiplier = 1.0) {
      double spacing = baseDistPoints;
      
      if(m_enabled) {
         double atr[1];
         if(CopyBuffer(m_atr_handle, 0, 0, 1, atr) > 0) {
            double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            if(point > 0.0) {
               // Chuyển đổi ATR sang đơn vị Points (ví dụ 0.00150 -> 150 points)
               double atrPoints = atr[0] / point;
               spacing = atrPoints * m_multiplier;
            }
         } else {
            Print("GiaCat VolatilityEngine: Không thể đọc ATR M15, sử dụng khoảng cách cơ bản.");
         }
      }
      
      // Áp dụng hệ số giãn cách của Regime (ví dụ: Regime transition nhân đôi khoảng cách)
      spacing = spacing * regimeMultiplier;
      
      // Áp dụng hệ số tăng khoảng cách lưới nâng cấp (DCA Grid Step Multiplier)
      // Lưới tiến trình: spacing * (stepMultiplier ^ orderIndex)
      if(orderIndex > 0 && stepMultiplier > 1.0) {
         spacing = spacing * MathPow(stepMultiplier, orderIndex);
      }
      
      // Ràng buộc khoảng cách nằm trong khoảng giới hạn Min / Max
      int finalSpacing = (int)MathRound(spacing);
      if(finalSpacing < m_min_points) finalSpacing = m_min_points;
      if(finalSpacing > m_max_points) finalSpacing = m_max_points;
      
      return finalSpacing;
   }
};

#endif
