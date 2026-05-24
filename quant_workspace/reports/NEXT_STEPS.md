# NEXT OPERATIONAL STEPS (NEXT_STEPS.md)
> Mode: Safe / Non-interactive Verification

To continue the verification and development of the system in a safe and deterministic manner, execute the following steps:

---

## 📋 ACTION ITEM ROADMAP

### Step 1: Activate Isolated Environment
Before running any script or visualizer in this workspace, always activate the virtual environment:
```powershell
# Windows PowerShell
.\quant_workspace\.venv\Scripts\Activate.ps1
```

### Step 2: Run Deterministic Unit Tests
Run the pytest test suite to verify that core math routines and regime detectors pass:
```powershell
pytest quant_workspace/tests/
```

### Step 3: Run Observability Exporter & Dashboard
To visualize the real-time simulation metrics, launch the Streamlit dashboard:
```powershell
streamlit run quant_workspace/dashboard/visualizer.py
```

### Step 4: Rebuild Code Graph After Edits
If you add or modify files in `quant_workspace/core/` or MQL5 includes, rebuild the code graph to keep AI agents aware of imports:
```powershell
python quant_workspace/scripts/build_code_graph.py
```
