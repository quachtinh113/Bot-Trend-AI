# Hướng Dẫn Tích Hợp & Kiểm Thử — Gia Cat Institutional Upgrade

Tài liệu này hướng dẫn cách tích hợp các module quản lý rủi ro nâng cao (`.mqh`) đã xây dựng vào mã nguồn chính của EA **GiaCat_Ultimate_Session.mq5**.

---

## 1. Khai báo thư viện và khai báo biến toàn cục

Thêm các chỉ thị `#include` ở phần đầu của mã nguồn EA chính:

```mql5
#include <GiaCat/regime_engine.mqh>
#include <GiaCat/volatility_engine.mqh>
#include <GiaCat/session_governor.mqh>
#include <GiaCat/equity_defense.mqh>
#include <GiaCat/audit_logger.mqh>

// Khai báo đối tượng các Engine toàn cục
CRegimeEngine      regimeEngine;
CVolatilityEngine  volatilityEngine;
CSessionGovernor   sessionGovernor;
CEquityDefense     equityDefense;
CAuditLogger       auditLogger;

// Biến lưu trữ trạng thái hoạt động thực tế
ENUM_MARKET_REGIME   currentRegime = REGIME_RANGING;
RegimeActions        activeActions;
RiskMetrics          currentRiskMetrics;
datetime             firstOrderTime = 0; // Thời gian mở lệnh đầu tiên của rổ lệnh hiện tại
int                  lastSlippagePoints = 0; // Trượt giá đo được từ giao dịch gần nhất
```

---

## 2. Khai báo Input Parameters mới

Bổ sung các tham số cấu hình này vào phần khai báo `input` của EA:

```mql5
//--- Institutional Upgrade Parameters
input group "=== 12. INSTITUTIONAL UPGRADE - REGIME & VOLATILITY ==="
input bool   InpATRGridEnable      = true;     // Bật Dynamic Grid theo ATR
input double InpATRMultiplier      = 1.5;      // Hệ số nhân ATR M15
input int    InpMinGridPoints      = 150;      // Khoảng cách lưới tối thiểu (pts)
input int    InpMaxGridPoints      = 1200;     // Khoảng cách lưới tối đa (pts)

input group "=== 13. INSTITUTIONAL UPGRADE - RISK GOVERNANCE ==="
input bool   InpUseSessionGovernor = true;     // Bật Session Governor & News Blackout
input double InpMaxDDVelocity      = 2.0;      // Tốc độ tăng trưởng Drawdown tối đa (%/phút)
input double InpMaxBasketAgeHours  = 48.0;     // Tuổi rổ lệnh tối đa trước khi xử lý (giờ)
input double InpMaxMarginDropSpeed = 100.0;    // Tốc độ tụt Margin Level tối đa (%/phút)
input double InpMaxSpreadMultiplier = 3.0;     // Hệ số giãn spread tối đa so với trung bình
input int    InpMaxSlippagePoints  = 100;      // Độ trượt giá tối đa cho phép (pts)
```

---

## 3. Khởi tạo trong hàm `OnInit()`

Bổ sung logic khởi tạo các Engine trong hàm `OnInit()` của EA:

```mql5
int OnInit()
{
   // Khởi tạo Regime Engine
   if(!regimeEngine.Init(Symbol(), 100)) {
      Print("GiaCat EA: Khoi tao Regime Engine THAT BAI!");
      return(INIT_FAILED);
   }

   // Khởi tạo Volatility Engine
   if(!volatilityEngine.Init(Symbol(), InpATRGridEnable, InpATRMultiplier, InpMinGridPoints, InpMaxGridPoints)) {
      Print("GiaCat EA: Khoi tao Volatility Engine THAT BAI!");
      return(INIT_FAILED);
   }

   // Khởi tạo Session Governor
   if(!sessionGovernor.Init(Symbol(), InpUseNewsFilter, InpNewsBeforeMin, InpNewsAfterMin)) {
      Print("GiaCat EA: Khoi tao Session Governor THAT BAI!");
      return(INIT_FAILED);
   }

   // Khởi tạo Equity Defense Engine
   equityDefense.Init(Symbol(), InpMaxDDVelocity, InpMaxBasketAgeHours, InpMaxMarginDropSpeed, InpMaxSpreadMultiplier, InpMaxSlippagePoints);

   Print("GiaCat EA: Khoi tao toan bo Engine rui ro nang cao THANH CONG!");
   return(INIT_SUCCEEDED);
}
```

---

## 4. Tích hợp Logic kiểm tra vào hàm `OnTick()`

Mỗi khi có tick mới, EA cần chạy các kiểm tra phòng vệ trước khi cho phép bất kỳ hành động mở lệnh/DCA nào:

```mql5
void OnTick()
{
   // 1. Cập nhật Market Regime định kỳ (Ví dụ mỗi nến H1 hoặc 1 phút)
   static datetime lastRegimeCheck = 0;
   if(TimeCurrent() - lastRegimeCheck >= 60) {
      string reason = "";
      currentRegime = regimeEngine.DetectRegime(reason);
      regimeEngine.GetRegimeActions(currentRegime, activeActions);
      lastRegimeCheck = TimeCurrent();
   }

   // 2. Xác định Phiên và kiểm tra News Blackout
   int gmtHour = 0;
   ENUM_TRADING_SESSION currentSession = sessionGovernor.GetCurrentSession(gmtHour);
   
   bool allowMeanReversion = true;
   double sessionLotScale = 1.0;
   bool requireDirFilter = false;
   bool restrictGridVol = false;
   
   if(InpUseSessionGovernor) {
      sessionGovernor.GetSessionConstraints(currentSession, allowMeanReversion, sessionLotScale, requireDirFilter, restrictGridVol);
   }

   string newsReason = "";
   bool isNewsBlackout = sessionGovernor.CheckNewsBlackout(newsReason);

   // 3. Đo lường rủi ro tài khoản và chạy Equity Defense
   string defenseReason = "";
   // Xác định thời gian mở lệnh đầu tiên của rổ lệnh hiện tại
   firstOrderTime = GetFirstOrderOpenTime(); 
   
   ENUM_DEFENSE_ACTION defenseAction = equityDefense.EvaluateDefense(firstOrderTime, lastSlippagePoints, currentRiskMetrics, defenseReason);

   // 4. Thực thi hành động tương ứng với kết quả phòng ngự
   if(defenseAction == DEFENSE_HARD_KILL) {
      Print("GUY HIEM CAP DO 4: " + defenseReason);
      CloseAllPositions("HARD_KILL: " + defenseReason);
      auditLogger.LogEvent("HARD_KILL", EnumToString(currentRegime), iATRVal(), iADXVal(), CurrentSpread(), currentRiskMetrics.dd_velocity, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), GetBasketAge(), defenseReason);
      ExpertRemove(); // Gỡ EA ra khỏi đồ thị để bảo vệ tuyệt đối tài sản
      return;
   }
   
   if(defenseAction == DEFENSE_EMERGENCY_EXIT) {
      // Kích hoạt co cụm rổ lệnh khẩn cấp hoặc tỉa lỗ rổ lệnh bằng Trim Manager
      Print("GUY HIEM CAP DO 3: " + defenseReason);
      ExecuteEmergencyBasketShrink();
      auditLogger.LogEvent("EMERGENCY_EXIT", EnumToString(currentRegime), iATRVal(), iADXVal(), CurrentSpread(), currentRiskMetrics.dd_velocity, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), GetBasketAge(), defenseReason);
   }

   // 5. Điều kiện cấm mở rổ lệnh mới (Base Order)
   bool blockNewBaskets = (defenseAction == DEFENSE_HARD_BLOCK) || isNewsBlackout;
   
   // 6. Điều kiện cấm mở lệnh DCA (DCA Block)
   bool blockDCA = (defenseAction == DEFENSE_SOFT_BLOCK) || 
                   activeActions.disable_new_dca || 
                   (restrictGridVol && currentRegime == REGIME_TRENDING);

   // Tích hợp các biến khóa này vào hàm mở lệnh Base và hàm mở lệnh DCA hiện tại của EA
}
```

---

## 5. Tích hợp Spacing động vào hàm tính khoảng cách Lưới DCA

Khi EA tính toán khoảng cách để đặt lệnh DCA tiếp theo (ví dụ lệnh thứ `n`):

```mql5
double GetNextSpacingPoints(int orderIndex)
{
   // Thay vì dùng khoảng cách cố định (InpHeDist) như cũ:
   // double spacing = InpHeDist;
   
   // Gọi Volatility Engine tính khoảng cách dựa trên ATR M15 kết hợp với Hệ số giãn của Regime
   double regimeMult = activeActions.grid_spacing_multiplier;
   int dynamicSpacing = volatilityEngine.CalculateSpacing(orderIndex, InpHeDist, InpHeStep, regimeMult);
   
   return (double)dynamicSpacing;
}
```

---

## 6. Tích hợp Giảm khối lượng (Lot Scaling) vào hàm tính Lot lệnh mới

Khi EA tính khối lượng cho lệnh đầu tiên (Base) hoặc lệnh DCA tiếp theo:

```mql5
double CalculateNextLot(int orderIndex, double baseLot)
{
   double lot = baseLot;
   
   // 1. Áp dụng cấp số nhân DCA nếu orderIndex > 0
   if(orderIndex > 0) {
      lot = baseLot * MathPow(InpHeLotMul, orderIndex);
   }

   // 2. Áp dụng Hệ số giảm khối lượng từ Market Regime (Trending/Transition)
   lot = lot * activeActions.lot_exposure_scale;
   
   // 3. Áp dụng Hệ số giảm khối lượng từ Session Governor (Phiên giao dịch Á, Âu, overlap)
   if(InpUseSessionGovernor) {
      int gmtHour = 0;
      ENUM_TRADING_SESSION session = sessionGovernor.GetCurrentSession(gmtHour);
      double sessionScale = 1.0;
      bool dummy1, dummy2, dummy3;
      sessionGovernor.GetSessionConstraints(session, dummy1, sessionScale, dummy2, dummy3);
      
      lot = lot * sessionScale;
   }
   
   // Kiểm tra giới hạn Min Lot / Max Lot của tài khoản
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   lot = MathRound(lot / lotStep) * lotStep;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   // Kiểm tra quy tắc cấm Martingale hệ số cao (> 1.25)
   if(orderIndex > 0 && lot / GetLotOfOrder(orderIndex - 1) > 1.25) {
      lot = GetLotOfOrder(orderIndex - 1) * 1.25;
      lot = MathRound(lot / lotStep) * lotStep;
   }
   
   return lot;
}
```

---

## 7. Tích hợp Logging sự kiện

Gọi hàm của Audit Logger mỗi khi EA thực hiện các hành động quan trọng:

- **Khi mở lệnh Base đầu tiên:**
  `auditLogger.LogEvent("ENTRY", EnumToString(currentRegime), GetH1ATR(), GetH1ADX(), GetSpread(), GetDrawdown(), GetMarginLevel(), 0, "Base Order Opened");`

- **Khi mở lệnh DCA:**
  `auditLogger.LogEvent("DCA", EnumToString(currentRegime), GetH1ATR(), GetH1ADX(), GetSpread(), GetDrawdown(), GetMarginLevel(), GetBasketAge(), StringFormat("DCA Order #%d Opened", orderIndex));`

- **Khi Trim Manager tỉa lệnh:**
  `auditLogger.LogEvent("TRIM", EnumToString(currentRegime), GetH1ATR(), GetH1ADX(), GetSpread(), GetDrawdown(), GetMarginLevel(), GetBasketAge(), "Trimmed Oldest Loser");`

- **Khi đóng toàn bộ rổ lệnh (Chốt lời/Cắt lỗ cuối tuần):**
  `auditLogger.LogEvent("CLOSE", EnumToString(currentRegime), GetH1ATR(), GetH1ADX(), GetSpread(), GetDrawdown(), GetMarginLevel(), GetBasketAge(), "Friday Close Target / Target Met");`
