# LOCAL CODE GRAPH QUERY POLICY (CODE_GRAPH_POLICY.md)
> Mode: Hard Governance

To minimize token usage and prevent context overflow, AI agents are governed by this mandatory policy.

---

## 📋 RULES OF ENGAGEMENT
1. **Mandatory Query:** AI agents MUST query [code_graph_index.json](file:///d:/09_Bot%20Trend%20AI/quant_workspace/reports/code_graph_index.json) to map dependencies before making any file reads.
2. **Ast Parsing Only:** The code graph is constructed locally using AST-based parsing on python packages and clean symbol maps on MQL5 includes.
3. **Traversal Limit:** Dependency mapping is restricted to a maximum depth of **2**.
4. **Ignore Pattern:**
   - `.venv/`
   - `node_modules/`
   - `dist/`, `build/`, `logs/`, `reports/`
   - Temporary cache directories

---

## 🛠️ CODE GRAPH REBUILDING
- The code graph should be rebuilt after modifying any file in the core quant pipeline. Rebuilding is done by running:
  `python scripts/build_code_graph.py`
