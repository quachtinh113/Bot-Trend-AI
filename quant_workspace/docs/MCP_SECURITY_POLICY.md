# SAFE MCP TOOL REGISTRY SECURITY POLICY (MCP_SECURITY_POLICY.md)
> Mode: High Security Sandbox

This policy governs all Model Context Protocol (MCP) server configurations and tool registries exposed to AI agents within this workspace.

---

## 🏛️ 1. CONTEXT CONTAINMENT GENERAL POLICY
1. **Sandboxed Operation:** All file manipulation and testing operations MUST be constrained strictly to the `quant_workspace/` folder.
2. **Deterministic Registry:** Only predefined tool schemas listed in the `mcp_allowed_tools.json` registry may be loaded.
3. **Audit Trails:** Any tool invocation must log structural call timestamps to `audit/mcp_security_audit.log`.

---

## 🛠️ 2. CATEGORIZED MCP TOOL REGISTRIES

### 1. Allowed Tools (Predefined Scope)
- **`file_read_scoped`:** Scoped to read files only under workspace root.
- **`grep_limited`:** Case-specific search with maximum line matches of 50.
- **`run_targeted_tests`:** Calls `pytest` on individual test files.
- **`risk_summary`:** Returns Sentinel metrics without exposing code logic.
- **`compile_check`:** Compiles MQL5 files without executing.

### 2. Forbidden Tools (Prohibited Scope)
- **`unrestricted_shell`:** Direct shell execution outside sandbox.
- **`unrestricted_repo_scan`:** Recursive broad file indexing.
- **`live_trade_execution`:** Any direct order sending to MT5 live servers.
- **`credential_reader`:** Reading raw environment files (like passwords).
