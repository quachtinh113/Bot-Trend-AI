//+------------------------------------------------------------------+
//|                                                 mock_test_ea.mq5 |
//|                                  Copyright 2026, Bot Trend AI    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Bot Trend AI"
#property link      "https://www.mql5.com"
#property version   "1.00"

// Khai báo include sử dụng đường dẫn tương đối từ Include của MT5
// Vì các file đặt trong Include/GiaCat/ ta dùng include tương ứng
#include "Include/GiaCat/regime_engine.mqh"
#include "Include/GiaCat/volatility_engine.mqh"
#include "Include/GiaCat/session_governor.mqh"
#include "Include/GiaCat/equity_defense.mqh"
#include "Include/GiaCat/audit_logger.mqh"

// Khai báo đối tượng các Engine toàn cục
CRegimeEngine      regimeEngine;
CVolatilityEngine  volatilityEngine;
CSessionGovernor   sessionGovernor;
CEquityDefense     equityDefense;
CAuditLogger       auditLogger;

// Các biến lưu trữ trạng thái hoạt động thực tế
ENUM_MARKET_REGIME   currentRegime = REGIME_RANGING;
RegimeActions        activeActions;
RiskMetrics          currentRiskMetrics;
datetime             firstOrderTime = 0;
int                  lastSlippagePoints = 0;

//--- Parameters
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

// Cấu hình tin tức mẫu
input bool   InpUseNewsFilter      = true;     // Bật bộ lọc tin tức
input int    InpNewsBeforeMin      = 30;       // Thời gian dừng trước tin (phút)
input int    InpNewsAfterMin       = 30;       // Thời gian dừng sau tin (phút)
input double InpHeDist             = 200.0;    // Khoảng cách lưới cơ bản
input double InpHeStep             = 1.2;      // Hệ số nhân khoảng cách lưới
input double InpHeLotMul           = 1.18;     // Hệ số nhân Lot rổ

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Khởi tạo các bộ máy kiểm soát rủi ro
   if(!regimeEngine.Init(Symbol(), 100)) {
      Print("GiaCat MockEA: Khoi tao Regime Engine THAT BAI!");
      return(INIT_FAILED);
   }

   if(!volatilityEngine.Init(Symbol(), InpATRGridEnable, InpATRMultiplier, InpMinGridPoints, InpMaxGridPoints)) {
      Print("GiaCat MockEA: Khoi tao Volatility Engine THAT BAI!");
      return(INIT_FAILED);
   }

   if(!sessionGovernor.Init(Symbol(), InpUseNewsFilter, InpNewsBeforeMin, InpNewsAfterMin)) {
      Print("GiaCat MockEA: Khoi tao Session Governor THAT BAI!");
      return(INIT_FAILED);
   }

   equityDefense.Init(Symbol(), InpMaxDDVelocity, InpMaxBasketAgeHours, InpMaxMarginDropSpeed, InpMaxSpreadMultiplier, InpMaxSlippagePoints);

   Print("GiaCat MockEA: Khoi tao cac he thong rui ro hoan tat!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("GiaCat MockEA: Go EA khoi do thi, ly do: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Cập nhật Market Regime định kỳ
   static datetime lastRegimeCheck = 0;
   if(TimeCurrent() - lastRegimeCheck >= 60) {
      string reason = "";
      currentRegime = regimeEngine.DetectRegime(reason);
      regimeEngine.GetRegimeActions(currentRegime, activeActions);
      lastRegimeCheck = TimeCurrent();
      Print("GiaCat MockEA: Cap nhat regime: ", reason);
   }

   // 2. Kiểm tra phiên và News Blackout
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
   if(isNewsBlackout) {
      Print("GiaCat MockEA: Phat hien News Blackout: ", newsReason);
   }

   // 3. Đo lường rủi ro tài khoản và chạy Equity Defense
   string defenseReason = "";
   ENUM_DEFENSE_ACTION defenseAction = equityDefense.EvaluateDefense(firstOrderTime, lastSlippagePoints, currentRiskMetrics, defenseReason);

   if(defenseAction == DEFENSE_HARD_KILL) {
      Print("GiaCat MockEA: KICH HOAT HARD KILL! Ly do: ", defenseReason);
      // Log event
      auditLogger.LogEvent("HARD_KILL", EnumToString(currentRegime), 0.00012, 22.5, (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD), currentRiskMetrics.dd_velocity, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 3600, defenseReason);
      ExpertRemove();
      return;
   }
   
   if(defenseAction == DEFENSE_EMERGENCY_EXIT) {
      Print("GiaCat MockEA: KICH HOAT EMERGENCY EXIT! Ly do: ", defenseReason);
      auditLogger.LogEvent("EMERGENCY_EXIT", EnumToString(currentRegime), 0.00012, 22.5, (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD), currentRiskMetrics.dd_velocity, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 3600, defenseReason);
   }

   // 4. Test tính toán Spacing động
   double spacing = GetNextSpacingPoints(3);
   
   // 5. Test tính toán Lot size
   double lot = CalculateNextLot(3, 0.01);
}

//+------------------------------------------------------------------+
//| Tính toán Spacing dòng cho test                                  |
//+------------------------------------------------------------------+
double GetNextSpacingPoints(int orderIndex)
{
   double regimeMult = activeActions.grid_spacing_multiplier;
   int dynamicSpacing = volatilityEngine.CalculateSpacing(orderIndex, InpHeDist, InpHeStep, regimeMult);
   return (double)dynamicSpacing;
}

//+------------------------------------------------------------------+
//| Tính toán Lot size cho test                                      |
//+------------------------------------------------------------------+
double CalculateNextLot(int orderIndex, double baseLot)
{
   double lot = baseLot;
   if(orderIndex > 0) {
      lot = baseLot * MathPow(InpHeLotMul, orderIndex);
   }
   lot = lot * activeActions.lot_exposure_scale;
   return lot;
}
