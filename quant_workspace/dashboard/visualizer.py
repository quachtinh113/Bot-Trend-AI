import streamlit as st
import pandas as pd
import json
import os
import time

st.set_page_config(
    page_title="NowTrading Quant V9 Telemetry",
    layout="wide",
    initial_sidebar_state="expanded"
)

st.title("🛡️ NowTrading Quant V9 Survival Telemetry Dashboard")
st.markdown("---")

# File paths
current_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
telemetry_path = os.path.join(current_dir, "telemetry", "quant_state.json")

# Initialize default telemetry file if not exists
if not os.path.exists(telemetry_path):
    os.makedirs(os.path.dirname(telemetry_path), exist_ok=True)
    default_state = {
        "timestamp": time.strftime("%Y.%m.%d %H:%M:%S"),
        "survival_score": 100.0,
        "survival_state": "NORMAL",
        "weekly_drawdown_pct": 0.0,
        "margin_level": 76360.99,
        "is_demo_account": True,
        "veto_count": 0
    }
    with open(telemetry_path, "w", encoding="utf-8") as f:
        json.dump(default_state, f, indent=2)

# Load data
try:
    with open(telemetry_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    st.error(f"Error loading telemetry: {str(e)}")
    data = {}

# Layout
col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric(
        label="Survival Score",
        value=f"{data.get('survival_score', 100.0):.1f}",
        delta=data.get('survival_state', 'NORMAL')
    )

with col2:
    st.metric(
        label="Weekly Drawdown (%)",
        value=f"{data.get('weekly_drawdown_pct', 0.0):.2f}%",
        delta="-Safe" if data.get('weekly_drawdown_pct', 0.0) < 5.0 else "-Warning"
    )

with col3:
    st.metric(
        label="Margin Level",
        value=f"{data.get('margin_level', 0.0):.2f}%",
        delta="Safe" if data.get('margin_level', 0.0) > 300.0 else "Unsafe"
    )

with col4:
    st.metric(
        label="Sentinel Veto Count",
        value=data.get('veto_count', 0),
        delta="0 Violations" if data.get('veto_count', 0) == 0 else "Veto Active"
    )

st.markdown("---")
st.subheader("📊 System Telemetry State Log")
st.json(data)
