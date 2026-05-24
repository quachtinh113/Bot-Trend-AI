# NOWTRADING QUANT RISK CONSTITUTION (RISK_CONSTITUTION.md)
> Severity Level: HIGH / Sovereign Rules

This constitution establishes the supreme, non-negotiable risk rules governing the trading system. No AI agent, automated pipeline, or market signal may bypass these rules.

---

## 🏛️ ARTICLE 1 — THE PRINCIPLE OF SOVEREIGN VETO
1. **Absolute Authority:** The Risk Engine (`Sentinel`) holds supreme veto authority over all transactional instructions.
2. **Advisory Signal Mode:** Trading algorithms, neural net predictions, and machine learning models are classified as **advisory only**.
3. **Mechanical Guard:** If the Risk Engine fails to load, initializes improperly, or returns a veto (`Veto = true`), the entire execution framework MUST freeze and enter `NO_TRADE` safe mode.

---

## 🛡️ ARTICLE 2 — SYSTEM DEFENSE THRESHOLDS

### 1. Daily & Weekly Drawdown Limits
- **Daily Budget:** `2.0%` of daily starting equity.
- **Weekly Budget:** `5.0%` of weekly starting equity.
- **Hard Kill Capping:** `8.0%` weekly starting drawdown triggers immediate position clearance and removal of the EA from all charts.

### 2. Margin Safety Guard
- **Margin Level > 500%:** Normal trading state.
- **Margin Level <= 500%:** `WARNING` notification dispatched.
- **Margin Level <= 300%:** `SOFT_BLOCK` (DCA nhồi lệnh bị cấm hoàn toàn).
- **Margin Level <= 250%:** `SAFE_MODE` (Chặn rổ lệnh mới hoàn toàn, lot scale giảm 60%).
- **Margin Level <= 180%:** `HARD_KILL` (Cắt lỗ toàn bộ rổ lệnh và tắt máy khẩn cấp).

### 3. Friday Close Protocol
- **Friday 18:00 Broker Time:** Stop opening new basket orders (`NO_NEW_BASKET`).
- **Friday 23:45 Broker Time:** Close all active trades (both winning and losing) to avoid weekend Gap risks.

---

## ⚙️ ARTICLE 3 — DETERMINISTIC TESTING MANDATE
- No changes to the `risk/` or `execution/` packages may be deployed without successfully passing a comprehensive suite of `pytest` deterministic test scenarios.
- All risk events (warnings, blocks, hard kills) must be logged in double format (both structured `.json` telemetry and human-readable `.csv` log trails) with high-entropy account masking.
