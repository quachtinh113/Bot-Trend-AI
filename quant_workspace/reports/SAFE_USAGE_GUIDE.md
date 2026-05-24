# SAFE AI OPERATIONS & USAGE GUIDE (SAFE_USAGE_GUIDE.md)
> Severity: CRITICAL / System Safety

This guide defines the boundaries of AI-guided operations within this repository to prevent unwanted account exposure or runtime failures.

---

## 🚫 PROTECTED ZONE CONFIGURATION
The core risk scoring and trade execution gates are designated as **PROTECTED COMPONENTS**:
- `quant_workspace/risk/`
- `quant_workspace/execution/`
- `Bot Trend AI/Include/GiaCat/survival_score_engine.mqh`
- `Bot Trend AI/Include/GiaCat/account_guard.mqh`

**Rule:** AI agents are forbidden from automatically editing or refactoring these components without explicit `HUMAN_APPROVED` instructions.

---

## 🔒 CODE GRAPH MOCK CHECK RULES
Before reading or editing files, the AI must query the local code graph. This prevents context bloat and enforces deterministic call traversals.

1. **Step 1:** Run `scripts/build_code_graph.py` or read `reports/code_graph_index.json`.
2. **Step 2:** Focus edits strictly to the scope of caller/callee depth 2.
3. **Step 3:** Perform targeted `pytest` validation rather than full system runtime tests to conserve local resources.
