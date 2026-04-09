-- Initial code for the vital sign portion was retrieved from https://github.com/arnepeine/ventai/blob/main/getVitalSigns.sql
-- Initial code for the GCS portion was retrieved from https://github.com/arnepeine/ventai/blob/main/getGCS.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- getAllVitalSigns.sql (PostgreSQL version)
-- 提取生命体征数据和格拉斯哥昏迷评分（GCS），基于 MIMIC-IV chartevents 表
-- 得到的数据：subject_id, hadm_id, stay_id, charttime, gcs, HeartRate, SysBP, DiasBP, MeanBP, RespRate, TempC, SpO2

DROP TABLE IF EXISTS getAllVitalSigns;
CREATE TABLE getAllVitalSigns AS

--  STEP 1: GET ALL VITAL SIGNS EXCEPT GCS SCORE

WITH ce AS (
  SELECT ce.stay_id, ce.subject_id, ce.hadm_id, ce.charttime
    , (CASE WHEN itemid IN (211,220045) AND valuenum > 0 AND valuenum < 300 THEN valuenum ELSE NULL END) AS HeartRate
    , (CASE WHEN itemid IN (51,442,455,6701,220179,220050) AND valuenum > 0 AND valuenum < 400 THEN valuenum ELSE NULL END) AS SysBP
    , (CASE WHEN itemid IN (8368,8440,8441,8555,220180,220051) AND valuenum > 0 AND valuenum < 300 THEN valuenum ELSE NULL END) AS DiasBP
    , (CASE WHEN itemid IN (456,52,6702,443,220052,220181,225312) AND valuenum > 0 AND valuenum < 300 THEN valuenum ELSE NULL END) AS MeanBP
    , (CASE WHEN itemid IN (615,618,220210,224690) AND valuenum > 0 AND valuenum < 70 THEN valuenum ELSE NULL END) AS RespRate
    , (CASE WHEN itemid IN (223761,678) AND valuenum > 70 AND valuenum < 120 THEN (valuenum-32)/1.8
               WHEN itemid IN (223762,676) AND valuenum > 10 AND valuenum < 50 THEN valuenum ELSE NULL END) AS TempC
    , (CASE WHEN itemid IN (646,220277) AND valuenum > 0 AND valuenum <= 100 THEN valuenum ELSE NULL END) AS SpO2
  FROM chartevents ce
  WHERE ce.itemid IN (
  211, 220045,
  51,442,455,6701,220179,220050,
  8368,8440,8441,8555,220180,220051,
  456,52,6702,443,220052,220181,225312,
  618, 615,220210,224690,
  646, 220277,
  223762,676,223761,678
)) ,

--  STEP 2: GET THE GCS SCORE

 base AS (
  SELECT ce.subject_id, ce.stay_id, ce.hadm_id, ce.charttime
  , MAX(CASE WHEN ce.itemid IN (223901) THEN ce.valuenum ELSE NULL END) AS GCSMotor
  , MAX(CASE WHEN ce.itemid IN (223900) THEN ce.valuenum ELSE NULL END) AS GCSVerbal
  , MAX(CASE WHEN ce.itemid IN (220739) THEN ce.valuenum ELSE NULL END) AS GCSEyes
  , MAX(CASE
      WHEN ce.itemid = 223900 AND ce.value = 'No Response-ETT' THEN 1
    ELSE 0 END) AS endotrachflag
  , ROW_NUMBER() OVER (PARTITION BY ce.stay_id ORDER BY ce.charttime ASC) AS rn
  FROM chartevents ce
  WHERE ce.itemid IN (223900, 223901, 220739)
  GROUP BY ce.subject_id, ce.stay_id, ce.hadm_id, ce.charttime
)
, gcs AS (
  SELECT b.*
  , b2.GCSVerbal AS GCSVerbalPrev
  , b2.GCSMotor AS GCSMotorPrev
  , b2.GCSEyes AS GCSEyesPrev
  , CASE
      WHEN b.GCSVerbal = 0
        THEN 15
      WHEN b.GCSVerbal IS NULL AND b2.GCSVerbal = 0
        THEN 15
      WHEN b2.GCSVerbal = 0
        THEN
            COALESCE(b.GCSMotor,6)
          + COALESCE(b.GCSVerbal,5)
          + COALESCE(b.GCSEyes,4)
      ELSE
            COALESCE(b.GCSMotor,COALESCE(b2.GCSMotor,6))
          + COALESCE(b.GCSVerbal,COALESCE(b2.GCSVerbal,5))
          + COALESCE(b.GCSEyes,COALESCE(b2.GCSEyes,4))
      END AS GCS

  FROM base b
  LEFT JOIN base b2
    ON b.stay_id = b2.stay_id
    AND b.rn = b2.rn+1
    AND b2.charttime > b.charttime - INTERVAL '6' HOUR
)
, gcs_stg AS (
  SELECT gs.subject_id, gs.stay_id, gs.hadm_id, gs.charttime
  , GCS
  , COALESCE(GCSMotor,GCSMotorPrev) AS GCSMotor
  , COALESCE(GCSVerbal,GCSVerbalPrev) AS GCSVerbal
  , COALESCE(GCSEyes,GCSEyesPrev) AS GCSEyes
  , CASE WHEN COALESCE(GCSMotor,GCSMotorPrev) IS NULL THEN 0 ELSE 1 END
  + CASE WHEN COALESCE(GCSVerbal,GCSVerbalPrev) IS NULL THEN 0 ELSE 1 END
  + CASE WHEN COALESCE(GCSEyes,GCSEyesPrev) IS NULL THEN 0 ELSE 1 END
    AS components_measured
  , EndoTrachFlag
  FROM gcs gs
)
, gcs_priority AS (
  SELECT subject_id, stay_id, hadm_id
    , charttime
    , GCS
    , GCSMotor
    , GCSVerbal
    , GCSEyes
    , EndoTrachFlag
    , ROW_NUMBER() OVER (
        PARTITION BY stay_id, charttime
        ORDER BY components_measured DESC, endotrachflag, gcs, charttime DESC
      ) AS rn
  FROM gcs_stg
)

, getGCS AS (
SELECT subject_id, hadm_id, stay_id, charttime, GCS, GCSMotor, GCSVerbal, GCSEyes, EndoTrachFlag
FROM gcs_priority gs
WHERE rn = 1
ORDER BY stay_id, charttime
)

--  STEP 3: Get vital signs including GCS in one table
, get_all_signs AS (
(SELECT ce.subject_id, ce.hadm_id, ce.stay_id, ce.charttime, ce.HeartRate, ce.SysBP, ce.DiasBP, ce.MeanBP, ce.RespRate, ce.TempC, ce.SpO2, getGCS.gcs
  FROM ce
 LEFT JOIN getGCS ON ce.stay_id = getGCS.stay_id AND ce.charttime = getGCS.charttime)
UNION
(SELECT getGCS.subject_id, getGCS.hadm_id, getGCS.stay_id, getGCS.charttime, ce.HeartRate, ce.SysBP, ce.DiasBP, ce.MeanBP, ce.RespRate, ce.TempC, ce.SpO2, getGCS.gcs
  FROM ce
 RIGHT JOIN getGCS ON ce.stay_id = getGCS.stay_id AND ce.charttime = getGCS.charttime
 WHERE ce.subject_id IS NULL)
)

SELECT
  subject_id,
  hadm_id,
  stay_id,
  charttime,
  gcs,
  AVG(HeartRate) AS HeartRate,
  AVG(SysBP) AS SysBP,
  AVG(DiasBP) AS DiasBP,
  AVG(MeanBP) AS MeanBP,
  AVG(RespRate) AS RespRate,
  AVG(TempC) AS TempC,
  AVG(SpO2) AS SpO2
FROM get_all_signs
GROUP BY subject_id, hadm_id, stay_id, charttime, gcs
ORDER BY stay_id, hadm_id, charttime;

