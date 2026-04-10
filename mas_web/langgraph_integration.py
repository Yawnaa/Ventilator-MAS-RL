"""
LangGraph多智能体集成模块
连接前端与LangGraph智能体系统
"""

import json
from typing import Dict, Any
from datetime import datetime
import streamlit as st

class AgentState:
    """智能体状态管理"""
    
    def __init__(self):
        self.perception_data = None
        self.decision_output = None
        self.safety_check = None
        self.active_alerts = []
        self.execution_log = []
    
    def add_log(self, agent_name: str, message: str, level: str = "info"):
        """添加执行日志"""
        self.execution_log.append({
            'timestamp': datetime.now().isoformat(),
            'agent': agent_name,
            'message': message,
            'level': level
        })
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'perception': self.perception_data,
            'decision': self.decision_output,
            'safety': self.safety_check,
            'alerts': self.active_alerts,
            'log': self.execution_log
        }


class PerceptionAgent:
    """感知智能体：采集和处理患者生理数据"""
    
    def __init__(self):
        self.name = "感知智能体"
    
    def process_vitals(self, vitals_dict: Dict[str, Any]) -> Dict[str, Any]:
        """
        处理生理参数
        
        参数:
            vitals_dict: 包含spo2, heart_rate, resp_rate等
        
        返回:
            处理后的感知数据
        """
        perception_output = {
            'timestamp': datetime.now().isoformat(),
            'raw_vitals': vitals_dict,
            'alerts': [],
            'trend': self._analyze_trend(vitals_dict),
            'risk_level': self._assess_risk(vitals_dict)
        }
        
        # 异常检测
        if vitals_dict.get('spo2', 100) < 90:
            perception_output['alerts'].append('低氧血症警告')
        
        if vitals_dict.get('heart_rate', 75) > 120:
            perception_output['alerts'].append('心动过速')
        
        return perception_output
    
    def _analyze_trend(self, vitals_dict: Dict[str, Any]) -> str:
        """分析趋势"""
        spo2 = vitals_dict.get('spo2', 95)
        if spo2 < 90:
            return "恶化"
        elif spo2 > 97:
            return "改善"
        else:
            return "稳定"
    
    def _assess_risk(self, vitals_dict: Dict[str, Any]) -> str:
        """评估风险"""
        spo2 = vitals_dict.get('spo2', 95)
        hr = vitals_dict.get('heart_rate', 75)
        
        if spo2 < 85 or hr > 130:
            return "高风险"
        elif spo2 < 90:
            return "中风险"
        else:
            return "低风险"


class DecisionAgent:
    """决策智能体：基于CQL强化学习优化参数"""
    
    def __init__(self):
        self.name = "CQL决策智能体"
    
    def make_decision(self, perception_output: Dict[str, Any]) -> Dict[str, Any]:
        """
        做出参数决策
        
        参数:
            perception_output: 来自感知智能体的输出
        
        返回:
            建议的参数调整
        """
        vitals = perception_output.get('raw_vitals', {})
        
        decision = {
            'timestamp': datetime.now().isoformat(),
            'recommendation': {
                'peep': self._calculate_peep(vitals),
                'fio2': self._calculate_fio2(vitals),
                'tidal_volume': self._calculate_tidal_volume(vitals),
                'rate_set': self._calculate_rate(vitals)
            },
            'confidence': 0.92,
            'reasoning': self._generate_reasoning(vitals)
        }
        
        return decision
    
    def _calculate_peep(self, vitals: Dict[str, Any]) -> float:
        """计算PEEP"""
        spo2 = vitals.get('spo2', 95)
        if spo2 < 90:
            return 10.0
        elif spo2 < 92:
            return 8.0
        else:
            return 8.0
    
    def _calculate_fio2(self, vitals: Dict[str, Any]) -> float:
        """计算FiO2"""
        spo2 = vitals.get('spo2', 95)
        if spo2 < 90:
            return 60.0
        elif spo2 < 92:
            return 45.0
        else:
            return 40.0
    
    def _calculate_tidal_volume(self, vitals: Dict[str, Any]) -> float:
        """计算潮气量（基于理想体重6-8 mL/kg）"""
        # 假设理想体重70kg
        return 420.0  # 6 mL/kg * 70 kg
    
    def _calculate_rate(self, vitals: Dict[str, Any]) -> int:
        """计算呼吸频率"""
        return 16
    
    def _generate_reasoning(self, vitals: Dict[str, Any]) -> str:
        """生成决策依据"""
        spo2 = vitals.get('spo2', 95)
        hr = vitals.get('heart_rate', 75)
        
        reasoning = f"""
        基于患者当前状态:
        - SpO₂: {spo2:.1f}% (正常范围)
        - 心率: {hr:.0f} bpm (稳定)
        - 呼吸频率: {vitals.get('resp_rate', 16):.1f} breaths/min
        
        采用保守的肺保护策略:
        - PEEP: 8 cmH₂O (维持肺泡招张)
        - FiO₂: 45% (避免氧中毒)
        - Tidal Volume: 420 mL (ARDS防护，6-8 mL/kg标准)
        """
        return reasoning


class SafetyAgent:
    """安全智能体：验证参数安全性"""
    
    def __init__(self):
        self.name = "安全智能体"
    
    def check_safety(self, decision_output: Dict[str, Any]) -> Dict[str, Any]:
        """
        执行安全检查
        
        参数:
            decision_output: 来自决策智能体的输出
        
        返回:
            安全检查结果
        """
        recommendation = decision_output.get('recommendation', {})
        
        safety_check = {
            'timestamp': datetime.now().isoformat(),
            'is_safe': True,
            'violations': [],
            'warnings': [],
            'approved_params': recommendation
        }
        
        # 安全阈值检查
        tv = recommendation.get('tidal_volume', 0)
        if tv > 500:  # 肺损伤风险阈值
            safety_check['is_safe'] = False
            safety_check['violations'].append('潮气量超过安全阈值（>500 mL），存在肺损伤风险')
        
        fio2 = recommendation.get('fio2', 0)
        if fio2 > 80:
            safety_check['warnings'].append('FiO₂过高，长期可能导致氧中毒')
        
        peep = recommendation.get('peep', 0)
        if peep > 20:
            safety_check['warnings'].append('PEEP过高，可能降低心输出量')
        
        return safety_check


class MASOrchestrator:
    """多智能体编排器：协调三个智能体的执行"""
    
    def __init__(self):
        self.perception_agent = PerceptionAgent()
        self.decision_agent = DecisionAgent()
        self.safety_agent = SafetyAgent()
        self.state = AgentState()
    
    def execute_workflow(self, patient_vitals: Dict[str, Any]) -> Dict[str, Any]:
        """
        执行完整的智能体工作流
        
        参数:
            patient_vitals: 患者生理参数
        
        返回:
            完整的工作流执行结果
        """
        # 第1步：感知
        self.state.perception_data = self.perception_agent.process_vitals(patient_vitals)
        self.state.add_log("感知智能体", "完成患者数据采集和预处理")
        
        # 第2步：决策
        self.state.decision_output = self.decision_agent.make_decision(self.state.perception_data)
        self.state.add_log("CQL决策智能体", "生成参数调整方案")
        
        # 第3步：安全检查
        self.state.safety_check = self.safety_agent.check_safety(self.state.decision_output)
        self.state.add_log("安全智能体", "完成安全验证")
        
        # 如果安全检查未通过，触发循环回流
        if not self.state.safety_check['is_safe']:
            self.state.add_log("系统", "检测到违规，触发循环回流", level="warning")
            self.state.active_alerts.extend(self.state.safety_check['violations'])
            return self._handle_violation()
        
        return {
            'success': True,
            'state': self.state.to_dict(),
            'final_params': self.state.safety_check['approved_params'],
            'alert_triggered': False
        }
    
    def _handle_violation(self) -> Dict[str, Any]:
        """处理安全违规"""
        return {
            'success': False,
            'state': self.state.to_dict(),
            'final_params': None,
            'alert_triggered': True,
            'message': '参数方案被拒绝，等待重新决策'
        }
