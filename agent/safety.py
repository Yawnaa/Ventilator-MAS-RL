class SafetyMonitorAgent:
    def __init__(self):
        # 设定来自 Table 3 的安全阈值
        self.min_peep = 5.0
        self.max_peep = 15.0
        self.max_p_plat = 30.0 # 肺保护通气的关键阈值

    def audit_action(self, current_state, recommended_action):
        """
        审计决策智能体的动作
        current_state 中包含平台压等关键实时指标
        """
        final_action = recommended_action.copy()
        
        # 假设状态的某个索引是平台压
        p_plat = current_state[1] 
        
        # 逻辑拦截：如果平台压过高，强制限制 PEEP 增加
        if p_plat > self.max_p_plat:
            print("【安全拦截】平台压过高！强制修正 PEEP 指令。")
            final_action[2] = self.min_peep # 假设索引2是 PEEP [cite: 329]
            
        return final_action