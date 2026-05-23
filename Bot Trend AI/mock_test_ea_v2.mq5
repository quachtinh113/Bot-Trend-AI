//+------------------------------------------------------------------+
//|                                              mock_test_ea_v2.mq5 |
//|                                  Copyright 2026, Bot Trend AI    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Bot Trend AI"
#property link      "https://www.mql5.com"
#property version   "2.00"

// Include các file risk engine của Gia Cat Quant V2
#include "Include/GiaCat/regime_engine.mqh"
#include "Include/GiaCat/volatility_engine.mqh"
#include "Include/GiaCat/session_governor.mqh"
#include "Include/GiaCat/equity_defense.mqh"
#include "Include/GiaCat/audit_logger.mqh"
#include "Include/GiaCat/portfolio_engine.mqh"
#include "Include/GiaCat/basket_intelligence.mqh"
#include "Include/GiaCat/predictive_volatility.mqh"
#include "Include/GiaCat/smart_dca_engine.mqh"
#include "Include/GiaCat/survival_score_engine.mqh"

// Khai báo đối tượng các Engine toàn cục
CRegimeEngine           regimeEngine;
CVolatilityEngine       volatilityEngine;
CSessionGovernor        sessionGovernor;
CEquityDefense          equityDefense;
CAuditLogger            auditLogger;
CPortfolioEngine        portfolioEngine;
CBasketIntelligence     basketIntel;
CPredictiveVolatility   predictiveVol;
CSmartDCAEngine         smartDCA;
CSurvivalScoreEngine    survivalEngine;

// Các biến lưu trữ trạng thái hoạt động thực tế
ENUM_MARKET_REGIME   currentRegime = REGIME_RANGING;
RegimeActions        activeRegimeActions;
RiskMetrics          currentRiskMetrics;
BasketTelemetry      currentBasketTelemetry;
double               currentSurvivalScore = 100.0;
ENUM_SURVIVAL_STATE  currentSurvivalState = SURVIVAL_NORMAL;

// Các biến trạng thái logic
bool                 vetoNewBaskets = false;
bool                 vetoNewDCA = false;
double               survivalLotScale = 1.0;
double               survivalSpacingScale = 1.0;
string               survivalStateName = "NORMAL";

//--- V2 Upgraded Inputs
input group "=== 14. QUANT SURVIVAL V2 - PORTFOLIO EXPOSURE ==="
input double InpMaxDirectionalLots  = 3.0;      // Khối lượng tối đa một chiều (lots)
input double InpMaxCorrelatedLots   = 4.5;      // Khối lượng tối đa cặp tương quan (lots)
input double InpGlobalLotCap        = 5.0;      // Trần tổng lot toàn tài khoản
input double InpMaxMarginPct        = 15.0;     // % Ký quỹ sử dụng tối đa (%)

input group "=== 15. QUANT SURVIVAL V2 - BASKET INTELLIGENCE ==="
input int    InpStressedOrders      = 5;        // Ngưỡng lệnh Stress (lớp)
input int    InpCriticalOrders      = 10;       // Ngưỡng lệnh Nguy cấp (lớp)
input double InpMaxAgeLimitHours    = 48.0;     // Tuổi rổ lệnh giới hạn (giờ)
input double InpStressedDDPct       = 10.0;     // Drawdown stress (%)

input group "=== 16. QUANT SURVIVAL V2 - PREDICTIVE VOLATILITY ==="
input double InpBBSqueezeThreshold  = 0.0010;   // Tỷ lệ nén BB Width (M15)
input double InpATRAccelerationLimit= 10.0;     // Ngưỡng slope ATR M15 (pts)
input int    InpSpreadAccelerationLimit= 15;    // Ngưỡng giãn spread (pts/10 ticks)
input int    InpVacuumTickRate      = 3;        // Tick rate rỗng thanh khoản (ticks/5s)

input group "=== 17. QUANT SURVIVAL V2 - SMART DCA & SAFETY ==="
input double InpMinRecoveryProb     = 60.0;     // Xác suất hồi phục tối thiểu (%)
input double InpWeeklyDDLimit       = 8.0;      // Giới hạn Drawdown tuần (%)
input double InpDailyLossBudget     = 4000.0;    // Ngân sách rủi ro ngày (Cent)

// Các Input cơ bản khác từ V1
input double InpHeDist              = 200.0;    // Spacing cơ bản
input double InpHeStep              = 1.2;      // Spacing multiplier
input double InpHeLotMul            = 1.18;     // DCA lot multiplier
input bool   InpUseNewsFilter       = true;
input int    InpNewsBeforeMin       = 30;
input int    InpNewsAfterMin        = 30;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Khởi tạo các V1 Engine
   if(!regimeEngine.Init(Symbol(), 100)) return(INIT_FAILED);
   if(!volatilityEngine.Init(Symbol(), true, 1.5, 150, 1200)) return(INIT_FAILED);
   if(!sessionGovernor.Init(Symbol(), InpUseNewsFilter, InpNewsBeforeMin, InpNewsAfterMin)) return(INIT_FAILED);
   equityDefense.Init(Symbol(), 2.0, InpMaxAgeLimitHours, 100.0, 3.0, 100);

   // 2. Khởi tạo các V2 Engine
   portfolioEngine.SetLimits(InpMaxDirectionalLots, InpMaxCorrelatedLots, InpGlobalLotCap, InpMaxMarginPct);
   basketIntel.Init(Symbol(), InpStressedOrders, InpCriticalOrders, InpMaxAgeLimitHours, InpStressedDDPct);
   
   if(!predictiveVol.Init(Symbol(), InpBBSqueezeThreshold, InpATRAccelerationLimit, InpSpreadAccelerationLimit, InpVacuumTickRate)) {
      Print("GiaCat V2 EA: Khoi tao Predictive Volatility Engine THAT BAI!");
      return(INIT_FAILED);
   }
   
   smartDCA.Init(Symbol(), InpHeLotMul, InpMinRecoveryProb);
   survivalEngine.Init(Symbol(), InpDailyLossBudget, InpWeeklyDDLimit);

   Print("GiaCat V2 EA: Khoi tao toan bo portfolio & quant engines THANH CONG!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Cập nhật tick cho Predictive Volatility
   int currentSpread = (int)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
   predictiveVol.RecordTick(currentSpread);

   // 1. Master Risk Layer: Cập nhật Survival Score và kiểm soát Veto
   double dailyLoss = 500.0; // Giả lập mức thua lỗ ngày
   double curDD = equityDefense.GetCurrentDrawdown();
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double equitySlope = 1.0; // Giả lập dốc tài khoản dương
   
   currentSurvivalScore = survivalEngine.CalculateSurvivalScore(dailyLoss, curDD, marginLevel, equitySlope);
   currentSurvivalState = survivalEngine.GetSurvivalState(currentSurvivalScore);
   
   // Nhận luật Veto từ Master Risk Engine (Governance Rule 7, 8)
   survivalEngine.GetMasterRiskVeto(currentSurvivalState, vetoNewBaskets, vetoNewDCA, survivalLotScale, survivalSpacingScale, survivalStateName);

   if(currentSurvivalState == SURVIVAL_HARD_KILL) {
      Print("GiaCat V2 EA: HARD KILL TRIGGERED! Gỡ EA để bảo vệ tài khoản.");
      CloseAllPositions();
      ExpertRemove();
      return;
   }

   // 2. Chạy Regime Engine xác định trạng thái thị trường
   string regimeReason = "";
   currentRegime = regimeEngine.DetectRegime(regimeReason);
   regimeEngine.GetRegimeActions(currentRegime, activeRegimeActions);

   // 3. Đo lường sức khỏe rổ lệnh (Basket Intelligence)
   int openOrders = GetOpenOrdersCount();
   double realizedProfit = 100.0; // Giả lập profit đã chốt
   double distToBE = 150.0; // Giả lập khoảng cách BE
   datetime firstOrderTime = GetFirstOrderOpenTime();
   
   basketIntel.MeasureTelemetry(openOrders, dailyLoss, curDD, distToBE, realizedProfit, firstOrderTime, currentBasketTelemetry);
   ENUM_BASKET_STATE basketState = basketIntel.EvaluateState(currentBasketTelemetry, curDD);
   
   // Quyết định DCA dựa trên rổ (Governance Rule 4)
   bool basketAllowDCA = basketIntel.IsDCAAllowed(basketState);
   double basketLotScale = 1.0;
   double basketSpacingScale = 1.0;
   bool basketRecoveryOnly = false;
   bool basketTriggerTrim = false;
   basketIntel.GetGridAdjustments(basketState, basketLotScale, basketSpacingScale, basketRecoveryOnly, basketTriggerTrim);

   // 4. Phân tích biến động sớm (Predictive Volatility)
   double atrAcc = 0.0, bbWidth = 0.0;
   int tickRate = 0;
   double spreadAcc = 0.0;
   string volReason = "";
   bool breakoutWarning = predictiveVol.DetectBreakoutWarning(atrAcc, bbWidth, spreadAcc, tickRate, volReason);

   // 5. Kiểm tra Portfolio Exposure (Rủi ro danh mục)
   ENUM_POSITION_TYPE proposeType = POSITION_TYPE_BUY;
   double rawProposedLot = 0.01;
   double exposureMultiplier = portfolioEngine.GetExposureMultiplier(Symbol(), rawProposedLot, proposeType);

   // 6. Kiểm tra điều kiện mở DCA (Smart DCA Engine)
   double regimeScore = (currentRegime == REGIME_TRENDING) ? 80.0 : (currentRegime == REGIME_TRANSITION ? 40.0 : 10.0);
   double atrScore = MathMin(atrAcc * 5.0, 100.0);
   double trendPressure = (currentRegime == REGIME_TRENDING) ? 70.0 : 20.0;
   double basketHealth = 100.0 - (curDD * 4.0);
   double spreadQuality = (currentSpread < 30) ? 95.0 : 30.0;

   double recoveryProb = smartDCA.CalculateRecoveryProbability(regimeScore, atrScore, trendPressure, basketHealth, spreadQuality);
   bool isTrendAligned = true;
   string smartDcaReason = "";
   
   bool dcaExecutionApproved = smartDCA.EvaluateDCAExecution(openOrders, recoveryProb, isTrendAligned, 20, smartDcaReason);

   // === KIỂM TRA ĐIỀU KIỆN CUỐI CÙNG (DUMB EXECUTION ENGINE) ===
   // Risk Engine có quyền phủ quyết tuyệt đối (Veto):
   bool finalDCAAllowed = true;
   
   if(vetoNewDCA) finalDCAAllowed = false;                 // Veto từ Master Survival Engine
   if(!basketAllowDCA) finalDCAAllowed = false;             // Veto từ Basket State (Critical/Terminal)
   if(breakoutWarning) finalDCAAllowed = false;             // Veto từ Predictive Volatility Squeeze
   if(!dcaExecutionApproved) finalDCAAllowed = false;       // Veto từ Smart DCA Probability
   if(exposureMultiplier <= 0.0) finalDCAAllowed = false;   // Veto từ Portfolio Exposure Cap

   // In log giả lập hoạt động
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 10) {
      Print(StringFormat("GiaCat V2: Score=%d, State=%s, BasketState=%s, Prob=%.1f%%, DCAAllowed=%s",
                         (int)currentSurvivalScore, survivalStateName, EnumToString(basketState), recoveryProb, finalDCAAllowed ? "YES" : "NO"));
      lastLog = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
int GetOpenOrdersCount() {
   return 3; // Giả lập rổ có 3 lệnh
}

datetime GetFirstOrderOpenTime() {
   return TimeCurrent() - 7200; // Giả lập rổ mở được 2 tiếng
}

void CloseAllPositions() {
   Print("GiaCat V2 EA: Thực thi đóng toàn bộ các vị thế giao dịch.");
}
