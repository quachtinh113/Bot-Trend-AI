# QUANT TELEMETRY OBSERVABILITY REPORT (OBSERVABILITY_REPORT.md)
> Target Version: NowTrading Quant V9
> Mode: Deterministic Monitoring

This report establishes the telemetry specs and metric scraper configurations for system health monitoring.

---

## 📊 1. METRIC SCAPE ARCHITECTURE
Structured logs are generated as JSON lines at `logs/quant_runtime.log`.
A Streamlit visualizer pulls from `telemetry/` json outputs dynamically to expose metrics:

- `quant_survival_score`: Current survival score (0-100) calculated by CSurvivalScoreEngine.
- `weekly_drawdown_pct`: Current weekly drawdown relative to Starting Equity.
- `margin_level_pct`: Current account margin level.
- `veto_event_count`: Number of Sentinel veto actions logged.

---

## 🖥️ 2. CONFIGURATION PATHS
- **Scraper Configuration:** [prometheus.yml](file:///d:/09_Bot%20Trend%20AI/quant_workspace/infra/prometheus.yml) targets port `8000` metrics endpoint.
- **Dashboard Blueprint:** [grafana_dashboard.json](file:///d:/09_Bot%20Trend%20AI/quant_workspace/infra/grafana_dashboard.json) is ready for direct manual import to Grafana to visualize metrics.
- **Telemetry File Sandbox:** Real-time metrics write directly to `telemetry/quant_state.json`.
