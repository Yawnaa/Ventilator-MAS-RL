-- getSIRS.sql (PostgreSQL version)
-- 计算 SIRS (Systemic Inflammatory Response Syndrome) 分数，基于 MIMIC-IV 数据
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/getSIRS_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化

-- ==============================================================================
-- 准备工作：建表
-- ==============================================================================
DROP TABLE IF EXISTS sirs CASCADE;
CREATE TABLE sirs AS

-- ==============================================================================
-- 步骤 1: 数据抽取 (CTE: scorecomp)
-- 从我们刚刚完美建好的 4 小时网格表 (overalltable2) 中，提取计算 SIRS 所需的原始特征。
-- ==============================================================================
WITH scorecomp AS (
    SELECT 
        stay_id, subject_id, hadm_id, start_time, -- 核心的主键和时间轴
        tempc,       -- 体温 (摄氏度)
        heartrate,   -- 心率
        resprate,    -- 呼吸频率
        paco2,       -- 动脉血二氧化碳分压
        wbc,         -- 白细胞计数
        bands        -- 杆状核粒细胞（未成熟白细胞）百分比
    FROM overalltable2
),

-- ==============================================================================
-- 步骤 2: 单项指标打分 (CTE: scorecalc)
-- 根据国际医学通用的 SIRS 标准，将连续的生理指标转化为 0 或 1 的离散得分。
-- ==============================================================================
scorecalc AS (
    SELECT 
        stay_id, subject_id, hadm_id, start_time, 
        tempc, heartrate, resprate, paco2, wbc, bands
        
        -- 1. 体温得分：< 36°C 或 > 38°C 记 1 分
        , CASE
            WHEN tempc < 36.0 THEN 1
            WHEN tempc > 38.0 THEN 1
            WHEN tempc IS NULL THEN NULL -- 缺失值先保留为 NULL
            ELSE 0
          END AS temp_score
          
        -- 2. 心率得分：> 90 次/分钟 记 1 分
        , CASE
            WHEN heartrate > 90.0 THEN 1
            WHEN heartrate IS NULL THEN NULL
            ELSE 0
          END AS heartrate_score
          
        -- 3. 呼吸得分：呼吸频率 > 20 次/分钟 或 二氧化碳分压 < 32 记 1 分
        , CASE
            WHEN resprate > 20.0 THEN 1
            WHEN paco2 < 32.0 THEN 1
            WHEN COALESCE(resprate, paco2) IS NULL THEN NULL
            ELSE 0
          END AS resp_score
          
        -- 4. 白细胞得分：< 4 或 > 12，或者未成熟粒细胞 > 10% 记 1 分
        , CASE
            WHEN wbc < 4.0 THEN 1
            WHEN wbc > 12.0 THEN 1
            WHEN bands > 10 THEN 1 
            WHEN COALESCE(wbc, bands) IS NULL THEN NULL
            ELSE 0
          END AS wbc_score

    FROM scorecomp
)

-- ==============================================================================
-- 步骤 3: 汇总总分并处理缺失值 (最终 SELECT 输出)
-- ==============================================================================
SELECT
    stay_id, subject_id, hadm_id, start_time,
    
    -- 【魔法核心】：将四个单项分数相加，得到 0~4 分的总分 (sirs)
    -- 注意：这里使用了 COALESCE(字段, 0)。
    -- 意思是：如果在这一条 4 小时的数据里，患者某项没查（分数为 NULL），
    -- 就默认他是健康的（记为 0 分），这样能确保总分一定能算出来，不会因为一个 NULL 导致整行作废。
    COALESCE(temp_score, 0)
    + COALESCE(heartrate_score, 0)
    + COALESCE(resp_score, 0)
    + COALESCE(wbc_score, 0)
    AS sirs, 
    
    -- 把单项得分也一并输出，方便以后追溯
    temp_score, heartrate_score, resp_score, wbc_score
FROM scorecalc;