# -*- coding: utf-8 -*-
"""
Created on Mon Aug 24 22:58:20 2026
EMG Signal Processing Dashboard

@author: Eza Yasir
Date: August 2026
Description: Interactive dashboard for visualizing processed EMG data
             (Isometric and Isotonic conditions)
"""



import streamlit as st
import pandas as pd
import numpy as np
import os
import plotly.graph_objects as go
from scipy import signal


# ==========================================
# PAGE CONFIGURATION
# ==========================================
st.set_page_config(page_title="EMG Signal Processing Dashboard", layout="wide")

st.title("EMG Signal Processing Dashboard")
st.subheader("Interactive visualization of processed sEMG data")

# ==========================================
# DATA LOADING (CACHED, PER CONDITION)
# ==========================================
# Isometric files: filtered_emg3_signal.csv, emg3_envelope_raw.csv,
#                   emg3_envelope_smoothed.csv, sampling_info3.csv
#                   -> full 0-60s (no instability found in diagnostics)
# Isotonic files:  same names + "_isotonica" suffix
#                   -> trimmed 20-60s (diagnostics showed a genuine
#                      startup transient in the first 20s for this
#                      condition -- see README for the evidence)

@st.cache_data
def load_condition_data(condition):
    base_dir = os.path.dirname(os.path.abspath(__file__))
    folder_path = os.path.join(base_dir, "python_dashboard3_data")

    suffix = "" if condition == "Isometric" else "_isotonica"

    filtered = pd.read_csv(os.path.join(folder_path, f"filtered_emg3_signal{suffix}.csv"))
    env_raw = pd.read_csv(os.path.join(folder_path, f"emg3_envelope_raw{suffix}.csv"))
    env_smooth = pd.read_csv(os.path.join(folder_path, f"emg3_envelope_smoothed{suffix}.csv"))
    info = pd.read_csv(os.path.join(folder_path, f"sampling_info3{suffix}.csv"))

    try:
        fs = int(info.loc[info['Parameter'] == 'Fs', 'Value'].iloc[0])
    except:
        fs = 2000

    for df in (filtered, env_raw, env_smooth):
        df['Time_s'] = pd.to_numeric(df['Time_s'])

    return filtered, env_raw, env_smooth, fs

# ==========================================
# SIDEBAR CONTROLS
# ==========================================
st.sidebar.header("Controls")

# Select Condition FIRST -- everything else depends on this
condition_options = ["Isometric", "Isotonic"]
selected_condition = st.sidebar.selectbox("Select Condition", condition_options)

# Load data for the selected condition
filtered_df, env_raw_df, env_smooth_df, FS = load_condition_data(selected_condition)

# Select Channel
channel_options = ["BCC", "BCL"]
selected_channel = st.sidebar.selectbox("Select Channel", channel_options)

# Time Range Slider -- bounds come from the loaded data itself, so this
# automatically adapts: Isometric spans 0-60s, Isotonic spans 20-60s
# (the first 20s was excluded during processing -- see caption below).
min_time = float(filtered_df['Time_s'].min())
max_time = float(filtered_df['Time_s'].max())

# Default to the first 20s of whatever window is actually available,
# instead of hardcoding 0-20 (which would be empty for Isotonic).
default_end = min(min_time + 20.0, max_time)

time_range = st.sidebar.slider(
    "Time Range (seconds)",
    min_value=min_time,
    max_value=max_time,
    value=(min_time, default_end),
    step=0.1
)

# Let the person know why the available range differs by condition,
# so it doesn't look like a bug when Isotonic starts at 20s.
if selected_condition == "Isotonic":
    st.sidebar.caption(
        "Note: first 20s excluded for this condition based on stability "
        "diagnostics (RMS ratio + drift analysis showed a startup "
        "transient). See README for details."
    )
else:
    st.sidebar.caption(
        "Full 60s used for this condition -- diagnostics showed no "
        "instability in the first 20s."
    )

# ==========================================
# HELPER FUNCTIONS FOR METRICS
# ==========================================
def calculate_metrics(y, fs):
    rms = np.sqrt(np.mean(y**2))

    # Spectral metrics
    f, Pxx = signal.welch(y, fs=fs, nperseg=min(1024, len(y)))
    if np.sum(Pxx) > 0:
        mdf = f[np.argmax(np.cumsum(Pxx) >= np.sum(Pxx)/2)]
        spectral_entropy = -np.sum((Pxx/np.sum(Pxx)) * np.log2(Pxx/np.sum(Pxx) + 1e-10))
    else:
        mdf = 0
        spectral_entropy = 0

    skewness = pd.Series(y).skew()
    kurtosis = pd.Series(y).kurtosis()

    return rms, mdf, spectral_entropy, skewness, kurtosis

# ==========================================
# MAIN DASHBOARD
# ==========================================
# 1. FILTERED SIGNAL PLOT
st.subheader(f"Filtered EMG Signal ({selected_channel}, {selected_condition})")

mask_filtered = (filtered_df['Time_s'] >= time_range[0]) & (filtered_df['Time_s'] <= time_range[1])
filtered_window = filtered_df[mask_filtered]

fig1 = go.Figure()
fig1.add_trace(go.Scatter(
    x=filtered_window['Time_s'],
    y=filtered_window[f'{selected_channel}_Filtered'],
    mode='lines',
    name=f'{selected_channel} Filtered',
    line=dict(width=1)
))
fig1.update_layout(
    xaxis_title="Time (s)",
    yaxis_title="Amplitude (V)",
    height=400,
    margin=dict(l=0, r=0, t=30, b=0)
)
st.plotly_chart(fig1, use_container_width=True)

# 2. MUSCLE ACTIVATION ENVELOPE PLOT
st.subheader(f"Muscle Activation - Smoothed Envelope ({selected_condition})")

# Data is static (pre-processed in MATLAB), so no auto-refresh is needed --
# the chart re-renders when the sidebar controls change, same as the plot above.
mask_env = (env_smooth_df['Time_s'] >= time_range[0]) & (env_smooth_df['Time_s'] <= time_range[1])
env_window = env_smooth_df[mask_env]

fig2 = go.Figure()
fig2.add_trace(go.Scatter(
    x=env_window['Time_s'],
    y=env_window[f'{selected_channel}_Envelope_Smoothed'],
    mode='lines',
    name=f'{selected_channel} Envelope',
    line=dict(width=2, color='orange')
))
fig2.update_layout(
    xaxis_title="Time (s)",
    yaxis_title="RMS Amplitude",
    height=300,
    margin=dict(l=0, r=0, t=30, b=0)
)
st.plotly_chart(fig2, use_container_width=True)

# 3. SIGNAL METRICS
st.subheader("Signal Metrics")

metric_window_filtered = filtered_window[f'{selected_channel}_Filtered'].dropna().values
if len(metric_window_filtered) > 0:
    rms, mdf, spec_entropy, skew, kurt = calculate_metrics(metric_window_filtered, FS)

    col1, col2, col3, col4, col5 = st.columns(5)
    col1.metric("RMS", f"{rms:.6f}")
    col2.metric("Median Freq", f"{mdf:.2f} Hz")
    col3.metric("Spectral Entropy", f"{spec_entropy:.4f}")
    col4.metric("Skewness", f"{skew:.4f}")
    col5.metric("Kurtosis", f"{kurt:.4f}")
else:
    st.warning("No data in the selected time range for metrics.")

st.caption(
    f"Condition: {selected_condition} | Sampling Frequency: {FS} Hz | "
    f"Data range: {min_time:.1f}-{max_time:.1f}s | Data loaded from MATLAB export."
)
