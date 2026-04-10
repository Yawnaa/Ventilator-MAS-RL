"""
Ventilator MAS-RL Frontend Dashboard
基于多智能体协作（MAS）的呼吸机调控系统前端
"""

import streamlit as st
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import time
from streamlit_echarts import st_echarts
import json
from enum import Enum

# 页面配置
st.set_page_config(
    page_title="呼吸机MAS控制系统",
    page_icon="🫁",
    layout="wide",
    initial_sidebar_state="expanded"
)

# 暗色调主题CSS
st.markdown("""
<style>
    :root {
        --primary-color: #00f2ff;
        --success-color: #00ff88;
        --warning-color: #ff6b6b;
        --bg-dark: #0f1419;
        --bg-secondary: #1a1f2e;
        --text-primary: #e0e0e0;
        --text-secondary: #9ca3af;
    }
    
    body {
        background-color: var(--bg-dark);
        color: var(--text-primary);
    }
    
    .stMetricValue {
        font-size: 24px;
        font-weight: bold;
        color: var(--primary-color);
    }
    
    .agent-container {
        background-color: var(--bg-secondary);
        border-left: 3px solid var(--primary-color);
        padding: 15px;
        border-radius: 8px;
        margin-bottom: 15px;
    }
    
    .agent-active {
        border-left-color: var(--success-color);
    }
    
    .agent-warning {
        border-left-color: var(--warning-color);
        background-color: rgba(255, 107, 107, 0.1);
    }
    
    .decision-card {
        background: linear-gradient(135deg, var(--bg-secondary) 0%, rgba(0,242,255,0.05) 100%);
        border: 1px solid var(--primary-color);
        border-radius: 8px;
        padding: 20px;
        margin-bottom: 15px;
    }
    
    .parameter-value {
        font-size: 28px;
        font-weight: bold;
        color: var(--primary-color);
    }
    
    .status-indicator {
        display: inline-block;
        width: 12px;
        height: 12px;
        border-radius: 50%;
        margin-right: 8px;
    }
    
    .status-active {
        background-color: var(--success-color);
        animation: pulse 2s infinite;
    }
    
    .status-inactive {
        background-color: var(--text-secondary);
    }
    
    .status-warning {
        background-color: var(--warning-color);
        animation: blink 0.5s infinite;
    }
    
    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
    }
    
    @keyframes blink {
        0%, 50%, 100% { opacity: 1; }
        25%, 75% { opacity: 0.3; }
    }
    
    .chat-message {
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 10px;
        font-size: 14px;
    }
    
    .chat-agent {
        background-color: rgba(0, 242, 255, 0.1);
        border-left: 3px solid var(--primary-color);
        color: var(--text-primary);
    }
    
    .chat-safety {
        background-color: rgba(255, 107, 107, 0.1);
        border-left: 3px solid var(--warning-color);
        color: #ff9999;
    }
    
    .cot-section {
        background-color: var(--bg-secondary);
        border: 1px solid rgba(0, 242, 255, 0.3);
        border-radius: 8px;
        padding: 15px;
        font-size: 13px;
        line-height: 1.6;
        color: var(--text-primary);
    }
</style>
""", unsafe_allow_html=True)

# ======================== 初始化会话状态 ========================
if 'current_step' not in st.session_state:
    st.session_state.current_step = 0

if 'alert_triggered' not in st.session_state:
    st.session_state.alert_triggered = False

if 'alert_time' not in st.session_state:
    st.session_state.alert_time = None

# ======================== 数据生成函数 ========================
def generate_vitals_data(seed=None):
    """生成病人生理参数数据"""
    if seed is not None:
        np.random.seed(seed)
    
    timestamps = pd.date_range(end=datetime.now(), periods=60, freq='1min')
    
    # 基础值 + 随机波动
    spo2_base = 95
    hr_base = 75
    rr_base = 16
    
    spo2 = spo2_base + np.random.normal(0, 2, 60)
    heart_rate = hr_base + np.random.normal(0, 3, 60)
    resp_rate = rr_base + np.random.normal(0, 1, 60)
    
    # 确保数据在合理范围
    spo2 = np.clip(spo2, 85, 100)
    heart_rate = np.clip(heart_rate, 50, 120)
    resp_rate = np.clip(resp_rate, 10, 30)
    
    return {
        'timestamps': timestamps,
        'spo2': spo2,
        'heart_rate': heart_rate,
        'resp_rate': resp_rate
    }

def create_vitals_chart(vitals_data, metric_name, unit, color):
    """创建折线图"""
    option = {
        "backgroundColor": "transparent",
        "textStyle": {"color": "#e0e0e0"},
        "tooltip": {
            "trigger": "axis",
            "backgroundColor": "rgba(15, 20, 25, 0.9)",
            "borderColor": "#00f2ff",
            "textStyle": {"color": "#e0e0e0"}
        },
        "grid": {
            "left": "50px",
            "right": "20px",
            "top": "10px",
            "bottom": "30px",
            "containLabel": True
        },
        "xAxis": {
            "type": "time",
            "splitLine": {"show": False},
            "axisLine": {"lineStyle": {"color": "#404854"}},
            "axisLabel": {"color": "#9ca3af", "fontSize": 11}
        },
        "yAxis": {
            "type": "value",
            "splitLine": {"lineStyle": {"color": "#2a3142"}},
            "axisLine": {"show": False},
            "axisLabel": {"color": "#9ca3af", "fontSize": 11}
        },
        "series": [
            {
                "data": list(zip(
                    [t.timestamp() * 1000 for t in vitals_data['timestamps']],
                    vitals_data['spo2'] if metric_name == 'SpO2' else 
                    vitals_data['heart_rate'] if metric_name == 'Heart Rate' else 
                    vitals_data['resp_rate']
                )),
                "type": "line",
                "smooth": True,
                "lineStyle": {"color": color, "width": 2},
                "areaStyle": {"color": {"type": "linear", "x": 0, "y": 0, "x2": 0, "y2": 1,
                    "colorStops": [{"offset": 0, "color": color}, {"offset": 1, "color": "transparent"}]
                }},
                "symbolSize": 4,
                "itemStyle": {"color": color}
            }
        ]
    }
    return option

# ======================== 智能体枚举 ========================
class AgentStatus(Enum):
    ACTIVE = "🟢 运行中"
    IDLE = "⚪ 待机"
    WARNING = "🔴 警告"

# ======================== 主布局 ========================
st.title("🫁 呼吸机多智能体协作系统")
st.markdown("###")

# 顶部控制面板
col_control1, col_control2, col_control3 = st.columns([2, 1, 1])
with col_control1:
    st.markdown("**当前患者ID:** P-20240410-001")
with col_control2:
    st.markdown(f"**系统时间:** {datetime.now().strftime('%H:%M:%S')}")
with col_control3:
    next_hour_btn = st.button("⏭️ 下一时刻", key="next_hour")

st.divider()

# 主要内容区域分为三列
left_col, middle_col, right_col = st.columns([1.2, 1.5, 1.2])

# ======================== 左侧：病人生理状态窗 ========================
with left_col:
    st.subheader("👤 病人生理状态")
    
    # 生成数据
    vitals_data = generate_vitals_data(seed=st.session_state.current_step)
    latest_spo2 = vitals_data['spo2'][-1]
    latest_hr = vitals_data['heart_rate'][-1]
    latest_rr = vitals_data['resp_rate'][-1]
    
    # 实时指标卡片
    st.markdown("**实时数值**")
    metric_col1, metric_col2, metric_col3 = st.columns(3)
    with metric_col1:
        st.metric("SpO₂", f"{latest_spo2:.1f}%", f"+{np.random.uniform(-1, 1):.1f}%")
    with metric_col2:
        st.metric("HR", f"{latest_hr:.0f}", f"+{np.random.uniform(-2, 2):.0f}")
    with metric_col3:
        st.metric("RR", f"{latest_rr:.1f}", f"+{np.random.uniform(-0.5, 0.5):.1f}")
    
    # 折线图
    st.markdown("**SpO₂ 趋势**")
    spo2_option = create_vitals_chart(vitals_data, 'SpO2', '#00f2ff', vitals_data)
    st_echarts(spo2_option, height=200)
    
    st.markdown("**心率 趋势**")
    hr_option = create_vitals_chart(vitals_data, 'Heart Rate', '#00ff88', vitals_data)
    st_echarts(hr_option, height=200)
    
    st.markdown("**呼吸频率 趋势**")
    rr_option = create_vitals_chart(vitals_data, 'Resp Rate', '#ffb700', vitals_data)
    st_echarts(rr_option, height=200)

# ======================== 中间：智能体协作流 ========================
with middle_col:
    st.subheader("🤖 智能体协作流")
    
    # 感知智能体
    st.markdown('<div class="agent-container agent-active">', unsafe_allow_html=True)
    col_icon, col_status = st.columns([0.3, 3.7])
    with col_icon:
        st.markdown("👁️")
    with col_status:
        st.markdown("**感知智能体**")
        st.markdown('<span class="status-indicator status-active"></span>运行中', unsafe_allow_html=True)
    st.markdown("**当前感知：**")
    st.markdown("""
    - SpO₂: 95.2% ✓
    - 心率: 76 bpm ✓
    - 呼吸频率: 16 breaths/min ✓
    - PEEP: 8 cmH₂O
    - FiO₂: 45%
    """)
    st.markdown('</div>', unsafe_allow_html=True)
    
    # 决策智能体
    st.markdown('<div class="agent-container agent-active">', unsafe_allow_html=True)
    col_icon, col_status = st.columns([0.3, 3.7])
    with col_icon:
        st.markdown("⚙️")
    with col_status:
        st.markdown("**CQL决策智能体**")
        st.markdown('<span class="status-indicator status-active"></span>运行中', unsafe_allow_html=True)
    st.markdown("**建议参数调整：**")
    st.markdown("""
    <div class="chat-message chat-agent">
    💡 基于当前患者状态，建议：
    • 维持 FiO₂ = 45%
    • PEEP 保持 8 cmH₂O
    • Tidal Volume 调整至 420 mL
    
    预期效果：最优氧合与通气
    </div>
    """, unsafe_allow_html=True)
    
    # 安全智能体
    is_alert = st.session_state.alert_triggered
    agent_class = "agent-container agent-warning" if is_alert else "agent-container agent-active"
    st.markdown(f'<div class="{agent_class}">', unsafe_allow_html=True)
    col_icon, col_status = st.columns([0.3, 3.7])
    with col_icon:
        st.markdown("🛡️")
    with col_status:
        st.markdown("**安全智能体**")
        status_class = "status-warning" if is_alert else "status-active"
        st.markdown(f'<span class="status-indicator {status_class}"></span>{"警告!" if is_alert else "运行中"}', unsafe_allow_html=True)
    
    if is_alert:
        st.markdown("""
        <div class="chat-message chat-safety">
        ⚠️ 【安全检查】拦截不合理参数！
        
        违规原因：
        • Tidal Volume 超过安全阈值（>500 mL）
        • 存在肺损伤风险
        
        ✗ 参数方案已拒绝
        ↻ 要求CQL重新决策...
        </div>
        """, unsafe_allow_html=True)
    else:
        st.markdown("""
        <div class="chat-message chat-agent">
        ✓ 参数方案通过安全检查
        • Tidal Volume: 420 mL < 500 mL ✓
        • FiO₂ 不超过安全上限 ✓
        
        方案批准，可执行
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)

# ======================== 右侧：决策结果区 ========================
with right_col:
    st.subheader("📊 决策结果")
    
    # 参数显示
    st.markdown("**当前输出参数**")
    param_col1, param_col2 = st.columns(2)
    
    with param_col1:
        st.markdown('<div class="decision-card">', unsafe_allow_html=True)
        st.markdown("**PEEP**")
        st.markdown('<span class="parameter-value">8</span> cmH₂O', unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
        
        st.markdown('<div class="decision-card">', unsafe_allow_html=True)
        st.markdown("**FiO₂**")
        st.markdown('<span class="parameter-value">45</span> %', unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    with param_col2:
        st.markdown('<div class="decision-card">', unsafe_allow_html=True)
        st.markdown("**Tidal Volume**")
        st.markdown('<span class="parameter-value">420</span> mL', unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
        
        st.markdown('<div class="decision-card">', unsafe_allow_html=True)
        st.markdown("**决策置信度**")
        st.markdown('<span class="parameter-value">92</span> %', unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    # CoT思维链
    st.markdown("**决策思路（CoT）**")
    st.markdown("""
    <div class="cot-section">
    <strong>医学依据：</strong>
    
    1. <strong>患者状态评估</strong>
       • SpO₂ 正常 (95.2%)，说明当前氧合良好
       • 心率平稳，无脓毒症迹象
    
    2. <strong>参数调整逻辑</strong>
       • PEEP维持 8 cmH₂O → 维护肺泡招张
       • FiO₂保持 45% → 避免氧中毒
       • Tidal Volume 420 mL → ARDS防护标准（6-8 mL/kg）
    
    3. <strong>风险评估</strong>
       • 低通气伤(Volutrauma)风险: ✓
       • 肺损伤(VILI)概率: 2.1%
       • 方案安全性: 高置信度
    
    4. <strong>预期效果</strong>
       • 目标呼吸频率: 14-16 breaths/min
       • 预期4小时内SpO₂维持: >93%
       • 改善趋势: ↗
    </div>
    """, unsafe_allow_html=True)

# ======================== 交互逻辑 ========================
if next_hour_btn:
    st.session_state.current_step += 1
    
    # 30%概率触发安全警告
    if np.random.random() < 0.3:
        st.session_state.alert_triggered = True
        st.session_state.alert_time = datetime.now()
    else:
        st.session_state.alert_triggered = False
    
    st.rerun()

# 底部信息
st.divider()
st.markdown("""
<div style='text-align: center; color: #9ca3af; font-size: 12px;'>
📌 <strong>系统说明：</strong> 本系统基于LangGraph多智能体架构，集成PostgreSQL数据库进行实时患者监测和呼吸机参数优化。<br>
🔄 点击"下一时刻"按钮可模拟时序演进，系统会自动执行感知→决策→安全检查的完整流程。
</div>
""", unsafe_allow_html=True)
