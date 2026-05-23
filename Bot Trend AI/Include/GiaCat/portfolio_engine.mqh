#ifndef PORTFOLIO_ENGINE_MQH
#define PORTFOLIO_ENGINE_MQH

// === CẤU HÌNH PORTFOLIO EXPOSURE ENGINE (QUẢN TRỊ RỦI RO DANH MỤC) ===

// Định nghĩa cấu trúc cho cặp tương quan
struct CorrelationItem {
   string symbol1;
   string symbol2;
   double coefficient; // Hệ số tương quan [-1.0 đến 1.0]
};

// Giao diện (Interface) cho phép mở rộng tính năng Rolling Correlation sau này
class ICorrelationManager {
public:
   virtual double GetCorrelation(string sym1, string sym2) = 0;
   virtual void   UpdateCorrelation(string sym1, string sym2, double coeff) = 0;
};

// Phiên bản quản lý tương quan tĩnh ban đầu, sẵn sàng nâng cấp lên động
class CStaticCorrelationManager : public ICorrelationManager {
private:
   CorrelationItem m_matrix[20];
   int             m_count;

public:
   CStaticCorrelationManager() : m_count(0) {
      // Thiết lập ma trận tương quan mặc định (tĩnh)
      AddCorrelation("EURUSD", "USDCHF", -0.85); // Tương quan nghịch cực mạnh
      AddCorrelation("EURUSD", "GBPUSD",  0.80); // Tương quan thuận mạnh
      AddCorrelation("EURUSD", "XAUUSD",  0.40); // Tương quan thuận nhẹ
      AddCorrelation("XAUUSD", "USDJPY", -0.55); // Tương quan nghịch (USDJPY tăng thường Gold giảm)
      AddCorrelation("GBPUSD", "USDCHF", -0.80);
      AddCorrelation("USDCAD", "XAUUSD", -0.30);
   }

   void AddCorrelation(string sym1, string sym2, double coeff) {
      if(m_count < 20) {
         m_matrix[m_count].symbol1 = sym1;
         m_matrix[m_count].symbol2 = sym2;
         m_matrix[m_count].coefficient = coeff;
         m_count++;
      }
   }

   // Lấy hệ số tương quan giữa 2 cặp tiền
   virtual double GetCorrelation(string sym1, string sym2) override {
      if(sym1 == sym2) return 1.0;
      for(int i = 0; i < m_count; i++) {
         if((m_matrix[i].symbol1 == sym1 && m_matrix[i].symbol2 == sym2) ||
            (m_matrix[i].symbol1 == sym2 && m_matrix[i].symbol2 == sym1)) {
            return m_matrix[i].coefficient;
         }
      }
      return 0.0; // Mặc định không tương quan nếu không khai báo
   }

   // Hàm hỗ trợ cập nhật động cho Rolling Correlation sau này
   virtual void UpdateCorrelation(string sym1, string sym2, double coeff) override {
      for(int i = 0; i < m_count; i++) {
         if((m_matrix[i].symbol1 == sym1 && m_matrix[i].symbol2 == sym2) ||
            (m_matrix[i].symbol1 == sym2 && m_matrix[i].symbol2 == sym1)) {
            m_matrix[i].coefficient = coeff;
            return;
         }
      }
      AddCorrelation(sym1, sym2, coeff);
   }
};

class CPortfolioEngine {
private:
   ICorrelationManager* m_corr_manager;       // Quản lý tương quan
   bool                 m_own_corr_manager;    // Cờ đánh dấu tự giải phóng bộ nhớ
   
   // Các giới hạn an toàn danh mục
   double               m_max_directional_lots; // Khối lượng một chiều tối đa (ví dụ: Buy tối đa 5.0 lots tổng)
   double               m_max_correlated_lots;  // Khối lượng các cặp tương quan tối đa
   double               m_global_lot_cap;       // Giới hạn tổng lot toàn bộ tài khoản
   double               m_max_margin_pct;       // % Ký quỹ sử dụng tối đa của hệ thống (ví dụ: 10% tài khoản)

public:
   // Constructor
   CPortfolioEngine() : 
      m_corr_manager(NULL),
      m_own_corr_manager(true),
      m_max_directional_lots(3.0),
      m_max_correlated_lots(4.5),
      m_global_lot_cap(5.0),
      m_max_margin_pct(15.0) 
   {
      m_corr_manager = new CStaticCorrelationManager();
   }
   
   // Cho phép truyền vào một Rolling Correlation Manager tùy biến từ ngoài
   CPortfolioEngine(ICorrelationManager* custom_corr) :
      m_corr_manager(custom_corr),
      m_own_corr_manager(false),
      m_max_directional_lots(3.0),
      m_max_correlated_lots(4.5),
      m_global_lot_cap(5.0),
      m_max_margin_pct(15.0) {}

   // Destructor
   ~CPortfolioEngine() {
      if(m_own_corr_manager && m_corr_manager != NULL) {
         delete m_corr_manager;
      }
   }

   // Hàm thiết lập giới hạn
   void SetLimits(double max_dir, double max_corr, double global_cap, double max_margin) {
      m_max_directional_lots = max_dir;
      m_max_correlated_lots = max_corr;
      m_global_lot_cap = global_cap;
      m_max_margin_pct = max_margin;
   }

   // Đo lường tổng trạng thái danh mục thực tế
   void ScanPortfolio(double &totalBuyLots, double &totalSellLots, double &usdConcentration, double &marginConcentration) {
      totalBuyLots = 0.0;
      totalSellLots = 0.0;
      usdConcentration = 0.0;
      
      int total_positions = PositionsTotal();
      for(int i = 0; i < total_positions; i++) {
         string pos_symbol = PositionGetSymbol(i);
         if(PositionSelect(pos_symbol)) {
            double volume = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if(type == POSITION_TYPE_BUY) {
               totalBuyLots += volume;
            } else if(type == POSITION_TYPE_SELL) {
               totalSellLots += volume;
            }
            
            // Tính toán nồng độ USD (USD Directional Concentration)
            // Lọc các cặp có chứa USD
            if(StringFind(pos_symbol, "USD") >= 0) {
               double net_lot = (type == POSITION_TYPE_BUY) ? volume : -volume;
               // Nếu USD đứng trước (ví dụ USDCHF, USDCAD): Long nghĩa là Buy USD
               if(StringSubstr(pos_symbol, 0, 3) == "USD") {
                  usdConcentration += net_lot;
               }
               // Nếu USD đứng sau (ví dụ EURUSD, GBPUSD): Long nghĩa là Sell USD
               else if(StringSubstr(pos_symbol, 3, 3) == "USD") {
                  usdConcentration -= net_lot;
               }
            }
         }
      }
      
      // Tính toán Ký quỹ sử dụng hiện tại của hệ thống (%)
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double margin = AccountInfoDouble(ACCOUNT_MARGIN);
      marginConcentration = (balance > 0.0) ? ((margin / balance) * 100.0) : 0.0;
   }

   // Tính tổng khối lượng của các tài sản tương quan với Symbol hiện tại
   double GetCorrelatedExposure(string symbol, ENUM_POSITION_TYPE type) {
      double correlatedLots = 0.0;
      int total_positions = PositionsTotal();
      
      for(int i = 0; i < total_positions; i++) {
         string pos_symbol = PositionGetSymbol(i);
         if(pos_symbol == symbol) continue; // Bỏ qua chính nó
         
         if(PositionSelect(pos_symbol)) {
            double vol = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Lấy hệ số tương quan
            double correlation = m_corr_manager.GetCorrelation(symbol, pos_symbol);
            if(MathAbs(correlation) >= 0.5) { // Chỉ xét tương quan từ trung bình trở lên
               // Nếu tương quan thuận (+): Cùng chiều (Buy-Buy) làm tăng rủi ro
               if(correlation > 0.0) {
                  if(pos_type == type) {
                     correlatedLots += vol * correlation;
                  }
               }
               // Nếu tương quan nghịch (-): Ngược chiều (Buy-Sell) làm tăng rủi ro
               else {
                  if(pos_type != type) {
                     correlatedLots += vol * MathAbs(correlation);
                  }
               }
            }
         }
      }
      return correlatedLots;
   }

   // Hàm quyết định giảm Lot size cho lệnh mới dựa trên Rủi ro danh mục (Exposure Decay)
   double GetExposureMultiplier(string symbol, double proposedLot, ENUM_POSITION_TYPE type) {
      double buyLots, sellLots, usdConc, marginConc;
      ScanPortfolio(buyLots, sellLots, usdConc, marginConc);
      
      // 1. Kiểm tra tổng Lot trần (Global Lot Cap)
      double totalCurrentLots = buyLots + sellLots;
      if(totalCurrentLots + proposedLot > m_global_lot_cap) {
         Print("GiaCat Portfolio: Khong dat yeu cau do vuot nguong Global Lot Cap!");
         return 0.0; // Phủ quyết hoàn toàn (Veto)
      }

      // 2. Kiểm tra giới hạn Ký quỹ (Margin Concentration)
      if(marginConc >= m_max_margin_pct) {
         Print("GiaCat Portfolio: Ký quy vuot nguong gioi han margin concentration!");
         return 0.0; // Phủ quyết hoàn toàn
      }

      double multiplier = 1.0;

      // 3. Kiểm tra rủi ro một chiều (Directional Exposure)
      double targetDirectionLots = (type == POSITION_TYPE_BUY) ? buyLots : sellLots;
      if(targetDirectionLots + proposedLot > m_max_directional_lots) {
         double overage = (targetDirectionLots + proposedLot) - m_max_directional_lots;
         double ratio = (proposedLot - overage) / proposedLot;
         if(ratio < multiplier) multiplier = ratio;
      }

      // 4. Kiểm tra tương quan (Correlated Exposure Decay)
      double corrLots = GetCorrelatedExposure(symbol, type);
      if(corrLots + proposedLot > m_max_correlated_lots) {
         double overage = (corrLots + proposedLot) - m_max_correlated_lots;
         double ratio = (proposedLot - overage) / proposedLot;
         if(ratio < multiplier) multiplier = ratio;
      }

      // 5. Kiểm tra rủi ro trái chiều Gold & USDJPY (Mối liên hệ nghịch thường gặp)
      // Gold (XAUUSD) Buy và USDJPY Buy thường triệt tiêu hoặc gia tăng rủi ro khi USD biến động mạnh
      if(symbol == "XAUUSD" && type == POSITION_TYPE_BUY) {
         if(PositionSelect("USDJPY")) {
            double jpyVol = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE jpyType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(jpyType == POSITION_TYPE_BUY) {
               // Cùng Buy Gold và Buy JPY -> USD bi ep tu hai huong. Scale down 30% lot
               multiplier *= 0.70;
            }
         }
      }

      if(multiplier < 0.0) multiplier = 0.0;
      if(multiplier > 1.0) multiplier = 1.0;

      return multiplier;
   }
};

#endif
