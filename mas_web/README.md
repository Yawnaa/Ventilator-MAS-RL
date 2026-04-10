# 呼吸机多智能体协作系统（MAS-RL）前端

## 📋 项目概述

基于 **LangGraph** 的多智能体架构，为呼吸机调控系统提供工业级前端界面。系统集成了三个核心智能体：
- **感知智能体** 👁️：实时监测患者生理参数
- **CQL决策智能体** ⚙️：基于强化学习优化呼吸机参数
- **安全智能体** 🛡️：验证参数安全性，防止医疗事故

## 🎨 视觉设计特性

### 暗色调医疗科技感
- 深蓝灰色背景 (`#0f1419`)
- 医疗蓝强调色 (`#00f2ff`)
- 安全绿指示灯 (`#00ff88`)
- 警告红拦截提示 (`#ff6b6b`)

### 交互界面
- **左侧**：患者生理指标实时动态图表（SpO₂、HR、RR）
- **中间**：智能体协作流展示，包含决策逻辑和安全拦截气泡
- **右侧**：参数输出与思维链（CoT）医学依据演现

## 🚀 快速开始

### 1. 环境配置

```bash
# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

### 2. 启动应用

```bash
streamlit run main.py
```

应用将在 `http://localhost:8501` 启动

### 3. 数据库配置

编辑 `config.py` 中的 `DATABASE_CONFIG`：

```python
DATABASE_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'mimic_iv',
    'user': 'postgres',
    'password': 'your_password'
}
```

## 📁 项目结构

```
mas_web/
├── main.py                    # Streamlit主应用（完整前端界面）
├── config.py                  # 配置文件（阈值、参数、数据库）
├── database.py                # PostgreSQL数据库操作模块
├── langgraph_integration.py  # LangGraph多智能体系统集成
├── requirements.txt           # Python依赖列表
└── README.md                  # 本文件
```

## 🔧 核心模块说明

### `main.py` - Streamlit 前端

提供一个三列布局的交互式仪表板：

#### 左列：病人生理状态
- 实时 Metric 卡片（SpO₂、HR、RR）
- 三条动态折线图（采用 ECharts）
- 自动更新频率：每次"下一时刻"点击

#### 中列：智能体协作流
- 感知智能体：显示采集的生理参数
- CQL决策智能体：显示参数调整方案
- 安全智能体：通过/拦截决策，带动画效果
- 聊天气泡展示智能体间的"对话"

#### 右列：决策结果区
- 四个参数卡片（PEEP、FiO₂、Tidal Volume、置信度）
- **思维链（CoT）**：展示决策的医学依据
  - 患者状态评估
  - 参数调整逻辑
  - 风险评估
  - 预期效果

### `config.py` - 配置文件

定义系统的所有可配置参数：

```python
# 医疗参数安全阈值
VITALS_THRESHOLDS
VENTILATOR_PARAMS

# UI主题色
THEME_COLORS

# 数据库连接
DATABASE_CONFIG

# 智能体描述
AGENTS_CONFIG

# 时间序列参数
TIMESERIES_CONFIG
```

### `database.py` - 数据库模块

提供以下主要函数：

```python
get_db_connection()              # 获取缓存数据库连接
query_patient_vitals()           # 查询患者生理参数历史
query_ventilator_settings()      # 查询呼吸机参数历史
get_patient_demographics()       # 获取患者基本信息
insert_ventilator_action()       # 记录参数调整
```

**特性**：
- 使用 `@st.cache_resource` 缓存连接，提高性能
- 自动异常处理和用户提示
- 支持时间范围查询

### `langgraph_integration.py` - 多智能体系统

核心类：

#### `PerceptionAgent`
- `process_vitals()`: 采集和预处理生理参数
- 自动异常检测（低氧血症、心动过速等）
- 趋势分析和风险评估

#### `DecisionAgent`
- `make_decision()`: 基于感知输出生成参数调整方案
- 自动计算 PEEP、FiO₂、Tidal Volume、呼吸频率
- 生成医学依据推理文本

#### `SafetyAgent`
- `check_safety()`: 执行安全验证
- 检查是否违反医疗安全约束
- 支持违规拦截和警告

#### `MASOrchestrator`
- `execute_workflow()`: 编排完整的多智能体工作流
- 按顺序：感知→决策→安全检查
- 支持异常处理和循环回流

## 🎮 交互特性

### "下一时刻"按钮
点击按钮模拟时间推进，系统会：
1. 生成下一个时刻的患者数据（或从数据库读取）
2. 执行完整的智能体工作流
3. 30% 概率触发安全警告（演示拦截机制）
4. 更新前端显示

### 警告闪烁效果
当安全智能体拦截参数时：
- 界面触发红色预警
- 安全智能体状态灯闪烁（CSS动画）
- 显示"⚠️ 拦截"和具体违规信息
- CQL被要求重新决策

## 📊 数据流

```
患者原始数据 (PostgreSQL)
    ↓
[感知智能体] → 生理参数预处理、异常检测
    ↓
[CQL决策智能体] → 参数优化方案生成
    ↓
[安全智能体] → 安全检查、违规拦截
    ↓
✓ 通过 → 参数执行
✗ 失败 → 触发循环回流
    ↓
前端展示 (Streamlit)
```

## 🧠 思维链（CoT）示例

系统自动生成如下的医学依据文本：

```
【医学依据】

1. 患者状态评估
   • SpO₂ 正常 (95.2%)，说明当前氧合良好
   • 心率平稳，无脓毒症迹象

2. 参数调整逻辑
   • PEEP维持 8 cmH₂O → 维护肺泡招张
   • FiO₂保持 45% → 避免氧中毒
   • Tidal Volume 420 mL → ARDS防护标准（6-8 mL/kg）

3. 风险评估
   • 低通气伤(Volutrauma)风险: ✓
   • 肺损伤(VILI)概率: 2.1%
   • 方案安全性: 高置信度

4. 预期效果
   • 目标呼吸频率: 14-16 breaths/min
   • 预期4小时内SpO₂维持: >93%
   • 改善趋势: ↗
```

## 🔌 与 LangGraph 的集成

该前端被设计为与完整的 LangGraph 智能体系统集成。实际部署时：

1. **替换模拟数据**：使用 `database.py` 从 PostgreSQL 读取真实患者数据
2. **调用真实 LangGraph**：将 `langgraph_integration.py` 中的各智能体替换为真正的 LangGraph 节点
3. **实时反馈**：系统可通过 WebSocket 或消息队列实现实时更新

## 📋 依赖列表

```
streamlit==1.28.1               # 前端框架
streamlit-echarts==0.4.0        # 图表库
pandas==2.0.3                   # 数据处理
numpy==1.24.3                   # 数值计算
psycopg2-binary==2.9.7         # PostgreSQL驱动
python-dateutil==2.8.2          # 时间处理
```

## 🎯 设计亮点

1. **医疗级安全性**
   - 多重安全检查机制
   - 明确的违规拦截反馈
   - 循环回流机制确保最终参数安全

2. **用户体验**
   - 直观的三列布局
   - 实时动态图表
   - 清晰的智能体状态指示
   - 完整的决策推理展示

3. **工业级质感**
   - 暗色调医疗科技风格
   - 平滑的CSS动画和过渡
   - 响应式布局
   - 专业的排版和配色

4. **可扩展性**
   - 模块化设计
   - 易于集成真实数据源
   - 支持自定义阈值
   - 可配置的智能体逻辑

## 🐛 故障排除

### 数据库连接错误
```
解决：检查 config.py 中的数据库配置，确保 PostgreSQL 正在运行
```

### 图表不显示
```
解决：确保 streamlit-echarts 已正确安装
pip install --upgrade streamlit-echarts
```

### 应用卡顿
```
解决：使用 @st.cache_resource 缓存数据库连接和计算结果
```

## 📞 技术支持

项目基于以下技术栈：
- **前端**：Streamlit + ECharts
- **后端**：LangGraph + PostgreSQL
- **AI**：CQL 强化学习算法
- **医疗**：MIMIC-IV 数据集

---

**最后一次更新**：2024年4月10日
**开发者**：AI Assistant
**许可证**：MIT
