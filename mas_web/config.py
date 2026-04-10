"""
配置文件
"""

# 医疗参数范围（安全约束）
VITALS_THRESHOLDS = {
    'spo2': {'min': 85, 'max': 100, 'optimal_min': 93, 'optimal_max': 98},
    'heart_rate': {'min': 40, 'max': 150, 'optimal_min': 60, 'optimal_max': 100},
    'resp_rate': {'min': 6, 'max': 40, 'optimal_min': 12, 'optimal_max': 20},
}

VENTILATOR_PARAMS = {
    'peep': {'min': 3, 'max': 25, 'unit': 'cmH₂O'},
    'fio2': {'min': 21, 'max': 100, 'unit': '%'},
    'tidal_volume': {'min': 200, 'max': 800, 'unit': 'mL', 'safety_threshold': 500},
    'resp_rate_set': {'min': 6, 'max': 40, 'unit': 'breaths/min'},
}

# 主题配置
THEME_COLORS = {
    'primary': '#00f2ff',      # 医疗蓝
    'success': '#00ff88',      # 安全绿
    'warning': '#ff6b6b',      # 警告红
    'bg_dark': '#0f1419',      # 深蓝灰
    'bg_secondary': '#1a1f2e', # 次级背景
    'text_primary': '#e0e0e0', # 主文本
    'text_secondary': '#9ca3af', # 次文本
}

# PostgreSQL数据库配置
DATABASE_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'mimic_iv',
    'user': 'postgres',
    'password': 'password'
}

# 智能体配置
AGENTS_CONFIG = {
    'perception': {
        'name': '感知智能体',
        'emoji': '👁️',
        'description': '实时监测患者生理参数'
    },
    'decision': {
        'name': 'CQL决策智能体',
        'emoji': '⚙️',
        'description': '基于强化学习优化呼吸机参数'
    },
    'safety': {
        'name': '安全智能体',
        'emoji': '🛡️',
        'description': '验证参数安全性，防止医疗事故'
    }
}

# 时间序列配置
TIMESERIES_CONFIG = {
    'lookback_steps': 60,      # 历史步数（分钟）
    'forecast_steps': 60,      # 预测步数（分钟）
    'sampling_interval': 1     # 采样间隔（分钟）
}
