# Quy Cách Xuất Dữ Liệu Giám Sát (Telemetry Dashboard Spec) — Gia Cat Quant V2

Hệ thống **Gia Cat Quant Survival Engine** được thiết kế để xuất dữ liệu trạng thái thời gian thực ra 3 định dạng: **JSON**, **CSV** và **HTML Summary**. Điều này giúp kết nối dữ liệu trực tiếp với hệ thống Web Dashboard giám sát từ xa hoặc lưu trữ làm báo cáo định kỳ.

---

## 1. Đầu Ra Định Dạng JSON (`GiaCat_Telemetry.json`)
Dữ liệu JSON được cập nhật liên tục sau mỗi tick hoặc mỗi phút để hiển thị trực tiếp lên Dashboard trực quan.

### 📋 Cấu trúc Schema:
```json
{
  "timestamp": "2026.05.23 21:00:00",
  "account": {
    "login": 1234567,
    "currency": "USDCent",
    "balance": 20000.0,
    "equity": 18200.0,
    "floating_dd_pct": 9.0,
    "margin_level": 550.0
  },
  "survival_engine": {
    "survival_score": 75.5,
    "state": "REDUCE_RISK",
    "weekly_start_equity": 20000.0,
    "weekly_drawdown_pct": 9.0,
    "daily_loss_cent": 1800.0,
    "daily_budget_cent": 4000.0
  },
  "market_regime": {
    "current_regime": "TRANSITION",
    "adx_h1": 22.4,
    "atr_h1": 0.00185,
    "avg_atr_100_h1": 0.00150,
    "atr_acceleration_m15": 1.2
  },
  "predictive_volatility": {
    "breakout_warning": false,
    "bb_width_m15": 0.0018,
    "spread_acceleration": 2.0,
    "tick_rate_5s": 15
  },
  "portfolio_exposure": {
    "total_buy_lots": 0.15,
    "total_sell_lots": 0.05,
    "usd_concentration_lots": -0.10,
    "margin_concentration_pct": 5.2,
    "correlated_exposure_lots": 0.08
  },
  "active_baskets": [
    {
      "symbol": "EURUSD",
      "state": "STRESSED",
      "order_count": 5,
      "floating_loss_cent": 1800.0,
      "distance_to_be_points": 180,
      "adverse_excursion_points": 240,
      "recovery_velocity_pts_min": 12.5,
      "efficiency_ratio": 0.12,
      "age_hours": 3.5
    }
  ]
}
```

---

## 2. Đầu Ra Định Dạng CSV (`GiaCat_Timeline.csv`)
Tập tin CSV lưu giữ nhật ký lịch sử thay đổi trạng thái của robot để phục vụ phân tích hồi quy (back-analysis) hiệu quả.

### 📊 Các Cột Dữ Liệu:
`Timestamp,SurvivalScore,SurvivalState,Regime,ADX_H1,ATR_H1,BB_Width,Spread,Slippage,MarginLevel,TotalLots,USD_Concentration,BasketOrders,FloatingDD,Reason`

### 📝 Ví dụ Bản ghi:
```csv
2026.05.23 21:00:00,75.5,REDUCE_RISK,TRANSITION,22.4,0.00185,0.0018,20,0,550.0,0.20,-0.10,5,9.0,Normal Grid Running
2026.05.23 21:05:00,35.0,SAFE_MODE,TRENDING,27.5,0.00280,0.0035,50,0,280.0,0.45,-0.25,8,12.5,Weekly DD reached 5.0%
```

---

## 3. Bản tóm tắt HTML (`GiaCat_Dashboard.html`)
MQL5 tự động xuất một tệp HTML tĩnh để người dùng có thể mở trực tiếp từ điện thoại hoặc trình duyệt web liên kết với VPS.

### 🎨 Giao diện hiển thị:
- **Card KPI nổi bật**: Hiển thị **Survival Score** màu sắc tương ứng:
  - `Score >= 60`: Xanh lá cây (NORMAL)
  - `60 > Score >= 40`: Vàng (REDUCE RISK)
  - `40 > Score >= 25`: Cam (SAFE MODE)
  - `25 > Score >= 15`: Đỏ (HARD BLOCK)
  - `Score < 15`: Đỏ sẫm nhấp nháy (HARD KILL)
- **Bảng trạng thái danh mục (Exposure Heatmap)**: Cảnh báo tỷ lệ ký quỹ và nồng độ rủi ro đồng USD.
- **Bảng đo lường rổ lệnh (Basket Health Report)**: Liệt kê chi tiết số lệnh, độ trôi ngược (adverse excursion) và tốc độ hồi phục của từng rổ đang mở.
- **Đồ thị Mini (Risk State Timeline)**: Trực quan hóa diễn biến của mức sụt giảm tài khoản trong ngày.
