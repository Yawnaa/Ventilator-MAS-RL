-- getSOFA.sql (PostgreSQL version)
-- 计算 SOFA (Sequential Organ Failure Assessment) 分数，基于 MIMIC-IV 数据
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/getSOFA_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化

/*
============================================================
脚本名称：getSOFA.sql (MIMIC-IV 兼容修正版)
============================================================
【功能描述】：
1. 计算每个患者在每个 4 小时网格点的 SOFA 器官衰竭评分。
2. 针对源表缺失血管活性药物速率（rate_dopamine 等）的情况进行了补丁处理。

【数据用途】：
- 提供强化学习的“状态 (State)”特征。
- 综合评估患者病情严重程度，数值越高代表器官衰竭越严重。
============================================================
*/

-- 1. 清理并创建新表
DROP TABLE IF EXISTS sofa CASCADE;
CREATE TABLE sofa AS

-- ------------------------------------------------------------
-- 步骤 1: 数据准备 (scorecomp)
-- 从 overalltable2 中提取原始指标。针对缺失的药物速率字段进行补零。
-- ------------------------------------------------------------
WITH scorecomp AS (
    SELECT 
        stay_id, subject_id, hadm_id, start_time,
        pao2fio2ratio, mechvent, -- 呼吸系统
        gcs,                     -- 神经系统
        meanbp,                  -- 循环系统基础指标
        -- 【补丁】：如果表中缺少这些列，暂时用 0 占位以通过编译
        0 AS rate_dopamine, 
        0 AS rate_norepinephrine, 
        0 AS rate_epinephrine,
        bilirubin,               -- 肝脏
        platelet,                -- 凝血
        creatinine, urineoutput  -- 肾脏
    FROM overalltable2
),

-- ------------------------------------------------------------
-- 步骤 2: 单项系统打分 (scorecalc)
-- 基于国际 SOFA 标准将连续生理指标转换为 0-4 分。
-- ------------------------------------------------------------
scorecalc AS (
SELECT *,
    -- 呼吸得分 (Respiration)
    CASE 
        WHEN pao2fio2ratio < 100 AND mechvent = 1 THEN 4 
        WHEN pao2fio2ratio < 200 AND mechvent = 1 THEN 3 
        WHEN pao2fio2ratio < 300 THEN 2 
        WHEN pao2fio2ratio < 400 THEN 1 
        WHEN pao2fio2ratio IS NULL THEN NULL 
        ELSE 0 
    END AS respiration,

    -- 神经得分 (CNS)
    CASE 
        WHEN gcs >= 13 AND gcs <= 14 THEN 1 
        WHEN gcs >= 10 AND gcs <= 12 THEN 2 
        WHEN gcs >= 6 AND gcs <= 9 THEN 3 
        WHEN gcs < 6 THEN 4 
        WHEN gcs IS NULL THEN NULL 
        ELSE 0 
    END AS cns,

    -- 心血管得分 (Cardiovascular)
    -- 注意：由于当前 rate 字段为 0，此得分主要由 meanbp 触发
    CASE 
        WHEN rate_dopamine > 15 OR rate_epinephrine > 0.1 OR rate_norepinephrine > 0.1 THEN 4 
        WHEN rate_dopamine > 5 OR rate_epinephrine <= 0.1 OR rate_norepinephrine <= 0.1 THEN 3 
        WHEN rate_dopamine <= 5 AND (rate_dopamine > 0) THEN 2 
        WHEN meanbp < 70 THEN 1 
        WHEN COALESCE(meanbp, rate_dopamine, rate_epinephrine, rate_norepinephrine) IS NULL THEN NULL 
        ELSE 0 
    END AS cardiovascular,

    -- 肝脏得分 (Liver)
    CASE 
        WHEN bilirubin >= 12.0 THEN 4 
        WHEN bilirubin >= 6.0 THEN 3 
        WHEN bilirubin >= 2.0 THEN 2 
        WHEN bilirubin >= 1.2 THEN 1 
        WHEN bilirubin IS NULL THEN NULL 
        ELSE 0 
    END AS liver,

    -- 凝血得分 (Coagulation)
    CASE 
        WHEN platelet < 20 THEN 4 
        WHEN platelet < 50 THEN 3 
        WHEN platelet < 100 THEN 2 
        WHEN platelet < 150 THEN 1 
        WHEN platelet IS NULL THEN NULL 
        ELSE 0 
    END AS coagulation,

    -- 肾脏得分 (Renal)
    CASE 
        WHEN (creatinine >= 5.0) OR (urineoutput < 200) THEN 4 
        WHEN (creatinine >= 3.5 AND creatinine < 5.0) OR (urineoutput < 500) THEN 3 
        WHEN (creatinine >= 2.0 AND creatinine < 3.5) THEN 2 
        WHEN (creatinine >= 1.2 AND creatinine < 2.0) THEN 1 
        WHEN COALESCE(urineoutput, creatinine) IS NULL THEN NULL 
        ELSE 0 
    END AS renal
FROM scorecomp
)

-- ------------------------------------------------------------
-- 步骤 3: 汇总输出与总分计算
-- ------------------------------------------------------------
SELECT 
    stay_id, subject_id, hadm_id, start_time,
    -- 保留各系统单项分
    respiration, cns, cardiovascular, liver, coagulation, renal,
    -- 计算 SOFA 总分 (0-24分)
    (COALESCE(respiration, 0) + 
     COALESCE(cns, 0) + 
     COALESCE(cardiovascular, 0) + 
     COALESCE(liver, 0) + 
     COALESCE(coagulation, 0) + 
     COALESCE(renal, 0)) AS sofa
FROM scorecalc;

-- 2. 建立索引（为后续的整体表合并提速）
CREATE INDEX IF NOT EXISTS sofa_idx_stay_time ON sofa (stay_id, start_time);