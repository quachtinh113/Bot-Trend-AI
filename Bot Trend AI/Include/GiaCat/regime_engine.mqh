#ifndef REGIME_ENGINE_MQH
#define REGIME_ENGINE_MQH

// === CẤU HÌNH REGIME MARKET ENGINE ===

// Enums định nghĩa các trạng thái thị trường
enum ENUM_MARKET_REGIME {
   REGIME_RANGING = 0,     // Thị trường đi ngang (Sideway)
   REGIME_TRANSITION = 1,  // Thị trường chuyển giao (Biến động nhẹ hoặc chuẩn bị breakout)
   REGIME_TRENDING = 2     // Thị trường có xu hướng mạnh (Trending hoặc biến động cực mạnh)
};

// Cấu trúc chứa các quy tắc hành động tương ứng với mỗi Regime
struct RegimeActions {
   bool disable_new_dca;            // Khóa hoàn toàn việc thêm lớp DCA mới
   bool recovery_exit_only;         // Chỉ cho phép lệnh thoát hòa vốn rổ (Escape / Recovery Mode)
   double lot_exposure_scale;       // Hệ số giảm khối lượng (0.5 nghĩa là giảm 50% khối lượng lệnh mới)
   bool emergency_basket_shrink;    // Kích hoạt chế độ co cụm/tỉa khẩn cấp rổ lệnh
   double grid_spacing_multiplier;  // Hệ số nhân khoảng cách lưới (ví dụ: 2.0 nghĩa là giãn khoảng cách gấp đôi)
   double max_layers_reduction;     // Hệ số giảm số lượng lớp lệnh tối đa (0.5 nghĩa là giảm một nửa số lớp)
};

// Lớp điều khiển chính của Market Regime Engine
class CRegimeEngine {
private:
   string            m_symbol;          // Cặp tiền tệ đang giao dịch
   ENUM_TIMEFRAMES   m_tf;              // Khung thời gian mặc định của Regime (H1)
   int               m_adx_handle;      // Handle của chỉ báo ADX
   int               m_atr_handle;      // Handle của chỉ báo ATR
   int               m_rsi_handle;      // Handle của chỉ báo RSI
   int               m_atr_lookback;    // Số nến để tính ATR trung bình (mặc định 100 nến H1)

public:
   // Constructor
   CRegimeEngine() : 
      m_symbol(""),
      m_tf(PERIOD_H1),
      m_adx_handle(INVALID_HANDLE),
      m_atr_handle(INVALID_HANDLE),
      m_rsi_handle(INVALID_HANDLE),
      m_atr_lookback(100) {}

   // Destructor giải phóng tài nguyên
   ~CRegimeEngine() {
      if(m_adx_handle != INVALID_HANDLE) IndicatorRelease(m_adx_handle);
      if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
      if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
   }

   // Hàm khởi tạo các chỉ báo kỹ thuật
   bool Init(string symbol, int atr_lookback = 100) {
      m_symbol = symbol;
      m_tf = PERIOD_H1;
      m_atr_lookback = atr_lookback;
      
      m_adx_handle = iADX(m_symbol, m_tf, 14);
      m_atr_handle = iATR(m_symbol, m_tf, 14);
      m_rsi_handle = iRSI(m_symbol, m_tf, 14);
      
      if(m_adx_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE || m_rsi_handle == INVALID_HANDLE) {
         Print("GiaCat RegimeEngine: Lỗi khởi tạo chỉ báo kỹ thuật!");
         return false;
      }
      return true;
   }

   // Hàm nhận diện thị trường hiện tại
   ENUM_MARKET_REGIME DetectRegime(string &reason) {
      double adx[1];
      double atr[1];
      double rsi[1];
      
      // Sao chép dữ liệu chỉ báo hiện tại (nến hiện tại)
      if(CopyBuffer(m_adx_handle, 0, 0, 1, adx) <= 0) {
         reason = "Lỗi đọc dữ liệu ADX H1";
         return REGIME_TRANSITION;
      }
      if(CopyBuffer(m_atr_handle, 0, 0, 1, atr) <= 0) {
         reason = "Lỗi đọc dữ liệu ATR H1";
         return REGIME_TRANSITION;
      }
      if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi) <= 0) {
         reason = "Lỗi đọc dữ liệu RSI H1";
         return REGIME_TRANSITION;
      }
      
      // Tính toán ATR trung bình lịch sử (lookback nến H1)
      double atr_arr[];
      ArraySetAsSeries(atr_arr, true);
      int copied = CopyBuffer(m_atr_handle, 0, 1, m_atr_lookback, atr_arr);
      if(copied <= 0) {
         reason = "Lỗi đọc dữ liệu ATR lịch sử H1";
         return REGIME_TRANSITION;
      }
      
      double sum = 0.0;
      for(int i = 0; i < copied; i++) {
         sum += atr_arr[i];
      }
      double avg_atr = (copied > 0) ? (sum / copied) : 0.0;
      
      double cur_adx = adx[0];
      double cur_atr = atr[0];
      double cur_rsi = rsi[0];
      
      // 1. REGIME_TRENDING (Thị trường xu hướng mạnh hoặc biến động cực lớn)
      if(cur_adx > 25.0 || (avg_atr > 0.0 && cur_atr > 1.8 * avg_atr)) {
         reason = StringFormat("Trending [ADX H1=%.2f, ATR H1=%.5f vs Trung binh(100)=%.5f]", cur_adx, cur_atr, avg_atr);
         return REGIME_TRENDING;
      }
      
      // 2. REGIME_RANGING (Thị trường đi ngang biên độ ổn định)
      if(cur_adx < 20.0 && (cur_rsi >= 40.0 && cur_rsi <= 60.0)) {
         reason = StringFormat("Ranging [ADX H1=%.2f, RSI H1=%.2f]", cur_adx, cur_rsi);
         return REGIME_RANGING;
      }
      
      // 3. REGIME_TRANSITION (Thị trường chuyển giao)
      reason = StringFormat("Transition [ADX H1=%.2f, ATR H1=%.5f vs Trung binh(100)=%.5f, RSI H1=%.2f]", cur_adx, cur_atr, avg_atr, cur_rsi);
      return REGIME_TRANSITION;
   }

   // Lấy các tham số cấu hình lưới giao dịch tương ứng với Regime hiện tại
   void GetRegimeActions(ENUM_MARKET_REGIME regime, RegimeActions &actions) {
      if(regime == REGIME_TRENDING) {
         actions.disable_new_dca = true;             // Khóa DCA mới
         actions.recovery_exit_only = true;          // Chỉ tập trung thoát rổ lệnh hòa vốn/lãi nhẹ
         actions.lot_exposure_scale = 0.0;           // Không mở thêm bất kỳ lệnh mới nào bên ngoài
         actions.emergency_basket_shrink = true;     // Bật cơ chế tỉa rổ lệnh khẩn cấp
         actions.grid_spacing_multiplier = 3.0;      // Nếu vẫn buộc phải mở DCA khẩn cấp, giãn khoảng cách 3 lần
         actions.max_layers_reduction = 0.5;         // Giảm 50% số lượng lớp lệnh cho phép
      }
      else if(regime == REGIME_RANGING) {
         actions.disable_new_dca = false;            // Cho phép DCA bình thường
         actions.recovery_exit_only = false;         // Vận hành bình thường
         actions.lot_exposure_scale = 1.0;           // Volume 100%
         actions.emergency_basket_shrink = false;    // Tắt chế độ co cụm
         actions.grid_spacing_multiplier = 1.0;      // Giữ khoảng cách lưới nguyên bản
         actions.max_layers_reduction = 1.0;         // Giữ nguyên số lượng lớp lệnh tối đa
      }
      else { // REGIME_TRANSITION
         actions.disable_new_dca = false;            // Vẫn cho phép DCA
         actions.recovery_exit_only = false;
         actions.lot_exposure_scale = 0.5;           // Giảm 50% khối lượng lệnh (Half Lot)
         actions.emergency_basket_shrink = false;
         actions.grid_spacing_multiplier = 2.0;      // Nhân đôi khoảng cách lưới (Double Spacing)
         actions.max_layers_reduction = 0.5;         // Giảm 50% số lượng lớp tối đa
      }
   }
};

#endif
