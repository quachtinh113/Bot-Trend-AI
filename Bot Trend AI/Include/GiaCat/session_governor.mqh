#ifndef SESSION_GOVERNOR_MQH
#define SESSION_GOVERNOR_MQH

// === CẤU HÌNH SESSION GOVERNOR & NEWS BLACKOUT ===

// Định nghĩa các phiên giao dịch
enum ENUM_TRADING_SESSION {
   SESSION_ASIA = 0,    // Phiên Á (22:00 - 07:00 GMT)
   SESSION_LONDON = 1,  // Phiên Âu (07:00 - 16:00 GMT)
   SESSION_NY = 2,      // Phiên Mỹ (12:00 - 21:00 GMT)
   SESSION_OVERLAP = 3  // Phiên Trùng (Âu - Mỹ: 12:00 - 16:00 GMT)
};

// Lớp quản lý phiên giao dịch và tin tức kinh tế
class CSessionGovernor {
private:
   string   m_symbol;               // Cặp tiền tệ đang giao dịch
   bool     m_use_news_filter;      // Bật/tắt bộ lọc tin tức
   int      m_news_before_min;      // Số phút dừng trước tin
   int      m_news_after_min;       // Số phút dừng sau tin

public:
   // Constructor
   CSessionGovernor() :
      m_symbol(""),
      m_use_news_filter(true),
      m_news_before_min(30),
      m_news_after_min(30) {}

   // Khởi tạo Governor
   bool Init(string symbol, bool use_news_filter, int before_min, int after_min) {
      m_symbol = symbol;
      m_use_news_filter = use_news_filter;
      m_news_before_min = before_min;
      m_news_after_min = after_min;
      return true;
   }

   // Xác định phiên giao dịch hiện tại dựa trên giờ GMT
   ENUM_TRADING_SESSION GetCurrentSession(int &gmtHour) {
      datetime gmtTime = TimeGMT();
      MqlDateTime dt;
      TimeToStruct(gmtTime, dt);
      gmtHour = dt.hour;

      // Trùng phiên Âu và Mỹ (12:00 - 16:00 GMT)
      if(gmtHour >= 12 && gmtHour < 16) {
         return SESSION_OVERLAP;
      }
      // Phiên Mỹ (16:00 - 21:00 GMT)
      if(gmtHour >= 16 && gmtHour < 21) {
         return SESSION_NY;
      }
      // Phiên Âu (07:00 - 12:00 GMT)
      if(gmtHour >= 7 && gmtHour < 12) {
         return SESSION_LONDON;
      }
      // Phiên Á (21:00 - 07:00 GMT)
      return SESSION_ASIA;
   }

   // Lấy các ràng buộc giao dịch của Phiên hiện tại
   void GetSessionConstraints(ENUM_TRADING_SESSION session, 
                               bool &allowMeanReversion, 
                               double &lotScale, 
                               bool &requireDirectionFilter, 
                               bool &restrictGridVolSpikes) {
      switch(session) {
         case SESSION_ASIA:
            allowMeanReversion = true;       // Cho phép giao dịch đảo chiều trung bình (Mean Reversion)
            lotScale = 0.6;                  // Giảm khối lượng xuống còn 60%
            requireDirectionFilter = false;  // Không cần bộ lọc xu hướng mạnh
            restrictGridVolSpikes = false;
            break;

         case SESSION_LONDON:
            allowMeanReversion = false;      // Giao dịch theo xu hướng
            lotScale = 1.0;                  // 100% volume
            requireDirectionFilter = true;   // Phải bật bộ lọc hướng của chỉ báo
            restrictGridVolSpikes = true;
            break;

         case SESSION_NY:
            allowMeanReversion = false;      // Giao dịch xu hướng
            lotScale = 0.8;                  // Giảm bớt 20% lot đề phòng biến động bất ngờ
            requireDirectionFilter = true;   // Lọc xu hướng chặt
            restrictGridVolSpikes = true;    // Hạn chế DCA khi có đột biến volatility
            break;

         case SESSION_OVERLAP:
            allowMeanReversion = false;
            lotScale = 0.5;                  // Khối lượng lệnh giảm 50% trong phiên trùng biến động cực mạnh
            requireDirectionFilter = true;
            restrictGridVolSpikes = true;
            break;
      }
   }

   // Kiểm tra xem hiện tại có đang trong khung thời gian cấm giao dịch do Tin Tức hay không
   bool CheckNewsBlackout(string &newsDescription) {
      if(!m_use_news_filter) return false;

      #ifdef __MQL5__
      // Sử dụng API Calendar của MT5
      MqlCalendarValue values[];
      datetime timeCur = TimeCurrent();
      
      // Khoảng thời gian kiểm tra: từ (Hiện tại - NewsAfterMin) đến (Hiện tại + NewsBeforeMin)
      datetime timeFrom = timeCur - (m_news_after_min * 60);
      datetime timeTo = timeCur + (m_news_before_min * 60);

      // Lấy lịch sử tin tức trong khoảng thời gian này
      int count = CalendarValueHistoryGet(values, timeFrom, timeTo);
      if(count > 0) {
         for(int i = 0; i < count; i++) {
            MqlCalendarEvent event;
            if(CalendarEventGet(values[i].event_id, event)) {
               // Chỉ lọc tin quan trọng (Cao - High)
               // tầm quan trọng: CALENDAR_IMPORTANCE_HIGH = 3
               if(event.importance == CALENDAR_IMPORTANCE_HIGH) {
                  // Chỉ lọc tin liên quan đến đồng USD hoặc đồng tiền của Symbol hiện tại (ví dụ EUR đối với EURUSD)
                  string currency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
                  string profitCur = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
                  
                  if(event.code == "USD" || event.code == currency || event.code == profitCur) {
                     newsDescription = StringFormat("Tin quan trong [%s]: %s vao luc %s", 
                                                    event.code, event.name, TimeToString(values[i].time, TIME_DATE|TIME_MINUTES));
                     return true; // Phát hiện tin tức cấm giao dịch
                  }
               }
            }
         }
      }
      #endif

      return false;
   }
};

#endif
