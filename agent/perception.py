import numpy as np

class PerceptionAgent:
    def __init__(self):
        # 这里的维度要和论文中 MIMIC-III 提取的特征数一致（如13或18维）
        self.state_dim = 18 

    def process_raw_data(self, raw_row):
        """
        将来自数据读取脚本的原始行转化为标准状态向量
        逻辑：处理缺失值 -> 物理量对齐 -> 归一化
        """
        # 示例：简单的归一化处理
        processed_state = np.array(raw_row) / 100.0 
        return processed_state

    def filter_signal(self, signal):
        """对气道压力等高频信号进行滤波（降噪）"""
        return np.mean(signal) # 示例：滑动平均滤波