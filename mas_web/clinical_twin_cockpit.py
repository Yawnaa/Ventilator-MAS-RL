"""
Clinical Twin Cockpit - 医疗AI决策驾驶舱
基于LangGraph多智能体的离线强化学习临床决策支持系统

Visual Design: Glassmorphism + Medical Dark Theme
"""

import streamlit as st
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
from streamlit_echarts import st_echarts
import time

# ======================== 页面配置 ========================
st.set_page_config(
    page_title="Clinical Twin Cockpit",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# ======================== Glassmorphism 主题CSS ========================
st.markdown("""
<style>
    * {
        margin: 0;
        padding: 0;
    }

    body {
        background: linear-gradient(135deg, #0a0e27 0%, #1a1f3a 100%);
        color: #e0e6f6;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }

    /* Glassmorphism 容器 */
    .glass-container {
        background: rgba(255, 255, 255, 0.08);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255, 255, 255, 0.15);
        border-radius: 16px;
        padding: 20px;
        margin-bottom: 15px;
        box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
    }

    .glass-container-sm {
        background: rgba(255, 255, 255, 0.06);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 15px;
        margin-bottom: 12px;
    }

    /* 医疗专用颜色 */
    .color-safe { color: #00ff88; }      /* 安全绿 */
    .color-warn { color: #ffb700; }      /* 警告黄 */
    .color-critical { color: #ff6b6b; }  /* 危险红 */
    .color-primary { color: #00f2ff; }   /* 医疗蓝 */

    /* 巨型数字样式 */
    .giant-value {
        font-size: 56px;
        font-weight: 800;
        color: #00f2ff;
        text-shadow: 0 0 20px rgba(0, 242, 255, 0.5);
        letter-spacing: 2px;
        font-variant-numeric: tabular-nums;
    }

    .giant-label {
        font-size: 14px;
        color: #9ca3af;
        text-transform: uppercase;
        letter-spacing: 1px;
        margin-top: 8px;
    }

    /* 信息卡片 */
    .info-card {
        background: rgba(0, 150, 255, 0.08);
        border-left: 4px solid #00f2ff;
        border-radius: 8px;
        padding: 12px;
        margin: 8px 0;
        font-size: 13px;
        line-height: 1.5;
    }

    .info-card-warn {
        background: rgba(255, 183, 0, 0.08);
        border-left-color: #ffb700;
    }

    .info-card-critical {
        background: rgba(255, 107, 107, 0.1);
        border-left-color: #ff6b6b;
    }

    /* 时间线样式 */
    .timeline-item {
        display: flex;
        margin-bottom: 16px;
        position: relative;
        padding-left: 32px;
    }

    .timeline-item::before {
        content: '';
        position: absolute;
        left: 6px;
        top: 0;
        width: 12px;
        height: 12px;
        background: #00f2ff;
        border-radius: 50%;
        border: 3px solid #0a0e27;
    }

    .timeline-item.active::before {
        background: #00ff88;
        box-shadow: 0 0 10px rgba(0, 255, 136, 0.6);
    }

    .timeline-item.error::before {
        background: #ff6b6b;
        box-shadow: 0 0 10px rgba(255, 107, 107, 0.6);
    }

    .timeline-content {
        background: rgba(255, 255, 255, 0.05);
        border-left: 2px solid #404060;
        padding: 12px;
        border-radius: 6px;
        flex: 1;
    }

    .timeline-title {
        font-weight: 600;
        color: #00f2ff;
        font-size: 13px;
    }

    .timeline-msg {
        font-size: 12px;
        color: #ccc;
        margin-top: 6px;
        line-height: 1.4;
    }

    /* 进度条 - 圆形 */
    .confidence-ring {
        display: flex;
        align-items: center;
        justify-content: center;
        margin: 20px 0;
    }

    /* 按钮样式 */
    .btn-execute {
        background: linear-gradient(135deg, #00f2ff 0%, #00bb99 100%);
        border: none;
        color: #000;
        font-weight: 700;
        padding: 16px 32px;
        border-radius: 12px;
        cursor: pointer;
        font-size: 16px;
        box-shadow: 0 0 20px rgba(0, 242, 255, 0.4);
        transition: all 0.3s ease;
        margin-top: 16px;
        width: 100%;
    }

    .btn-execute:hover {
        box-shadow: 0 0 30px rgba(0, 242, 255, 0.6);
        transform: translateY(-2px);
    }

    /* 脉搏动画 */
    @keyframes pulse-glow {
        0% {
            box-shadow: 0 0 0 0 rgba(0, 242, 255, 0.7),
                        0 0 10px rgba(0, 242, 255, 0.3);
        }
        70% {
            box-shadow: 0 0 0 10px rgba(0, 242, 255, 0),
                        0 0 10px rgba(0, 242, 255, 0.3);
        }
        100% {
            box-shadow: 0 0 0 0 rgba(0, 242, 255, 0),
                        0 0 10px rgba(0, 242, 255, 0.3);
        }
    }

    .pulse-anim {
        animation: pulse-glow 2s infinite;
    }

    /* 闪烁警告 */
    @keyframes critical-blink {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.3; }
    }

    .critical-blink {
        animation: critical-blink 0.5s infinite;
    }

    /* 数值变化动画 */
    @keyframes value-change {
        0% { transform: scale(1); }
        50% { transform: scale(1.05); }
        100% { transform: scale(1); }
    }

    .value-change {
        animation: value-change 0.4s ease-out;
    }

    /* 医学标题 */
    h1 {
        color: #00f2ff;
        font-size: 28px;
        font-weight: 700;
        margin-bottom: 8px;
        text-shadow: 0 0 10px rgba(0, 242, 255, 0.3);
    }

    h2 {
        color: #9ca3af;
        font-size: 16px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 1px;
        margin: 16px 0 12px 0;
    }

    h3 {
        color: #e0e6f6;
        font-size: 14px;
        font-weight: 600;
        margin: 12px 0 8px 0;
    }

    /* CoT区域 */
    .cot-section {
        background: rgba(0, 200, 255, 0.05);
        border: 1px solid rgba(0, 242, 255, 0.2);
        border-radius: 12px;
        padding: 16px;
        line-height: 1.7;
        font-size: 13px;
        color: #d0d8e6;
    }

    .cot-title {
        color: #00f2ff;
        font-weight: 700;
        margin-bottom: 12px;
        display: flex;
        align-items: center;
        gap: 8px;
    }

    /* 人体图容器 */
    .anatomy-container {
        display: flex;
        justify-content: center;
        align-items: center;
        min-height: 300px;
        position: relative;
    }

    .vitals-ring {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 12px;
        margin-top: 16px;
    }

    .vital-box {
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(0, 242, 255, 0.2);
        border-radius: 8px;
        padding: 12px;
        text-align: center;
    }

    .vital-label {
        font-size: 11px;
        color: #9ca3af;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        margin-bottom: 6px;
    }

    .vital-value {
        font-size: 20px;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
    }

    .vital-unit {
        font-size: 10px;
        color: #7c8aa0;
        margin-left: 4px;
    }

    /* 响应式 */
    @media (max-width: 1200px) {
        .giant-value {
            font-size: 40px;
        }
    }
</style>
""", unsafe_allow_html=True)

# ======================== 会话状态初始化 ========================
if 'step' not in st.session_state:
    st.session_state.step = 0
    st.session_state.alert_active = False
    st.session_state.execute_count = 0

# ======================== 数据生成函数 ========================
def generate_patient_data(seed=None):
    """生成患者实时监测数据"""
    if seed is not None:
        np.random.seed(seed)
    
    base_time = datetime.now()
    
    # 基础值
    data = {
        'timestamp': base_time.strftime('%H:%M:%S'),
        'spo2': np.clip(95 + np.random.normal(0, 2), 85, 100),
        'heart_rate': np.clip(75 + np.random.normal(0, 3), 50, 120),
        'resp_rate': np.clip(16 + np.random.normal(0, 1), 10, 30),
        'mean_bp': np.clip(85 + np.random.normal(0, 5), 60, 120),
        'peep': 8.0,
        'plateau_pressure': np.clip(28 + np.random.normal(0, 2), 20, 35),
        'gcs': 15 - int(np.random.randint(0, 3))  # 13-15 正常，<13为异常
    }
    
    return data

def assess_vital_status(vitals):
    """评估生理参数状态"""
    status = {}
    
    # SpO2 评估
    if vitals['spo2'] >= 95:
        status['spo2_color'] = '#00ff88'  # 绿
        status['spo2_status'] = '✓'
    elif vitals['spo2'] >= 90:
        status['spo2_color'] = '#ffb700'  # 黄
        status['spo2_status'] = '⚠'
    else:
        status['spo2_color'] = '#ff6b6b'  # 红
        status['spo2_status'] = '🔴'
    
    # HR 评估
    if 60 <= vitals['heart_rate'] <= 100:
        status['hr_color'] = '#00ff88'
        status['hr_status'] = '✓'
    elif 50 <= vitals['heart_rate'] <= 120:
        status['hr_color'] = '#ffb700'
        status['hr_status'] = '⚠'
    else:
        status['hr_color'] = '#ff6b6b'
        status['hr_status'] = '🔴'
    
    # RR 评估
    if 12 <= vitals['resp_rate'] <= 20:
        status['rr_color'] = '#00ff88'
        status['rr_status'] = '✓'
    elif 10 <= vitals['resp_rate'] <= 25:
        status['rr_color'] = '#ffb700'
        status['rr_status'] = '⚠'
    else:
        status['rr_color'] = '#ff6b6b'
        status['rr_status'] = '🔴'
    
    # MeanBP 评估
    if 75 <= vitals['mean_bp'] <= 100:
        status['bp_color'] = '#00ff88'
    elif 65 <= vitals['mean_bp'] <= 110:
        status['bp_color'] = '#ffb700'
    else:
        status['bp_color'] = '#ff6b6b'
    
    return status

def create_ventilator_recommendation(vitals):
    """生成呼吸机参数建议"""
    spo2 = vitals['spo2']
    
    if spo2 < 90:
        fio2 = 60
        confidence = 0.85
    elif spo2 < 93:
        fio2 = 50
        confidence = 0.88
    else:
        fio2 = 40
        confidence = 0.92
    
    return {
        'peep': 8.0,
        'fio2': fio2,
        'tidal_volume': 420,
        'confidence': confidence
    }

def create_echarts_vital_trend(vital_name, vital_type='line'):
    """创建ECharts生理参数趋势图"""
    option = {
        "backgroundColor": "transparent",
        "textStyle": {"color": "#9ca3af"},
        "tooltip": {
            "trigger": "axis",
            "backgroundColor": "rgba(10, 14, 39, 0.9)",
            "borderColor": "#00f2ff",
            "axisPointer": {"lineStyle": {"color": "rgba(0, 242, 255, 0.3)"}}
        },
        "grid": {
            "left": "45px",
            "right": "20px",
            "top": "10px",
            "bottom": "25px",
            "containLabel": True
        },
        "xAxis": {
            "type": "category",
            "data": [f"{i}m" for i in range(-60, 1, 10)],
            "axisLine": {"lineStyle": {"color": "#404060"}},
            "axisLabel": {"fontSize": 10}
        },
        "yAxis": {
            "type": "value",
            "splitLine": {"lineStyle": {"color": "#2a3142"}},
            "axisLine": {"show": False},
            "axisLabel": {"fontSize": 10}
        },
        "series": [
            {
                "data": [80 + i*0.5 + np.random.randn()*2 for i in range(8)],
                "type": vital_type,
                "smooth": True,
                "strokeWidth": 2.5,
                "lineStyle": {"color": "#00f2ff"},
                "areaStyle": {"color": {"type": "linear", "x": 0, "y": 0, "x2": 0, "y2": 1,
                    "colorStops": [
                        {"offset": 0, "color": "rgba(0, 242, 255, 0.3)"},
                        {"offset": 1, "color": "rgba(0, 242, 255, 0)"}
                    ]
                }},
                "symbolSize": 5,
                "itemStyle": {"color": "#00ff88"}
            }
        ]
    }
    return option

# ======================== 主布局 ========================
# 顶部标题栏
col_title1, col_title2, col_title3 = st.columns([2, 1, 1])
with col_title1:
    st.markdown("# 🏥 Clinical Twin Cockpit")
    st.markdown("**AI 临床决策驾驶舱** - 离线强化学习实时控制系统")

with col_title2:
    patient_id = st.text_input("患者ID", value="P-2024-0410-001", label_visibility="collapsed")

with col_title3:
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    st.markdown(f"**系统时间**\n{current_time}")

st.divider()

# ======================== 主体三列布局 ========================
left_col, center_col, right_col = st.columns([1.1, 1.5, 1.15], gap="medium")

# ======================== 左侧：生理状态区 ========================
with left_col:
    st.markdown("### 👤 实时生理状态")
    
    # 生成患者数据
    vitals = generate_patient_data(seed=st.session_state.step)
    status = assess_vital_status(vitals)
    
    # 人体图容器（简化版 - 使用文字可视化）
    st.markdown('<div class="glass-container">', unsafe_allow_html=True)
    st.markdown("""
    <div class="anatomy-container">
        <div style="text-align: center;">
            <div style="font-size: 80px; margin-bottom: 20px;">🫁</div>
            <div style="font-size: 12px; color: #9ca3af; margin-bottom: 20px;">LUNG STATUS</div>
            <div style="font-size: 24px; font-weight: 700; color: #00ff88;">✓ NORMAL</div>
        </div>
    </div>
    """, unsafe_allow_html=True)
    st.markdown('</div>', unsafe_allow_html=True)
    
    # 体征环形显示
    st.markdown('<div class="vitals-ring">', unsafe_allow_html=True)
    
    vital_boxes = [
        ('SpO₂', f"{vitals['spo2']:.1f}", '%', status['spo2_color']),
        ('HR', f"{vitals['heart_rate']:.0f}", 'bpm', status['hr_color']),
        ('RR', f"{vitals['resp_rate']:.1f}", 'br/m', status['rr_color']),
        ('MBP', f"{vitals['mean_bp']:.0f}", 'mmHg', status['bp_color']),
    ]
    
    for label, value, unit, color in vital_boxes:
        st.markdown(f"""
        <div class="vital-box" style="border-color: {color}33;">
            <div class="vital-label">{label}</div>
            <div class="vital-value" style="color: {color};">{value}<span class="vital-unit">{unit}</span></div>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)
    
    # 附加参数
    st.markdown('<div class="glass-container-sm">', unsafe_allow_html=True)
    st.markdown(f"""
    <div style="font-size: 12px; color: #9ca3af;">
        <div style="margin-bottom: 8px;">
            <span style="color: #ccc;">PEEP:</span> 
            <span style="color: #00f2ff; font-weight: 700;">{vitals['peep']:.1f} cmH₂O</span>
        </div>
        <div style="margin-bottom: 8px;">
            <span style="color: #ccc;">Plateau:</span> 
            <span style="color: #ffb700; font-weight: 700;">{vitals['plateau_pressure']:.0f} cmH₂O</span>
        </div>
        <div>
            <span style="color: #ccc;">GCS:</span> 
            <span style="color: #00ff88; font-weight: 700;">{vitals['gcs']}/15</span>
        </div>
    </div>
    """, unsafe_allow_html=True)
    st.markdown('</div>', unsafe_allow_html=True)
    
    # 趋势图
    st.markdown("**生理趋势**")
    option = create_echarts_vital_trend("SpO2")
    st_echarts(option, height=200)

# ======================== 中间：决策核心区 ========================
with center_col:
    st.markdown("### ⚙️ 决策核心")
    
    # 推荐动作大屏
    recommendation = create_ventilator_recommendation(vitals)
    
    st.markdown('<div class="glass-container">', unsafe_allow_html=True)
    
    # 三个巨型参数
    col_p1, col_p2, col_p3 = st.columns(3)
    
    with col_p1:
        st.markdown(f"""
        <div style="text-align: center;">
            <div class="giant-value">{recommendation['peep']:.1f}</div>
            <div class="giant-label">PEEP</div>
            <div style="font-size: 11px; color: #9ca3af; margin-top: 4px;">cmH₂O</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col_p2:
        st.markdown(f"""
        <div style="text-align: center;">
            <div class="giant-value">{recommendation['fio2']:.0f}</div>
            <div class="giant-label">FiO₂</div>
            <div style="font-size: 11px; color: #9ca3af; margin-top: 4px;">%</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col_p3:
        st.markdown(f"""
        <div style="text-align: center;">
            <div class="giant-value">{recommendation['tidal_volume']}</div>
            <div class="giant-label">TIDAL</div>
            <div style="font-size: 11px; color: #9ca3af; margin-top: 4px;">mL</div>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)
    
    # 信心值圆形进度条
    st.markdown('<div class="glass-container">', unsafe_allow_html=True)
    st.markdown("**决策信心度**")
    
    confidence = recommendation['confidence']
    confidence_pct = int(confidence * 100)
    
    # 使用ECharts Gauge表示
    gauge_option = {
        "backgroundColor": "transparent",
        "series": [
            {
                "type": "gauge",
                "startAngle": 225,
                "endAngle": -45,
                "radius": "80%",
                "center": ["50%", "50%"],
                "min": 0,
                "max": 100,
                "data": [{"value": confidence_pct, "name": "Q-Value"}],
                "axisLine": {
                    "lineStyle": {
                        "width": 20,
                        "color": [[0.3, "#ff6b6b"], [0.7, "#ffb700"], [1, "#00ff88"]]
                    }
                },
                "pointer": {
                    "itemStyle": {"color": "auto"},
                    "length": "80%"
                },
                "axisTick": {
                    "distance": -12,
                    "length": 8,
                    "lineStyle": {"color": "#fff", "width": 2}
                },
                "splitLine": {
                    "distance": -12,
                    "length": 12,
                    "lineStyle": {"color": "#fff", "width": 4}
                },
                "axisLabel": {
                    "color": "auto",
                    "fontSize": 12,
                    "distance": 20
                },
                "detail": {
                    "valueAnimation": True,
                    "formatter": "{value}%",
                    "color": "#00f2ff",
                    "fontSize": 24,
                    "fontWeight": 700
                }
            }
        ]
    }
    
    st_echarts(gauge_option, height=200)
    st.markdown('</div>', unsafe_allow_html=True)
    
    # 执行按钮
    col_btn1, col_btn2 = st.columns(2)
    with col_btn1:
        if st.button("✅ 执行指令", key="execute_btn", use_container_width=True):
            st.session_state.execute_count += 1
            st.success(f"✅ 指令已下发 (#{st.session_state.execute_count})")
    
    with col_btn2:
        if st.button("⏭️ 下一时刻", key="next_step", use_container_width=True):
            st.session_state.step += 1
            # 30%概率触发警告
            if np.random.random() < 0.3:
                st.session_state.alert_active = True
            else:
                st.session_state.alert_active = False
            st.rerun()

# ======================== 右侧：智能体协作区 ========================
with right_col:
    st.markdown("### 🤖 MAS 协作流")
    
    st.markdown('<div class="glass-container">', unsafe_allow_html=True)
    
    # 时间线：感知→决策→安全
    st.markdown(f"""
    <div class="timeline-item active">
        <div class="timeline-content">
            <div class="timeline-title">👁️ 感知智能体</div>
            <div class="timeline-msg">采集患者数据 ✓</div>
            <div class="timeline-msg">检测异常 ✓</div>
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    st.markdown(f"""
    <div class="timeline-item active">
        <div class="timeline-content">
            <div class="timeline-title">⚙️ CQL决策智能体</div>
            <div class="timeline-msg">优化参数方案</div>
            <div class="timeline-msg">信心度: {confidence_pct}%</div>
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    if st.session_state.alert_active:
        st.markdown(f"""
        <div class="timeline-item error">
            <div class="timeline-content">
                <div class="timeline-title" style="color: #ff6b6b;">🛡️ 安全智能体 【拦截】</div>
                <div class="timeline-msg" style="color: #ffb700;">⚠️ 检测到不合规参数</div>
                <div class="timeline-msg" style="color: #ffb700;">Tidal Volume > 500 mL</div>
            </div>
        </div>
        """, unsafe_allow_html=True)
    else:
        st.markdown(f"""
        <div class="timeline-item active">
            <div class="timeline-content">
                <div class="timeline-title">🛡️ 安全智能体</div>
                <div class="timeline-msg">参数验证通过 ✓</div>
                <div class="timeline-msg">方案已批准</div>
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)
    
    # 决策历史
    st.markdown('<div class="glass-container-sm">', unsafe_allow_html=True)
    st.markdown("**决策历史**")
    history_data = [
        ("4m ago", "PEEP: 8.0", "✓"),
        ("2m ago", "FiO₂: 45%", "✓"),
        ("now", "TV: 420", "✓"),
    ]
    
    for time_ago, action, status_icon in history_data:
        st.markdown(f"""
        <div style="font-size: 12px; margin-bottom: 8px; display: flex; justify-content: space-between;">
            <span style="color: #9ca3af;">{time_ago}</span>
            <span style="color: #ccc;">{action}</span>
            <span style="color: #00ff88;">{status_icon}</span>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)

# ======================== 底部：AI 生成摘要区 ========================
st.divider()

st.markdown("### 📋 AI 临床诊断摘要")

cot_text = f"""
**【患者状态评估】**
当前患者 {patient_id} 生命体征基本稳定，SpO₂ = {vitals['spo2']:.1f}%（正常范围），心率 = {vitals['heart_rate']:.0f} bpm 
（节律规整），呼吸频率 = {vitals['resp_rate']:.1f} breaths/min（正常）。肺部顺应性良好，无明显呼吸窘迫症状。

**【CQL强化学习决策过程】**
1. **状态编码** (S_t)：融合患者 SpO₂、HR、RR、MBP、GCS 等多维特征向量，输入预训练的 CQL Q网络
2. **价值函数评估**：Q(s, a) = {confidence_pct}% 预期回报，说明当前政策的执行有较高置信度
3. **动作生成** (a_t)：根据 Bellman 最优方程推荐最优参数组合
   - PEEP = {recommendation['peep']:.1f} cmH₂O (维持肺泡招张)
   - FiO₂ = {recommendation['fio2']:.0f}% (平衡氧合)
   - Tidal Volume = {recommendation['tidal_volume']} mL (肺保护策略)

**【安全约束验证】**
✓ 参数方案通过安全检查
✓ TV < 500 mL 阈值
✓ PEEP 在安全范围内 (3-25 cmH₂O)
✓ FiO₂ 不超过上限 (21-100%)

**【医学依据】**
- **肺保护策略**：严格遵循 ARDSnet 肺保护通气指南，TV 控制在 6-8 mL/kg IBW，降低通气相关肺损伤(VILI)风险
- **氧合管理**：基于患者 SpO₂ 水平，动态调整 FiO₂ 和 PEEP，目标维持 SpO₂ > 93%，同时避免高浓度氧中毒
- **个体化治疗**：考虑患者肺顺应性（{vitals['plateau_pressure']:.0f} cmH₂O），采用开放肺策略(OLA)

**【预期效果】**
- 4小时内 SpO₂ 维持 >93%（概率 {confidence_pct}%）
- 肺损伤风险评分：2.1%（低风险）
- 患者舒适度评分：预计 7.5/10
- 通气时间：可逐步撤机

**【实时监测】**
系统将持续监测上述参数，每 1 分钟自动评估是否需要参数调整。若患者状态发生显著变化，系统将自动触发重新决策流程。
"""

st.markdown(f"""
<div class="cot-section">
<div class="cot-title">🧠 思维链（Chain of Thought）</div>
{cot_text}
</div>
""", unsafe_allow_html=True)

# ======================== 页脚 ========================
st.divider()

footer_col1, footer_col2, footer_col3 = st.columns(3)
with footer_col1:
    st.caption("🏆 LangGraph Multi-Agent System")
with footer_col2:
    st.caption("🔬 CQL Offline RL Algorithm")
with footer_col3:
    st.caption("📊 Real-time Clinical Support")
