-- getSOFA.sql (PostgreSQL version)
-- 计算 SOFA (Sequential Organ Failure Assessment) 分数，基于 MIMIC-IV 数据
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/getSOFA_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化

DROP TABLE IF EXISTS sofa;
CREATE TABLE sofa AS

WITH scorecomp AS (

SELECT stay_id, subject_id, hadm_id, start_time
           -- respiration
       , pao2fio2ratio, mechvent
	   -- nervous system
       , gcs
	   -- cardiovascular system
	   , meanbp, rate_dopamine
	   , rate_norepinephrine, rate_epinephrine
	   -- liver
       , bilirubin
	   -- coagulation
	   , platelet
	   -- kidneys (renal)
	   , creatinine, urineoutput

FROM overalltable2),

scorecalc AS (
SELECT stay_id, subject_id, hadm_id, start_time, pao2fio2ratio, mechvent, gcs, meanbp, rate_dopamine, rate_norepinephrine, rate_epinephrine
       , bilirubin, platelet, creatinine, urineoutput
	   , CASE
      WHEN pao2fio2ratio < 100 AND mechvent = 1 THEN 4
      WHEN pao2fio2ratio < 200 AND mechvent = 1 THEN 3
      WHEN pao2fio2ratio < 300 THEN 2
      WHEN pao2fio2ratio < 400 THEN 1
      WHEN pao2fio2ratio IS NULL THEN NULL
      ELSE 0
    END AS respiration
	  -- Neurological failure (GCS)
  , CASE
      WHEN (gcs >= 13 AND gcs <= 14) THEN 1
      WHEN (gcs >= 10 AND gcs <= 12) THEN 2
      WHEN (gcs >= 6 AND gcs <= 9) THEN 3
      WHEN gcs < 6 THEN 4
      WHEN gcs IS NULL THEN NULL
  ELSE 0 END
    AS cns
  -- Cardiovascular
  , CASE
      WHEN rate_dopamine > 15 OR rate_epinephrine > 0.1 OR rate_norepinephrine > 0.1 THEN 4
      WHEN rate_dopamine > 5 OR rate_epinephrine <= 0.1 OR rate_norepinephrine <= 0.1 THEN 3
      WHEN rate_dopamine <= 5 /*or rate_dobutamine > 0*/ THEN 2
      WHEN meanbp < 70 THEN 1
      WHEN COALESCE(meanbp, rate_dopamine, /*rate_dobutamine,*/ rate_epinephrine, rate_norepinephrine) IS NULL THEN NULL
      ELSE 0
    END AS cardiovascular
	-- Liver
  , CASE
      -- Bilirubin checks in mg/dL
        WHEN bilirubin >= 12.0 THEN 4
        WHEN bilirubin >= 6.0 THEN 3
        WHEN bilirubin >= 2.0 THEN 2
        WHEN bilirubin >= 1.2 THEN 1
        WHEN bilirubin IS NULL THEN NULL
        ELSE 0
      END AS liver
	  -- Coagulation
  , CASE
      WHEN platelet < 20 THEN 4
      WHEN platelet < 50 THEN 3
      WHEN platelet < 100 THEN 2
      WHEN platelet < 150 THEN 1
      WHEN platelet IS NULL THEN NULL
      ELSE 0
    END AS coagulation

	-- Renal failure - high creatinine or low urine output
  , CASE
    WHEN (creatinine >= 5.0) THEN 4
    WHEN urineoutput < 200 THEN 4
    WHEN (creatinine >= 3.5 AND creatinine < 5.0) THEN 3
    WHEN urineoutput < 500 THEN 3
    WHEN (creatinine >= 2.0 AND creatinine < 3.5) THEN 2
    WHEN (creatinine >= 1.2 AND creatinine < 2.0) THEN 1
    WHEN COALESCE(urineoutput, creatinine) IS NULL THEN NULL
  ELSE 0 END
    AS renal

	FROM scorecomp)

SELECT stay_id, subject_id, hadm_id, start_time
	   -- parameters from scorecomp
       , pao2fio2ratio, mechvent, gcs, meanbp, rate_dopamine, rate_norepinephrine, rate_epinephrine
       , bilirubin, platelet, creatinine, urineoutput
	   -- parameters from scorecalc, contains separate scores to estimate the final SOFA score
	   , respiration, cns, cardiovascular, liver, coagulation, renal
	   -- overall SOFA score calculation
       , COALESCE(respiration, 0) + COALESCE(cns, 0)
       + COALESCE(cardiovascular, 0) + COALESCE(liver, 0)
       + COALESCE(coagulation, 0) + COALESCE(renal, 0) AS sofa
	   
FROM scorecalc

ORDER BY stay_id, subject_id , hadm_id, start_time
