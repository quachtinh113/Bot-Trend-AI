#ifndef SURVIVAL_SCORE_ENGINE_MQH
#define SURVIVAL_SCORE_ENGINE_MQH

// === CẤU HÌNH SURVIVAL SCORE ENGINE (BỘ NÃO BẢO HIỂM TÀI SẢN) ===

// Định nghĩa các trạng thái Risk của Master Engine
enum ENUM_SURVIVAL_STATE {
   SURVIVAL_NORMAL = 0,       // Hoạt động bình thường (Score >= 60)
   SURVIVAL_REDUCE_RISK = 1,  // Giảm thiểu rủi ro (60 > Score >= 40)
   SURVIVAL_SAFE_MODE = 2,    // Chế độ an toàn (40 > Score >= 25 - No New Basket, Recovery Only)
   SURVIVAL_HARD_BLOCK = 3,   // Khóa cứng hoạt động (25 > Score >= 15 - Block DCA & No New Basket)
   SURVIVAL_HARD_KILL = 4     // Thanh trừng tài khoản (Score < 15 - Close All & Stop EA)
};

class CSurvivalScoreEngine {
private:
   string   m_symbol;
   double   m_weekly_start_equity; // Vốn bắt đầu tuần (Starting Equity)
   double   m_daily_risk_budget;   // Ngân sách rủi ro ngày (Cent)
   double   m_weekly_dd_limit;     // Giới hạn Drawdown tuần (%) - Mặc định 8%
   
   // Tên biến toàn cầu của Terminal để lưu Starting Equity xuyên phiên khởi động lại
   string   m_gv_weekly_equity_key;
   string   m_gv_weekly_index_key;

public:
   // Constructor
   CSurvivalScoreEngine() :
      m_symbol(""),
      m_weekly_start_equity(0.0),
      m_daily_risk_budget(1000.0),
      m_weekly_dd_limit(8.0),
      m_gv_weekly_equity_key(""),
      m_gv_weekly_index_key("") {}

   // Khởi tạo Survival Score Engine
   void Init(string symbol, double daily_budget, double weekly_dd) {
      m_symbol = symbol;
      m_daily_risk_budget = daily_budget;
      m_weekly_dd_limit = weekly_dd;
      
      long login = AccountInfoInteger(ACCOUNT_LOGIN);
      m_gv_weekly_equity_key = StringFormat("GiaCat_WeeklyStartEquity_%d", login);
      m_gv_weekly_index_key = StringFormat("GiaCat_LastWeekIndex_%d", login);
      
      CheckAndInitializeWeeklyEquity();
   }

   // Hàm kiểm tra tuần mới và khởi tạo/đọc Starting Equity
   void CheckAndInitializeWeeklyEquity() {
      datetime current_time = TimeCurrent();
      long curr_week_index = current_time / (7 * 24 * 3600); // Chia lấy tuần tuyệt đối
      
      // Đọc tuần lưu trước đó từ Global Variable
      long last_week_index = 0;
      if(GlobalVariableCheck(m_gv_weekly_index_key)) {
         last_week_index = (long)GlobalVariableGet(m_gv_weekly_index_key);
      }
      
      // Nếu là tuần mới hoặc chưa từng khởi tạo biến toàn cầu
      if(curr_week_index != last_week_index || !GlobalVariableCheck(m_gv_weekly_equity_key)) {
         double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(m_gv_weekly_equity_key, current_equity);
         GlobalVariableSet(m_gv_weekly_index_key, (double)curr_week_index);
         m_weekly_start_equity = current_equity;
         Print(StringFormat("GiaCat Survival: Khởi tạo Starting Equity tuần mới: %.2f (Tuần số %d)", current_equity, curr_week_index));
      } else {
         m_weekly_start_equity = GlobalVariableGet(m_gv_weekly_equity_key);
      }
   }

   // Đọc vốn bắt đầu tuần
   double GetWeeklyStartEquity() {
      return m_weekly_start_equity;
   }

   // Tính toán Điểm số Sinh tồn (Survival Score) từ 0 đến 100
   double CalculateSurvivalScore(double dailyLossCent, double currentDDPercent, double marginLevelVal, double equitySlopeSign) {
      // Đảm bảo cập nhật tuần trước khi tính toán
      CheckAndInitializeWeeklyEquity();
      
      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // 1. Tính toán sụt giảm tài khoản tuần theo Starting Equity (Governance Rule 1)
      double weekly_dd = 0.0;
      if(m_weekly_start_equity > 0.0) {
         double loss = m_weekly_start_equity - current_equity;
         if(loss > 0.0) {
            weekly_dd = (loss / m_weekly_start_equity) * 100.0;
         }
      }

      // Khởi tạo điểm số tối đa là 100
      double score = 100.0;

      // 2. Trừ điểm dựa trên sụt giảm tuần (Áp dụng các ngưỡng quyết định tại Governance Rule 2)
      // Ngưỡng 3% = SOFT_BLOCK (Score < 25), Ngưỡng 5% = SAFE_MODE (Score < 40), Ngưỡng 8% = HARD_KILL (Score < 15)
      if(weekly_dd >= 8.0) {
         score = 10.0; // Rơi thẳng vào vùng HARD_KILL (Score < 15)
      }
      else if(weekly_dd >= 5.0) {
         // Từ 5% -> 8%: Điểm số dao động trong khoảng [15, 24]
         double progress = (weekly_dd - 5.0) / (8.0 - 5.0);
         score = 24.0 - (progress * 9.0);
      }
      else if(weekly_dd >= 3.0) {
         // Từ 3% -> 5%: Điểm số dao động trong khoảng [25, 39] (Vùng SAFE_MODE / HARD_BLOCK)
         double progress = (weekly_dd - 3.0) / (5.0 - 3.0);
         score = 39.0 - (progress * 14.0);
      }
      else if(weekly_dd > 0.0) {
         // Từ 0% -> 3%: Điểm số dao động trong khoảng [40, 95]
         double progress = weekly_dd / 3.0;
         score = 95.0 - (progress * 55.0);
      }

      // 3. Trừ điểm dựa trên sụt giảm tài khoản hiện tại (Current Drawdown)
      if(currentDDPercent >= 20.0) {
         score -= 20.0;
      } else if(currentDDPercent >= 10.0) {
         score -= 10.0;
      }

      // 4. Trừ điểm dựa trên Margin Level tụt dốc
      if(marginLevelVal > 0.0) {
         if(marginLevelVal < 250.0) {
            score -= 15.0;
         } else if(marginLevelVal < 500.0) {
            score -= 5.0;
         }
      }

      // 5. Trừ điểm dựa trên hướng dốc của đường cong tài sản (Equity Slope)
      if(equitySlopeSign < 0) {
         score -= 5.0; // Xu hướng tài khoản đang đi xuống trong 48 giờ qua
      }

      // Ràng buộc giới hạn điểm số trong khoảng [0, 100]
      if(score < 0.0) score = 0.0;
      if(score > 100.0) score = 100.0;

      return score;
   }

   // Phân cấp Trạng thái Sinh tồn tương ứng dựa trên Điểm số (Governance Rule 5)
   ENUM_SURVIVAL_STATE GetSurvivalState(double score) {
      if(score < 15.0) return SURVIVAL_HARD_KILL;    // Score < 15 -> HARD_KILL (Thanh trừng)
      if(score < 25.0) return SURVIVAL_HARD_BLOCK;   // Score < 25 -> HARD_BLOCK (Khóa DCA)
      if(score < 40.0) return SURVIVAL_SAFE_MODE;    // Score < 40 -> SAFE_MODE (Chỉ Recovery)
      if(score < 60.0) return SURVIVAL_REDUCE_RISK;  // Score < 60 -> REDUCE_RISK (Giảm lot, giãn spacing)
      return SURVIVAL_NORMAL;                        // Hoạt động bình thường
   }

   // Lấy các luật veto rủi ro từ Master Engine để kiểm soát Dumb Execution Engine (Rule 7, 8)
   void GetMasterRiskVeto(ENUM_SURVIVAL_STATE state, 
                          bool &vetoNewBaskets, 
                          bool &vetoNewDCA, 
                          double &lotScalingFactor, 
                          double &spacingScalingFactor,
                          string &stateName) 
   {
      vetoNewBaskets = false;
      vetoNewDCA = false;
      lotScalingFactor = 1.0;
      spacingScalingFactor = 1.0;

      switch(state) {
         case SURVIVAL_NORMAL:
            stateName = "NORMAL";
            break;

         case SURVIVAL_REDUCE_RISK:
            stateName = "REDUCE_RISK";
            lotScalingFactor = 0.60;       // Giảm 40% lot size cho mọi vị thế mới
            spacingScalingFactor = 1.50;   // Giãn khoảng cách lưới dca 1.5 lần
            break;

         case SURVIVAL_SAFE_MODE:
            stateName = "SAFE_MODE";
            vetoNewBaskets = true;         // Cấm mở rổ lệnh mới hoàn toàn (Rule 5)
            lotScalingFactor = 0.40;       // Nếu DCA, giảm lot còn 40%
            spacingScalingFactor = 2.00;   // Giãn khoảng cách gấp đôi
            break;

         case SURVIVAL_HARD_BLOCK:
            stateName = "HARD_BLOCK";
            vetoNewBaskets = true;         // Cấm mở rổ mới
            vetoNewDCA = true;             // Khóa cứng mở thêm DCA mới (Rule 5)
            lotScalingFactor = 0.0;
            break;

         case SURVIVAL_HARD_KILL:
            stateName = "HARD_KILL";
            vetoNewBaskets = true;
            vetoNewDCA = true;
            lotScalingFactor = 0.0;
            break;
      }
   }
};

#endif
