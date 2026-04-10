-- Initial code was retrieved https://github.com/arnepeine/ventai/blob/main/sampled_data_with_scdem_withventparams.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- Code was modified to be campatible with MIMIC IV.

-- query script to merge the sampled data with the corresponding scores and demographic information
/*
============================================================
脚本名称：OverallTable3_Final.sql (全特征整合总表)
============================================================
【本表产出数据说明】：
1. 这是一个“全维度”的临床轨迹大表，每一行代表患者在一个 4 小时窗口内的完整状态。
2. 整合了：
   - 动态生理指标 (OverallTable2)
   - 器官衰竭与炎症评分 (SOFA, SIRS)
   - 人口统计学背景 (Age, Gender, Elixhauser)
   - 体重指标 (Actual Weight, Ideal Body Weight)
   - 最终临床结局 (Mortality, Death Time)

【本表核心作用】：
1. 强化学习状态空间 (State)：提供模型决策所需的全部背景信息。
2. 奖励函数计算 (Reward)：关联了 90 天死亡率标签，是判断模型操作对错的基准。
3. 训练轨迹生成：按时间顺序排列，方便 Python 脚本直接切割成 (s, a, r, s') 元组。
============================================================
*/

-- ------------------------------------------------------------
-- 0. 性能优化：建立复合索引 (如果之前没建，这步至关重要)
-- ------------------------------------------------------------
-- 复合索引（ID + 时间）能让左连接的速度提升 10 倍以上
CREATE INDEX IF NOT EXISTS idx_ot2_stay_time ON OverallTable2(stay_id, start_time);
CREATE INDEX IF NOT EXISTS idx_sofa_stay_time ON SOFA(stay_id, start_time);
CREATE INDEX IF NOT EXISTS idx_sirs_stay_time ON SIRS(stay_id, start_time);

-- 静态表只需要 stay_id 索引
CREATE INDEX IF NOT EXISTS idx_ibw_stay_id ON idealbodyweight(stay_id);
CREATE INDEX IF NOT EXISTS idx_weight_stay_id ON getWeight(stay_id);
CREATE INDEX IF NOT EXISTS idx_demog_stay_id ON getMainDemographics(stay_id);

-- ------------------------------------------------------------
-- 1. 创建总装表 OverallTable3
-- ------------------------------------------------------------
DROP TABLE IF EXISTS OverallTable3 CASCADE;
CREATE TABLE OverallTable3 AS

SELECT
    -- A. 基础标识与时间轴
    samp.stay_id, 
    ic.subject_id, 
    ic.hadm_id, 
    samp.start_time, 
    
    -- B. 人口统计学与静态背景
    dem.first_admit_age,     -- 入院年龄
    dem.gender,              -- 性别
    weig.weight,             -- 入院体重
    ideal.ideal_body_weight_kg, -- 理想体重 (IBW)
    dem.icu_readm,           -- 是否再入 ICU
    dem.elixhauser_score,    -- 共病严重程度评分
    
    -- C. 派生临床评分 (专家知识)
    sf.sofa,                 -- 器官衰竭总分
    sr.sirs,                 -- 炎症反应总分
    
    -- D. 详细生命体征与实验室检查 (State)
    samp.gcs, samp.heartrate, samp.sysbp, samp.diasbp, samp.meanbp,
    samp.shockindex, samp.resprate, samp.tempc, samp.spo2, 
    samp.potassium, samp.sodium, samp.chloride, samp.glucose, 
    samp.bun, samp.creatinine, samp.magnesium, samp.calcium, 
    samp.ionizedcalcium, samp.carbondioxide, samp.sgot, samp.sgpt, 
    samp.bilirubin, samp.albumin, samp.hemoglobin, samp.wbc, 
    samp.platelet, samp.ptt, samp.pt, samp.inr, samp.ph, 
    samp.pao2, samp.paco2, samp.base_excess, samp.bicarbonate, 
    samp.lactate, samp.pao2fio2ratio, 
    
    -- E. 呼吸机干预参数 (Action)
    samp.mechvent,           -- 机械通气状态 (0/1)
    samp.fio2,               -- 吸氧浓度
    samp.peep,               -- 呼气末正压
    samp.tidal_volume,       -- 原始潮气量
    
    -- 【计算列】：经过理想体重校正的潮气量 (RL研究的核心动作特征)
    -- 使用 NULLIF 避免除以零报错
    (samp.tidal_volume / NULLIF(ideal.ideal_body_weight_kg, 0)) AS adjusted_tidal_volume,
    
    samp.plateau_pressure,   -- 平台压
    
    -- F. 辅助治疗与结局 (Reward 相关)
    samp.urineoutput,        -- 尿量
    samp.vaso_total,         -- 血管活性药物总量
    samp.iv_total,           -- 输液总量
    samp.cum_fluid_balance,  -- 累计液体平衡
    dem.hospmort90day,       -- 【核心标签】：90天死亡标志 (0=存活, 1=死亡)
    dem.dischtime,           -- 出院时间
    dem.deathtime            -- 死亡时间

FROM OverallTable2 samp

-- 1. 关联 SIRS (需要 ID 和 时间 同时匹配)
LEFT JOIN SIRS sr
    ON samp.stay_id = sr.stay_id AND samp.start_time = sr.start_time

-- 2. 关联 SOFA (需要 ID 和 时间 同时匹配)
LEFT JOIN SOFA sf
    ON samp.stay_id = sf.stay_id AND samp.start_time = sf.start_time

-- 3. 关联静态人口学特征
LEFT JOIN getMainDemographics dem
    ON samp.stay_id = dem.stay_id 

-- 4. 关联实际体重
LEFT JOIN getWeight weig
    ON samp.stay_id = weig.stay_id

-- 5. 关联理想体重
LEFT JOIN idealbodyweight ideal
    ON samp.stay_id = ideal.stay_id

-- 6. 强制匹配 ICU 入院基本信息表
INNER JOIN icustays ic
    ON samp.stay_id = ic.stay_id

-- 按照患者和时间线性排序，确保轨迹逻辑正确
ORDER BY samp.stay_id, samp.start_time;
