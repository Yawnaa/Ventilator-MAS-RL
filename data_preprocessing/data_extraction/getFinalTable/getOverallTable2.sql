-- getOverallTable2.sql (PostgreSQL version)
-- 按 4 小时分辨率对 OverallTable 中的数据进行采样，基于 MIMIC-IV
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/sampling_lab_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化

-- 此代码使用 4 小时的分辨率对"overalltable"表中的数据进行采样
-- 在你的“呼吸机参数推荐”或类似的重症强化学习毕设项目中，SIRS 具有极其重要的战略地位：

-- 1. 扩充强化学习的状态空间 (State Space)
-- 你的模型需要“观察”患者的当前状态才能做出决策。光告诉它患者心率 110、体温 38.5 是不够的，加上 sirs = 3 这个高度浓缩的医学专家特征，能帮神经网络（DQN/SAC 等算法）更快地“顿悟”：哦，这是一个处于严重系统性炎症反应（败血症高风险）的病人，我的呼吸机参数必须调得更保守！

-- 2. 定义研究队列 (Cohort Definition)
-- 很多顶级顶会的医学 AI 论文（如 Nature 上的 AI Clinician），并不是针对所有 ICU 病人训练模型的。

-- 因为如果给一个仅仅是骨折术后观察的健康病人推荐呼吸机参数，是没有意义的。他们通常会在后面的代码里加上一句类似 WHERE sirs >= 2 的过滤条件，专门挑选那些真正患有重症感染/败血症的患者来训练 RL 智能体。这张表就是你后续做数据筛选的“通行证”。

-- 3. 作为降维的“安全网”
-- 你注意到了代码最后的 COALESCE(..., 0) 了吗？在真实医疗中，缺失值极多。SIRS 帮我们把容易缺失的 5 个连续变量，降维压缩成了 1 个绝对不会缺失的离散分数，提高了模型对抗噪声的鲁棒性。

-- 创建用于生成时间序列的数字表 (0-4000)
-- ==============================================================================
-- 【全局设置】
-- ==============================================================================
-- getOverallTable2.sql (PostgreSQL version)
-- 按 4 小时分辨率对 OverallTable 中的数据进行采样，基于 MIMIC-IV
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/sampling_lab_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化，并修复了极端离群值导致的数据爆炸问题

-- 此代码使用 4 小时的分辨率对"overalltable"表中的数据进行采样

-- ==============================================================================
-- 【全局设置】
-- ==============================================================================
SET search_path TO mimiciv_icu, mimiciv_hosp, public;

-- ==============================================================================
-- 1. 生成序列数字表 (0-4000)
-- ==============================================================================
DROP TABLE IF EXISTS numbers CASCADE;
CREATE TABLE numbers (n INT);

WITH RECURSIVE seq AS (
  SELECT 0 as n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 4000
)
INSERT INTO numbers (n) SELECT n FROM seq;

-- ==============================================================================
-- 2. 生成基准时间网格 (Grid) - 【已修复数据膨胀 Bug】
-- ==============================================================================
DROP TABLE IF EXISTS grid CASCADE;
CREATE TABLE grid AS
WITH minmax AS (
  SELECT 
      subject_id, 
      hadm_id, 
      stay_id, 
      min(charttime) as mint, 
      max(charttime) as raw_maxt
  FROM overalltable
  WHERE stay_id IS NOT NULL  -- 🔒 安全锁1：绝对不允许非 ICU 的 (Null) 幽灵数据混入
  GROUP BY stay_id, subject_id, hadm_id
)
SELECT
    stay_id,
    subject_id,
    hadm_id,
    CAST(mint + (INTERVAL '4 HOURS') * numbers.n AS TIMESTAMP) AS start_time
FROM minmax 
JOIN numbers 
  ON (mint + (INTERVAL '4 HOURS') * numbers.n) <= raw_maxt
  AND numbers.n <= 180;      -- 🔒 安全锁2：强制截断！一个 stay_id 最多生成 30 天 (180个) 网格，防止护士输错时间戳导致数据无限生成

-- ==============================================================================
-- 3. 建立关键索引 (加速的灵魂！必须执行！)
-- ==============================================================================
CREATE INDEX IF NOT EXISTS grid_idx_stay_id ON grid (stay_id);
CREATE INDEX IF NOT EXISTS ot_idx_stay_time ON overalltable (stay_id, charttime);

-- ==============================================================================
-- 4. 生成 OverallTable2 (绝对一致的最近邻插值)
-- ==============================================================================
DROP TABLE IF EXISTS overalltable2 CASCADE;

CREATE TABLE overalltable2 AS
SELECT 
    gr.stay_id,
    gr.subject_id,
    gr.hadm_id,
    gr.start_time,
    
    -- 直接从 LATERAL 表中提取那唯一一行的数据，取代几万次的 array_agg
    ot_near.gcs, ot_near.heartrate, ot_near.sysbp, ot_near.diasbp, ot_near.meanbp,
    ot_near.shockindex, ot_near.resprate, ot_near.tempc, ot_near.spo2, 
    ot_near.potassium, ot_near.sodium, ot_near.chloride, ot_near.glucose, 
    ot_near.bun, ot_near.creatinine, ot_near.magnesium, ot_near.calcium, 
    ot_near.ionizedcalcium, ot_near.carbondioxide, ot_near.sgot, ot_near.sgpt, 
    ot_near.bilirubin, ot_near.albumin, ot_near.hemoglobin, ot_near.wbc, 
    ot_near.platelet, ot_near.ptt, ot_near.pt, ot_near.inr, ot_near.ph, 
    ot_near.pao2, ot_near.paco2, ot_near.base_excess, ot_near.bicarbonate, 
    ot_near.lactate, ot_near.pao2fio2ratio, ot_near.bands, ot_near.mechvent, 
    ot_near.fio2, ot_near.urineoutput, ot_near.vaso_total, ot_near.iv_total, 
    ot_near.cum_fluid_balance, ot_near.peep, ot_near.tidal_volume, 
    ot_near.plateau_pressure

FROM grid gr
LEFT JOIN LATERAL (
    -- 【魔法核心】：针对每一个网格时间点，单独去大表里抓取最近的那一行
    SELECT *
    FROM overalltable ot
    WHERE ot.stay_id = gr.stay_id
      AND ot.charttime <= gr.start_time  -- 条件：必须在当前网格时间点之前或正好等于
    ORDER BY ot.charttime DESC           -- 倒序排列：最靠近网格时间的排在最上面
    LIMIT 1                              -- 只要第 1 条（即绝对时间差最小的那条）
) ot_near ON TRUE

ORDER BY gr.stay_id, gr.subject_id, gr.hadm_id, gr.start_time;