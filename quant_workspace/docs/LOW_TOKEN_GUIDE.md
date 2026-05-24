# AGENT LOW TOKEN CONTEXT OPTIMIZATION GUIDE (LOW_TOKEN_GUIDE.md)

This guide outlines mandatory strategies to optimize context window space and minimize token expenditure when utilizing Antigravity and multi-agent workflows.

---

## 🔒 MANDATORY OPERATIONAL RESTRICTIONS

1. **Query Code Graph First:** AI agents MUST query the localized `code_graph_index.json` or run `build_code_graph.py` to identify required callers, callees, and dependencies BEFORE opening any source code files.
2. **Scoping File Reads:**
   - Maximum file reads per task: **8**
   - Maximum file edits per task: **4**
3. **No Unstructured Grep:** Avoid recursive grep on the entire workspace. Use specific subdirectory queries.
4. **Summary Preservation:** Prefer metadata files and structural logs over raw log/backtest streams.
5. **No Essays:** Limit verbal discussions. All outputs must be operational, concise, and direct.

---

## 🛠️ LOW TOKEN CONTEXT TRUNCATION
- When reading logs, always use trailing flags (e.g., `Get-Content -Tail 50` or `tail -n 50`) to avoid pulling megabytes of textual dumps into the context.
- When generating reports, use bullet points, tables, and short concise summaries.
- Keep comments and docstrings in code focused and structural.
