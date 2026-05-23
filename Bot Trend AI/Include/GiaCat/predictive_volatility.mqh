#ifndef PREDICTIVE_VOLATILITY_MQH
#define PREDICTIVE_VOLATILITY_MQH

// === CẤU HÌNH PREDICTIVE VOLATILITY ENGINE (DỰ BÁO BIẾN ĐỘNG TRƯỚC SÓNG) ===

class CPredictiveVolatility {
private:
   string            m_symbol;          // Cặp tiền tệ đang giao dịch
   ENUM_TIMEFRAMES   m_tf;              // Khung thời gian dự báo (M15)
   
   int               m_atr_handle;      // Handle chỉ báo ATR
   int               m_bb_handle;       // Handle chỉ báo Bollinger Bands

   // Các biến phục vụ tính toán tốc độ tick (Liquidity)
   datetime          m_tick_window_start;
   int               m_tick_counter;

   // Lịch sử Spread để tính gia tốc spread
   int               m_spread_history[10];
   int               m_spread_index;

   // Các ngưỡng kích hoạt cảnh báo Breakout
   double            m_bb_squeeze_threshold;  // Tỷ lệ nén BB (ví dụ: < 0.0015)
   double            m_atr_acceleration_limit; // Ngưỡng gia tốc ATR (points/bar)
   int               m_spread_acceleration_limit; // Ngưỡng giãn spread đột ngột (points/s)
   int               m_vacuum_tick_rate;      // Tần suất tick tối thiểu báo hiệu hút thanh khoản (ticks/5s)

public:
   // Constructor
   CPredictiveVolatility() :
      m_symbol(""),
      m_tf(PERIOD_M15),
      m_atr_handle(INVALID_HANDLE),
      m_bb_handle(INVALID_HANDLE),
      m_tick_window_start(0),
      m_tick_counter(0),
      m_spread_index(0),
      m_bb_squeeze_threshold(0.0010),
      m_atr_acceleration_limit(10.0),
      m_spread_acceleration_limit(15),
      m_vacuum_tick_rate(3)
   {
      ArrayInitialize(m_spread_history, 0);
   }

   // Destructor giải phóng tài nguyên
   ~CPredictiveVolatility() {
      if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
      if(m_bb_handle != INVALID_HANDLE) IndicatorRelease(m_bb_handle);
   }

   // Khởi tạo Engine dự báo
   bool Init(string symbol, double bb_squeeze, double atr_acc, int spread_acc, int vacuum_ticks) {
      m_symbol = symbol;
      m_tf = PERIOD_M15;
      m_bb_squeeze_threshold = bb_squeeze;
      m_atr_acceleration_limit = atr_acc;
      m_spread_acceleration_limit = spread_acc;
      m_vacuum_tick_rate = vacuum_ticks;
      
      m_atr_handle = iATR(m_symbol, m_tf, 14);
      m_bb_handle = iBands(m_symbol, m_tf, 20, 0, 2.0, PRICE_CLOSE);
      
      m_tick_window_start = TimeCurrent();
      m_tick_counter = 0;
      m_spread_index = 0;
      ArrayInitialize(m_spread_history, 0);

      if(m_atr_handle == INVALID_HANDLE || m_bb_handle == INVALID_HANDLE) {
         Print("GiaCat PredictiveVolatility: Lỗi khởi tạo chỉ báo kỹ thuật!");
         return false;
      }
      return true;
   }

   // Ghi nhận tick mới để tính toán tần suất (Tick Rate) và đo lường thanh khoản
   void RecordTick(int currentSpread) {
      m_tick_counter++;
      
      // Lưu lịch sử spread
      m_spread_history[m_spread_index] = currentSpread;
      m_spread_index = (m_spread_index + 1) % 10;
   }

   // Tính toán gia tốc spread trong 10 ticks gần nhất
   int GetSpreadAcceleration() {
      int maxSpread = m_spread_history[0];
      int minSpread = m_spread_history[0];
      for(int i = 1; i < 10; i++) {
         if(m_spread_history[i] > maxSpread) maxSpread = m_spread_history[i];
         if(m_spread_history[i] < minSpread) minSpread = m_spread_history[i];
      }
      return (maxSpread - minSpread); // Độ chênh lệch giãn nở spread nhanh
   }

   // Hàm phân tích và dự báo nguy cơ Breakout sắp xảy ra
   bool DetectBreakoutWarning(double &atrAcceleration, double &bbWidth, double &spreadAcc, int &tickRate5s, string &reason) {
      datetime timeCur = TimeCurrent();
      
      // 1. Tính toán tần suất tick (Tick Rate trong cửa sổ 5 giây)
      double elapsedSec = (double)(timeCur - m_tick_window_start);
      if(elapsedSec >= 5.0) {
         tickRate5s = m_tick_counter;
         m_tick_counter = 0;
         m_tick_window_start = timeCur;
      } else {
         tickRate5s = -1; // Cần đợi đủ 5 giây để cập nhật cửa sổ tick mới
      }

      // 2. Tính toán Bollinger Band Width (Đo lường độ nén Volatility Compression)
      double base_line[1], upper_line[1], lower_line[1];
      if(CopyBuffer(m_bb_handle, 0, 0, 1, base_line) <= 0 ||
         CopyBuffer(m_bb_handle, 1, 0, 1, upper_line) <= 0 ||
         CopyBuffer(m_bb_handle, 2, 0, 1, lower_line) <= 0) {
         reason = "Lỗi đọc dữ liệu Bollinger Bands M15";
         return false;
      }
      
      if(base_line[0] > 0.0) {
         bbWidth = (upper_line[0] - lower_line[0]) / base_line[0];
      } else {
         bbWidth = 0.0;
      }

      // 3. Tính toán gia tốc biến động (ATR Acceleration - Khung M15)
      double atr_arr[5];
      ArraySetAsSeries(atr_arr, true);
      if(CopyBuffer(m_atr_handle, 0, 0, 5, atr_arr) <= 0) {
         reason = "Lỗi đọc dữ liệu ATR M15";
         return false;
      }
      
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point > 0.0) {
         // Tính độ dốc (slope) của ATR giữa nến hiện tại và nến cách đây 4 nến
         atrAcceleration = (atr_arr[0] - atr_arr[4]) / point; 
      } else {
         atrAcceleration = 0.0;
      }

      // 4. Gia tốc Spread
      spreadAcc = (double)GetSpreadAcceleration();

      // === ĐÁNH GIÁ ĐIỀU KIỆN TIÊN ĐOÁN BREAKOUT ===
      
      // A. Volatility Compression (Nén lò xo): Bollinger Band Width bị siết chặt dưới ngưỡng
      bool isSqueeze = (bbWidth > 0.0 && bbWidth <= m_bb_squeeze_threshold);
      
      // B. ATR Acceleration (Lò xo bắt đầu bung): ATR nến M15 tăng tốc mạnh lên trên ngưỡng
      bool isAtrAccelerating = (atrAcceleration >= m_atr_acceleration_limit);

      // C. Liquidity Vacuum (Hút thanh khoản trước tin bão): Spread giãn nở nhanh kèm tần suất tick tụt sâu
      bool isLiquidityVacuum = false;
      if(spreadAcc >= m_spread_acceleration_limit && tickRate5s > 0 && tickRate5s <= m_vacuum_tick_rate) {
         isLiquidityVacuum = true;
      }

      // Đưa ra quyết định cảnh báo Breakout sớm
      if(isSqueeze && isAtrAccelerating) {
         reason = StringFormat("Breakout Warning: BB Squeeze (Width=%.5f) kem ATR Acceleration (Slope=%.1f pts)", bbWidth, atrAcceleration);
         return true;
      }
      
      if(isLiquidityVacuum) {
         reason = StringFormat("Liquidity Vacuum: Spread acceleration giat manh (%d pts) kem Tick Rate tut giam (%d ticks/5s)", (int)spreadAcc, tickRate5s);
         return true;
      }

      reason = "Volatility on-track";
      return false;
   }
};

#endif
