import numpy as np
import torch
import collections
import pickle

from data_preprocessing.train_test_split import rewards
from utils.load_utils import load_data

Experience = collections.namedtuple('Experience', field_names=['state', 'action', 'reward', 'done', 'new_state'])


def sample(self, batch_size):
    indices = np.random.randint(0, self.size, batch_size)
    states = [self.states[i] for i in indices]
    actions = [self.actions[i] for i in indices]
    rewards = [self.rewards[i] for i in indices]
    dones = [self.dones[i] for i in indices]
    next_states = [self.next_states[i] for i in indices]

    # --- 详细调试开始 ---
    print("\n[DEBUG] Sampling indices:", indices[:10], "...")
    problem_indices = []
    for i, idx in enumerate(indices):
        ns = self.next_states[idx]
        if ns is None:
            print(f"  Buffer index {idx}: None")
            problem_indices.append(idx)
        elif isinstance(ns, (list, np.ndarray)):
            arr = np.array(ns)
            if arr.shape != (self.state_dim,):
                print(f"  Buffer index {idx}: shape {arr.shape}, expected ({self.state_dim},)")
                problem_indices.append(idx)
        else:
            print(f"  Buffer index {idx}: unexpected type {type(ns)}")
            problem_indices.append(idx)
    
    if problem_indices:
        # 打印第一个问题样本的原始存储内容
        bad_idx = problem_indices[0]
        print(f"\n[DEBUG] First problematic buffer entry (index {bad_idx}):")
        print(f"  state: {self.states[bad_idx]}")
        print(f"  action: {self.actions[bad_idx]}")
        print(f"  reward: {self.rewards[bad_idx]}")
        print(f"  done: {self.dones[bad_idx]}")
        print(f"  next_state: {self.next_states[bad_idx]}")
    # --- 调试结束 ---

    # 继续原有转换...

def prepare_buffer(data, batch_size=128, buffer_size=1000000, device="cuda"):
    buffer = ReplayBuffer(buffer_size, batch_size, device)

    for episode in data.episodes:
        observations = episode.observations
        actions = episode.actions
        rewards = episode.rewards
        for i in range(len(observations)):
            # Determine new_state based on the done flag
            if i==(len(observations)-1):
                # empty state of 44 dimensions
                new_state = np.empty(44)
                terminal=1
            else:
                new_state = observations[i + 1] if i + 1 < len(observations) else np.array([])
                terminal=0

            experience = Experience(observations[i], actions[i], rewards[i], terminal, new_state)
            buffer.append(experience)
    return buffer


class ReplayBuffer:
    def __init__(self, buffer_size, batch_size, device):
        self.capacity = int(buffer_size)
        self.batch_size = batch_size
        self.buffer = collections.deque(maxlen=self.capacity)
        self.batch_size = batch_size
        self.device = device

    def __len__(self):
        return len(self.buffer)

    def append(self, experience):
        self.buffer.append(experience)

    def sample(self):
        indices = np.random.choice(len(self.buffer), self.batch_size, replace=False)
        states, actions, rewards, dones, next_states = zip(*[self.buffer[idx] for idx in indices])
        valid_dim = len(states[0]) # 获取正确的状态维度（这里就是 19）
        clean_next_states = []
        for ns in next_states:
        # 如果 next_state 是空的、None，或者由于某种原因长度不对，统一用全 0 补齐
          if ns is None or len(ns) == 0 or len(ns) != valid_dim:
            clean_next_states.append(np.zeros(valid_dim))
          else:
            clean_next_states.append(ns)
    
      # 替换原来的 next_states
        next_states = clean_next_states
        return (
            torch.FloatTensor(np.array(states)).to(self.device),
            torch.LongTensor(np.array(actions)).to(self.device),
            torch.FloatTensor(np.array(rewards)).to(self.device),
            torch.FloatTensor(np.array(dones)).to(self.device),
            torch.FloatTensor(np.array(next_states)).to(self.device),

        )

    def get_batch(self, batch_index, batch_size):
        start_index = batch_index * batch_size
        end_index = min(start_index + batch_size, len(self.buffer))
        batch = list(self.buffer)[start_index:end_index]
        states, actions, rewards, dones, next_states = zip(*batch)
        
        # === 给 get_batch 也加上一模一样的清洗逻辑 ===
        valid_dim = len(states[0]) 
        clean_next_states = []
        for ns in next_states:
          if ns is None or len(ns) == 0 or len(ns) != valid_dim:
            clean_next_states.append(np.zeros(valid_dim))
          else:
            clean_next_states.append(ns)
            
        next_states = clean_next_states
        # ==========================================

        return (
            torch.FloatTensor(np.array(states)).to(self.device),
            torch.LongTensor(np.array(actions)).to(self.device),
            torch.FloatTensor(np.array(rewards)).to(self.device),
            torch.FloatTensor(np.array(dones)).to(self.device),
            torch.FloatTensor(np.array(next_states)).to(self.device),
        )

    def get_batch_count(self, batch_size):
        return len(self.buffer) // batch_size

    def normalize_buffer(self):
        if len(self.buffer) == 0:
            return

        all_states = []
        for experience in self.buffer:
            all_states.append(experience[0])  # states

        all_states = np.array(all_states)

        self.state_mean = np.mean(all_states, axis=0)
        self.state_std = np.std(all_states, axis=0)
        self.state_std[self.state_std < 1e-5] = 1  # avoid division by zero

        normalized_buffer = []
        for experience in self.buffer:
            normalized_experience = (
                self.normalize_states(experience[0]),  # state
                experience[1],  # action
                experience[2],  # reward
                experience[3],  # done
                # next_state
                self.normalize_states(experience[4]) if (not experience[3]) else  experience[4] # not terminal state
            )
            normalized_buffer.append(normalized_experience)

        self.buffer = collections.deque(normalized_buffer, maxlen=self.capacity)

    def normalize_states(self, states):
        if self.state_mean is None or self.state_std is None:
            return states
        return (states - self.state_mean) / self.state_std

    def get_normalization_params(self):
        return self.state_mean, self.state_std
    def save(self, save_folder):
        # save buffer
        with open(save_folder, 'wb') as f:
            pickle.dump(self.buffer, f)

    def load(self, save_folder):
        with open(save_folder, 'rb') as f:
            self.buffer = pickle.load(f)


def get_buffers(device, with_cal, run_id, state_mode, reward_mode, buffer_size, batch_size):
    train_data, test_data, val_data, cal_data = load_data(states=state_mode,
                                                          rewards=reward_mode,
                                                          index_of_split=run_id, no_split=False,
                                                          with_cal=with_cal)
    train_replay_buffer = prepare_buffer(train_data, buffer_size=buffer_size,
                                         batch_size=batch_size, device=device)
    test_replay_buffer = prepare_buffer(test_data, buffer_size=buffer_size,
                                        batch_size=batch_size, device=device)
    val_replay_buffer = prepare_buffer(val_data, buffer_size=buffer_size,
                                       batch_size=batch_size, device=device)

    cal_replay_buffer = None
    if with_cal:
        cal_replay_buffer = prepare_buffer(cal_data, buffer_size=buffer_size,
                                           batch_size=batch_size, device=device)
    data_dic = {"train": train_replay_buffer, "test": test_replay_buffer, "val": val_replay_buffer,
                "cal": cal_replay_buffer, "cal_data": cal_data, "test_data": test_data,
                "val_data": val_data, "train_data": train_data}
    return data_dic
