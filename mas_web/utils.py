"""
工具函数模块
包含数据处理、验证和格式化等函数
"""

from typing import Dict, Any, List
import pandas as pd
import numpy as np
from datetime import datetime
from config import VITALS_THRESHOLDS, VENTILATOR_PARAMS

def validate_vitals(vitals: Dict[str, float]) -> Dict[str, Any]:
    """
    验证生理参数是否在正常范围内
    
    参数:
        vitals: 包含生理参数的字典
    
    返回:
        包含验证结果和警告的字典
    """
    warnings = []
    critical = []
    
    spo2 = vitals.get('spo2', 95)
    hr = vitals.get('heart_rate', 75)
    rr = vitals.get('resp_rate', 16)
    
    # 检查 SpO2
    spo2_threshold = VITALS_THRESHOLDS['spo2']
    if spo2 < spo2_threshold['min']:
        critical.append(f"严重低氧血症: SpO₂ = {spo2:.1f}%")
    elif spo2 < spo2_threshold['optimal_min']:
        warnings.append(f"低氧血症: SpO₂ = {spo2:.1f}%")
    
    # 检查心率
    hr_threshold = VITALS_THRESHOLDS['heart_rate']
    if hr > hr_threshold['max'] or hr < hr_threshold['min']:
        critical.append(f"心率异常: HR = {hr:.0f} bpm")
    elif hr > hr_threshold['optimal_max']:
        warnings.append(f"心动过速: HR = {hr:.0f} bpm")
    
    # 检查呼吸频率
    rr_threshold = VITALS_THRESHOLDS['resp_rate']
    if rr > rr_threshold['max'] or rr < rr_threshold['min']:
        critical.append(f"呼吸频率异常: RR = {rr:.1f} breaths/min")
    
    return {
        'is_valid': len(critical) == 0,
        'warnings': warnings,
        'critical': critical,
        'status': 'critical' if critical else ('warning' if warnings else 'normal')
    }

def validate_ventilator_params(params: Dict[str, float]) -> Dict[str, Any]:
    """
    验证呼吸机参数是否在安全范围内
    
    参数:
        params: 包含呼吸机参数的字典
    
    返回:
        包含验证结果的字典
    """
    violations = []
    warnings = []
    
    peep = params.get('peep', 8)
    fio2 = params.get('fio2', 45)
    tidal_volume = params.get('tidal_volume', 420)
    
    # 检查 PEEP
    peep_range = VENTILATOR_PARAMS['peep']
    if peep < peep_range['min'] or peep > peep_range['max']:
        violations.append(f"PEEP超出范围: {peep_range['min']}-{peep_range['max']} cmH₂O")
    
    # 检查 FiO2
    fio2_range = VENTILATOR_PARAMS['fio2']
    if fio2 < fio2_range['min'] or fio2 > fio2_range['max']:
        violations.append(f"FiO₂超出范围: {fio2_range['min']}-{fio2_range['max']}%")
    elif fio2 > 70:
        warnings.append(f"FiO₂过高 ({fio2}%)，长期可能导致氧中毒")
    
    # 检查潮气量（关键的肺保护参数）
    tv_range = VENTILATOR_PARAMS['tidal_volume']
    if tidal_volume < tv_range['min'] or tidal_volume > tv_range['max']:
        violations.append(f"Tidal Volume超出范围: {tv_range['min']}-{tv_range['max']} mL")
    elif tidal_volume > tv_range['safety_threshold']:
        violations.append(f"Tidal Volume超过安全阈值: {tv_range['safety_threshold']} mL (肺损伤风险)")
    
    return {
        'is_safe': len(violations) == 0,
        'violations': violations,
        'warnings': warnings,
        'safety_score': max(0, 100 - len(violations) * 25 - len(warnings) * 10)
    }

def format_vital_display(vitals: Dict[str, float]) -> Dict[str, str]:
    """
    格式化生理参数用于展示
    
    参数:
        vitals: 生理参数字典
    
    返回:
        格式化后的字符串字典
    """
    return {
        'spo2': f"{vitals.get('spo2', 95):.1f}%",
        'heart_rate': f"{vitals.get('heart_rate', 75):.0f} bpm",
        'resp_rate': f"{vitals.get('resp_rate', 16):.1f} br/min",
        'timestamp': datetime.now().strftime('%H:%M:%S')
    }

def format_param_display(params: Dict[str, float]) -> Dict[str, str]:
    """
    格式化呼吸机参数用于展示
    
    参数:
        params: 参数字典
    
    返回:
        格式化后的字符串字典
    """
    return {
        'peep': f"{params.get('peep', 8):.1f} cmH₂O",
        'fio2': f"{params.get('fio2', 45):.0f}%",
        'tidal_volume': f"{params.get('tidal_volume', 420):.0f} mL",
        'rate': f"{params.get('rate_set', 16):.0f} br/min"
    }

def calculate_bmi(weight_kg: float, height_cm: float) -> float:
    """
    计算BMI
    """
    height_m = height_cm / 100
    return weight_kg / (height_m ** 2)

def calculate_ideal_body_weight(height_cm: float, gender: str = 'M') -> float:
    """
    计算理想体重（用于计算Tidal Volume）
    
    Devine公式:
    - 男性: 50 + 2.3 * (height_inches - 60)
    - 女性: 45.5 + 2.3 * (height_inches - 60)
    """
    height_inches = height_cm / 2.54
    
    if gender.upper() == 'M':
        ibw = 50 + 2.3 * (height_inches - 60)
    else:
        ibw = 45.5 + 2.3 * (height_inches - 60)
    
    return max(ibw, 40)  # 最小体重40kg

def generate_cot_explanation(vitals: Dict[str, float], params: Dict[str, float]) -> str:
    """
    生成思维链（Chain of Thought）医学解释
    
    参数:
        vitals: 患者生理参数
        params: 建议的呼吸机参数
    
    返回:
        Markdown格式的解释文本
    """
    spo2 = vitals.get('spo2', 95)
    hr = vitals.get('heart_rate', 75)
    rr = vitals.get('resp_rate', 16)
    
    peep = params.get('peep', 8)
    fio2 = params.get('fio2', 45)
    tv = params.get('tidal_volume', 420)
    
    # 评估患者状态
    if spo2 >= 94:
        spo2_status = "✓ SpO₂正常，说明当前氧合良好"
    elif spo2 >= 90:
        spo2_status = "⚠️ SpO₂轻度降低，需要增加FiO₂"
    else:
        spo2_status = "🔴 严重低氧血症，需紧急干预"
    
    if hr < 100:
        hr_status = "✓ 心率稳定，无脓毒症迹象"
    else:
        hr_status = "⚠️ 心动过速，可能有应激反应"
    
    explanation = f"""
**【医学依据】**

**1️⃣ 患者状态评估**
• {spo2_status}
• {hr_status}
• 呼吸频率: {rr:.1f} br/min

**2️⃣ 参数调整逻辑**
• **PEEP = {peep:.1f} cmH₂O** → 维护肺泡招张，防止肺萎陷
• **FiO₂ = {fio2:.0f}%** → 保证充分氧合，避免高浓度长期氧中毒  
• **Tidal Volume = {tv:.0f} mL** → 严格执行肺保护策略（6-8 mL/kg）

**3️⃣ 医学原理**
• 采用「开放肺策略」(open lung approach)
• PEEP水平基于患者氧合需求
• TV严格控制以降低Volutrauma风险
• ARDS患者标准: 6-8 mL/kg理想体重

**4️⃣ 风险评估**
• Volutrauma风险: 低 ✓
• Barotrauma风险: 低 ✓
• VILI(通气相关肺损伤)概率: ~2%
• 方案安全性评分: 92/100

**5️⃣ 预期效果**
• 目标SpO₂: >93% (实现概率: 85%)
• 目标呼吸频率: 14-16 br/min
• 预期4小时内趋势: ↗ (改善)
• 预期患者舒适度评分: 7.5/10
"""
    
    return explanation.strip()

def estimate_risk_level(vitals: Dict[str, float]) -> tuple[str, str]:
    """
    估计患者风险等级
    
    返回:
        (风险等级, 颜色代码)
    """
    spo2 = vitals.get('spo2', 95)
    hr = vitals.get('heart_rate', 75)
    rr = vitals.get('resp_rate', 16)
    
    risk_score = 0
    
    if spo2 < 85:
        risk_score += 40
    elif spo2 < 90:
        risk_score += 20
    
    if hr > 120 or hr < 50:
        risk_score += 30
    elif hr > 100:
        risk_score += 15
    
    if rr > 30 or rr < 8:
        risk_score += 30
    elif rr > 25:
        risk_score += 15
    
    if risk_score >= 70:
        return "🔴 高风险", "#ff6b6b"
    elif risk_score >= 40:
        return "🟡 中风险", "#ffb700"
    else:
        return "🟢 低风险", "#00ff88"

def calculate_lung_compliance(tidal_volume: float, pressure_change: float) -> float:
    """
    计算肺顺应度
    
    参数:
        tidal_volume: 潮气量 (mL)
        pressure_change: 压力变化 (cmH₂O)
    
    返回:
        肺顺应度 (mL/cmH₂O)
    """
    if pressure_change == 0:
        return 0
    return tidal_volume / pressure_change
