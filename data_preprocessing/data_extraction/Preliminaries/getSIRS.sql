-- getSIRS.sql (PostgreSQL version)
-- 计算 SIRS (Systemic Inflammatory Response Syndrome) 分数，基于 MIMIC-IV 数据
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/getSIRS_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化

-- DROP TABLE IF EXISTS sirs;
-- CREATE TABLE sirs AS

WITH scorecomp AS (

SELECT stay_id, subject_id, hadm_id, start_time, tempc, heartrate, resprate, paco2, wbc, bands
FROM overalltable2),

scorecalc AS (
SELECT stay_id, subject_id, hadm_id, start_time, tempc, heartrate, resprate, paco2, wbc, bands
, CASE
    WHEN tempc < 36.0 THEN 1
    WHEN tempc > 38.0 THEN 1
    WHEN tempc IS NULL THEN NULL
    ELSE 0
  END AS temp_score
, CASE
    WHEN heartrate > 90.0 THEN 1
    WHEN heartrate IS NULL THEN NULL
    ELSE 0
  END AS heartrate_score
, CASE
    WHEN resprate > 20.0 THEN 1
    WHEN paco2 < 32.0 THEN 1
    WHEN COALESCE(resprate, paco2) IS NULL THEN NULL
    ELSE 0
  END AS resp_score
, CASE
    WHEN wbc < 4.0 THEN 1
    WHEN wbc > 12.0 THEN 1
    WHEN bands > 10 THEN 1 -- > 10% immature neurophils (band forms)
    WHEN COALESCE(wbc, bands) IS NULL THEN NULL
    ELSE 0
  END AS wbc_score

FROM scorecomp
)

SELECT
  stay_id, subject_id, hadm_id, start_time
  -- Combine all the scores to get SIRS
  -- Impute 0 if the score is missing
  , COALESCE(temp_score, 0)
  + COALESCE(heartrate_score, 0)
  + COALESCE(resp_score, 0)
  + COALESCE(wbc_score, 0)
    AS sirs
  , temp_score, heartrate_score, resp_score, wbc_score
FROM scorecalc;
