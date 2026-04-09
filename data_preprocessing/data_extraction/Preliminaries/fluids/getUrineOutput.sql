-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getUrineOutput.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- getUrineOutput.sql (PostgreSQL version)
-- 提取尿液输出数据，基于 MIMIC-IV outputevents 表
-- 得到的数据：subject_id, hadm_id, stay_id, charttime, UrineOutput (尿液输出量)

DROP TABLE IF EXISTS getUrineOutput;
CREATE TABLE getUrineOutput AS
SELECT
  subject_id, hadm_id, stay_id, charttime, SUM(UrineOutput) AS UrineOutput
FROM (
SELECT oe.subject_id, oe.hadm_id, oe.stay_id, oe.charttime
  , CASE
      WHEN oe.itemid = 227488 AND oe.value > 0 THEN -1*oe.value ELSE oe.value
    END AS UrineOutput
  FROM outputevents oe
  WHERE itemid IN (
  -- these are the most frequently occurring urine output observations
  226559, -- "Foley"
  226560, -- "Void"
  226561, -- "Condom Cath"
  226584, -- "Ileoconduit"
  226563, -- "Suprapubic"
  226564, -- "R Nephrostomy"
  226565, -- "L Nephrostomy"
  226567, -- "Straight Cath"
  226557, -- "R Ureteral Stent"
  226558, -- "L Ureteral Stent"
  227488, -- GU Irrigant Volume In
  227489  -- GU Irrigant/Urine Volume Out
  )
) t1
GROUP BY t1.subject_id, t1.hadm_id, t1.stay_id, t1.charttime
ORDER BY t1.subject_id, t1.hadm_id, t1.stay_id, t1.charttime;
