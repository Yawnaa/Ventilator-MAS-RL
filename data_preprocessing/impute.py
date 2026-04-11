# -*- coding: utf-8 -*-
''''''
""" impute.py
功能：读取原始 CSV 数据，使用 KNN 和 Sample-and-Hold 策略填充缺失值，
      删除缺失率过高的特征，最终生成无缺失的插补数据文件。
 """

# 导入系统路径处理模块
# importing
import sys
import os
from pathlib import Path
import os
import pandas as pd

# 将当前工作目录添加到系统路径，确保后续导入能找到本地模块
sys.path.append(os.getcwd())
path = Path(os.getcwd())
sys.path.append(str(path.parent.absolute()))

# 导入项目自定义的插补工具函数
from utils.imputation_utils import preprocess_imputation
from constants import DATA_FOLDER_PATH


# 定义数据文件夹路径（实际上这里又定义了一次，可能与 constants 重复，但无伤大雅）
IMPUTED_DATA_DIR_PATH       = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../data")
# 插补参数设置
IMPUTATION_N                = 1
IMPUTATION_K                = 3
# 原始数据文件路径（注意：这里路径写的是 "../data/final-data.csv"，实际指向项目根目录下的 data 文件夹）
DATA_TABLE_FILE_NAME        = os.path.join(DATA_FOLDER_PATH, "../data/final-data.csv")
# 插补后数据的保存路径（以 pickle 格式保存，保留数据类型）
IMPUTED_DATAFRAME_PATH      = os.path.join(DATA_FOLDER_PATH,"imputed.pkl")
# 1. 读取原始 CSV 数据
# Get data into pandas dataframe
full_df = pd.read_csv(DATA_TABLE_FILE_NAME, na_values='\\N')
# Impute missing values
# 2. 调用预处理函数进行缺失值插补
# preprocess_imputation 内部实现了：
#   - 识别各列的缺失率
#   - 缺失率 < 30%：使用 KNN（K=3）插补
#   - 缺失率 30%~95%：使用 Sample-and-Hold（时间窗口内的前向填充）
#   - 缺失率 > 95%：直接删除该特征列
df = preprocess_imputation(full_df, IMPUTATION_N, IMPUTATION_K)
# 3. 删除仍包含任何缺失值的行（理论上经过上一步后不应再有缺失值，这是最后的安全保障）
df = df.dropna()

# 4. 输出处理信息，便于检查哪些特征被删除了
print("removed features:",[col for col in full_df.columns if col not in df.columns ])
print("final features:",df.columns)

# 5. 将插补后的数据保存为 pickle 文件
df.to_pickle(IMPUTED_DATAFRAME_PATH)
