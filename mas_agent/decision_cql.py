import d3rlpy

class DecisionAgent:
    def __init__(self, model_path=None):
        # 初始化 CQL 算法配置
        self.algo = d3rlpy.algos.CQLConfig().create(use_gpu=False)
        if model_path:
            self.load_brain(model_path)

    def train(self, dataset):
        """离线预训练逻辑"""
        self.algo.fit(dataset, n_steps=10000)
        self.algo.save_model('models/saved_weights/decision_agent_cql.pt')

    def get_action(self, state):
        """根据当前状态输出通气参数建议"""
        # predict 会返回一个动作数组，例如 [PEEP, FiO2]
        action = self.algo.predict(state.reshape(1, -1))[0]
        return action

    def load_brain(self, path):
        self.algo.build_with_env(observation_shape=(18,), action_size=5) # 根据 Table 3/4 设定维度
        self.algo.load_model(path)