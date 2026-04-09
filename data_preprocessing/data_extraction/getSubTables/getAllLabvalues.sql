-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getLabValues.sql and https://github.com/arnepeine/ventai/blob/main/getOthers.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- getAllLabvalues.sql (PostgreSQL version)
-- 提取实验室检查数据，基于 MIMIC-IV labevents 和 chartevents 表
-- 得到的数据：subject_id, hadm_id, stay_id, charttime, 30+ 实验室指标（电解质、血气、血液细胞计数等）

DROP TABLE IF EXISTS getAllLabvalues;
CREATE TABLE getAllLabvalues AS

WITH le AS (
  SELECT ic.intime, ic.outtime, le.subject_id, le.hadm_id, ic.stay_id
    , le.charttime
    , (CASE WHEN itemid = 50862 AND valuenum > 0 AND valuenum < 10 THEN valuenum ELSE NULL END) AS ALBUMIN
    , (CASE WHEN itemid = 50868 AND valuenum > 0 AND valuenum < 10000 THEN valuenum ELSE NULL END) AS ANIONGAP
    , (CASE WHEN itemid = 51144 AND valuenum > 0 AND valuenum < 100 THEN valuenum ELSE NULL END) AS BANDS
    , (CASE WHEN itemid = 50882 AND valuenum > 0 AND valuenum < 10000 THEN valuenum ELSE NULL END) AS BICARBONATE
    , (CASE WHEN itemid = 50885 AND valuenum > 0 AND valuenum < 150 THEN valuenum ELSE NULL END) AS BILIRUBIN
    , (CASE WHEN itemid IN (50806, 50902) AND valuenum > 0 AND valuenum < 10000 THEN valuenum ELSE NULL END) AS CHLORIDE
    , (CASE WHEN itemid = 50912 AND valuenum > 0 AND valuenum < 150 THEN valuenum ELSE NULL END) AS CREATININE
    , (CASE WHEN itemid IN (50809,50931) AND valuenum > 0 AND valuenum < 10000 THEN valuenum ELSE NULL END) AS GLUCOSE
    , (CASE WHEN itemid IN (50810,51221) AND valuenum > 0 AND valuenum < 100 THEN valuenum ELSE NULL END) AS HEMATOCRIT
    , (CASE WHEN itemid IN (50811,51222) AND valuenum > 0 AND valuenum < 50 THEN valuenum ELSE NULL END) AS HEMOGLOBIN
    , (CASE WHEN itemid = 50813 AND valuenum > 0 AND valuenum < 50 THEN valuenum ELSE NULL END) AS LACTATE
    , (CASE WHEN itemid = 51265 AND valuenum > 0 AND valuenum < 10000 THEN valuenum ELSE NULL END) AS PLATELET
    , (CASE WHEN itemid IN (50822,50971) AND valuenum > 0 AND valuenum < 30 THEN valuenum ELSE NULL END) AS POTASSIUM
    , (CASE WHEN itemid = 51275 AND valuenum > 0 AND valuenum < 150 THEN valuenum ELSE NULL END) AS PTT
    , (CASE WHEN itemid = 51237 AND valuenum > 0 AND valuenum < 50 THEN valuenum ELSE NULL END) AS INR
    , (CASE WHEN itemid = 51274 AND valuenum > 0 AND valuenum < 150 THEN valuenum ELSE NULL END) AS PT
    , (CASE WHEN itemid IN (50824,50983) AND valuenum > 0 AND valuenum < 200 THEN valuenum ELSE NULL END) AS SODIUM
    , (CASE WHEN itemid = 51006 AND valuenum > 0 AND valuenum < 300 THEN valuenum ELSE NULL END) AS BUN
    , (CASE WHEN itemid IN (51300,51301) AND valuenum > 0 AND valuenum < 1000 THEN valuenum ELSE NULL END) AS WBC
	, (CASE WHEN itemid IN (50960) AND valuenum > 0 THEN valuenum ELSE NULL END) AS MAGNESIUM
	, (CASE WHEN itemid IN (50804) AND valuenum > 0 THEN valuenum ELSE NULL END) AS CARBONDIOXIDE
	, (CASE WHEN itemid IN (50802) AND valuenum > -10 AND valuenum < 10 THEN valuenum ELSE NULL END) AS BASE_EXCESS
	, (CASE WHEN itemid IN (50893) AND valuenum > 0 THEN valuenum ELSE NULL END) AS CALCIUM
	, (CASE WHEN itemid IN (50820) AND valuenum > 7 AND valuenum < 8 THEN valuenum ELSE NULL END) AS pH
	, (CASE WHEN itemid IN (50821) AND valuenum > 70 AND valuenum < 110 THEN valuenum ELSE NULL END) AS PaO2
	, (CASE WHEN itemid IN (50818) AND valuenum > 22 AND valuenum < 58 THEN valuenum ELSE NULL END) AS PaCO2

  FROM labevents le
	LEFT JOIN icustays ic
	ON le.subject_id = ic.subject_id AND le.hadm_id = ic.hadm_id
	AND le.charttime BETWEEN (ic.intime - INTERVAL '6' HOUR) AND (ic.outtime + INTERVAL '1' DAY)
  WHERE le.itemid IN (
    50868, 50862, 51144, 50882, 50885, 50912, 50902, 50806, 50931, 50809, 51221, 50810, 51222,
    50811, 50813, 51265, 50971, 50822, 51275, 51237, 51274, 50983, 50824, 51006, 51301, 51300,
	50960, 50804, 50802, 50893, 50820, 50821, 50818
  )
)

, ce AS (
  SELECT ce.stay_id, ce.subject_id, ce.hadm_id, ce.charttime
    , (CASE WHEN itemid IN (3801) THEN valuenum ELSE NULL END) AS SGOT
    , (CASE WHEN itemid IN (3802) THEN valuenum ELSE NULL END) AS SGPT
    , (CASE WHEN itemid IN (816,1350,3766,8177,8325,225667) THEN valuenum ELSE NULL END) AS IonizedCalcium
  FROM chartevents ce
  WHERE ce.itemid IN (3801, 3802, 816, 1350, 3766, 8177, 8325, 225667)
)

, others AS (
  SELECT subject_id, hadm_id, ce.stay_id, ce.charttime, AVG(SGOT) AS SGOT, AVG(SGPT) AS SGPT, AVG(IonizedCalcium) AS IonizedCalcium
  FROM ce
  GROUP BY ce.subject_id, ce.hadm_id, ce.stay_id, ce.charttime
)

, joined_tables AS (
  (SELECT
  	le.subject_id AS subject_id, le.hadm_id AS hadm_id, le.stay_id AS stay_id, le.charttime AS charttime, ALBUMIN, ANIONGAP,
       BANDS, BASE_EXCESS, BICARBONATE, BILIRUBIN, CHLORIDE,
      CARBONDIOXIDE, CALCIUM, CREATININE, GLUCOSE, HEMATOCRIT
     , HEMOGLOBIN, LACTATE, MAGNESIUM, PH, PLATELET, POTASSIUM,
  PTT, INR, PT, SODIUM, BUN, WBC, PaO2, PaCO2,
  others.SGOT, others.SGPT, others.IonizedCalcium
  FROM le LEFT JOIN others ON (le.stay_id = others.stay_id) AND (le.charttime = others.charttime))
  UNION
  (SELECT
  	others.subject_id AS subject_id, others.hadm_id AS hadm_id, others.stay_id AS stay_id, others.charttime AS charttime, ALBUMIN, ANIONGAP,
       BANDS, BASE_EXCESS, BICARBONATE, BILIRUBIN, CHLORIDE,
      CARBONDIOXIDE, CALCIUM, CREATININE, GLUCOSE, HEMATOCRIT
     , HEMOGLOBIN, LACTATE, MAGNESIUM, PH, PLATELET, POTASSIUM,
  PTT, INR, PT, SODIUM, BUN, WBC, PaO2, PaCO2,
  others.SGOT, others.SGPT, others.IonizedCalcium
  FROM le RIGHT JOIN others ON (le.stay_id = others.stay_id) AND (le.charttime = others.charttime)
  WHERE le.subject_id IS NULL
  )
)

SELECT
  subject_id, hadm_id, stay_id, charttime, AVG(ALBUMIN) AS ALBUMIN, AVG(ANIONGAP) AS ANIONGAP,
      AVG(BANDS) AS BANDS, AVG(BASE_EXCESS) AS BASE_EXCESS, AVG(BICARBONATE) AS BICARBONATE, AVG(BILIRUBIN) AS BILIRUBIN, AVG(CHLORIDE) AS CHLORIDE,
      AVG(CARBONDIOXIDE) AS CARBONDIOXIDE, AVG(CALCIUM) AS CALCIUM, AVG(CREATININE) AS CREATININE, AVG(GLUCOSE) AS GLUCOSE, AVG(HEMATOCRIT) AS HEMATOCRIT
  , AVG(HEMOGLOBIN) AS HEMOGLOBIN, AVG(LACTATE) AS LACTATE, AVG(MAGNESIUM) AS MAGNESIUM, AVG(PH) AS PH, AVG(PLATELET) AS PLATELET, AVG(POTASSIUM) AS POTASSIUM,
  AVG(PTT) AS PTT, AVG(INR) AS INR, AVG(PT) AS PT, AVG(SODIUM) AS SODIUM, AVG(BUN) AS BUN, AVG(WBC) AS WBC, AVG(PaO2) AS PaO2, AVG(PaCO2) AS PaCO2,
  AVG(SGOT) AS SGOT, AVG(SGPT) AS SGPT, AVG(IonizedCalcium) AS IonizedCalcium
  FROM joined_tables
  GROUP BY stay_id, subject_id, hadm_id, charttime
  ORDER BY stay_id, subject_id, hadm_id, charttime;