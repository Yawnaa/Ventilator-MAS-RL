-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getVentilationParams.sql
-- https://github.com/arnepeine/ventai/blob/main/vent_parameters.sql
-- and https://github.com/MIT-LCP/mimic-code/blob/1754d925ba4e96e376dc29858e8df301fcb69a20/concepts/durations/ventilation-durations.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- getAllVentilationParams.sql (PostgreSQL version)
-- 提取呼吸机参数（PEEP、潮气量、高原压），基于 MIMIC-IV chartevents 表
-- 得到的数据：subject_id, hadm_id, stay_id, charttime, fio2_chartevents, MechVent, PEEP, tidal_volume, plateau_pressure

DROP TABLE IF EXISTS data_;
CREATE TABLE data_ AS (
SELECT
  ce.stay_id, ce.subject_id, ce.hadm_id, ce.charttime
    , (CASE WHEN itemid IN (60,437,505,506,686,220339,224700) THEN valuenum ELSE NULL END) AS PEEP
	, (CASE WHEN itemid IN (639, 654, 681, 682, 683, 684,224685,224684,224686) THEN valuenum ELSE NULL END) AS tidal_volume
	, (CASE WHEN itemid IN (224696) THEN valuenum ELSE NULL END) AS plateau_pressure
  FROM chartevents ce
  WHERE ce.value IS NOT NULL AND ce.itemid IN (
	60,437,505,506,686,220339,224700,
	639, 654, 681, 682, 683, 684,224685,224684,224686,
	224696
  )
);

CREATE INDEX data_index_charttime ON data_ (charttime);
CREATE INDEX data_index_stay_id ON data_ (stay_id);
CREATE INDEX data_index_stay_id_charttime ON data_ (stay_id, charttime);

DROP TABLE IF EXISTS ce_vent_param;
CREATE TABLE ce_vent_param AS (
 SELECT ce.subject_id, ce.hadm_id, ce.stay_id, ce.charttime, ce.itemid, data_.tidal_volume, data_.plateau_pressure, data_.PEEP, ce.valuenum, ce.value
   FROM chartevents ce
  LEFT JOIN data_ ON (data_.stay_id = ce.stay_id) AND (data_.charttime = ce.charttime)
  WHERE ce.value IS NOT NULL
);

CREATE INDEX ce_vent_param_index_subject_id_hadm_id_stay_id_charttime
ON ce_vent_param(subject_id, hadm_id, stay_id, charttime);

DROP TABLE IF EXISTS getAllVentilationParams;
CREATE TABLE getAllVentilationParams AS

SELECT subject_id, hadm_id, stay_id, charttime
--  STEP 2: Get the FiO2
    , MAX(
        CASE
          WHEN itemid IN (223835,223769,223770)
            THEN CASE
              WHEN valuenum > 0 AND valuenum <= 1 THEN valuenum * 100
              WHEN valuenum > 1 AND valuenum < 21 THEN NULL
              WHEN valuenum >= 21 AND valuenum <= 100 THEN valuenum
              ELSE NULL END
        WHEN itemid IN (3420, 3422) THEN valuenum
        WHEN itemid = 190 AND valuenum > 0.20 AND valuenum < 1 THEN valuenum * 100
      ELSE NULL END
    ) AS fio2_chartevents
--  STEP 3: Get mechanical ventilation
  , MAX(
    CASE
       WHEN itemid IS NULL OR value IS NULL THEN 0
      WHEN itemid = 720 AND value != 'Other/Remarks' THEN 1
      WHEN itemid = 223848 AND value != 'Other' THEN 1
      WHEN itemid = 223849 THEN 1
      WHEN itemid = 467 AND value = 'Ventilator' THEN 1
      WHEN itemid IN (
        445, 448, 449, 450, 1340, 1486, 1600, 224687,
        639, 654, 681, 682, 683, 684,224685,224684,224686,
        218,436,535,444,459,224697,224695,224696,224746,224747,
        221,1,1211,1655,2000,226873,224738,224419,224750,227187,
        224696,
        5865,5866,224707,224709,224705,224706,
        60,437,505,506,686,220339,224700,
        3459,
        501,502,503,224702,
        223,667,668,669,670,671,672,
        224701
        )
        THEN 1
      ELSE 0
    END
    ) AS MechVent,
    AVG(PEEP) AS PEEP, AVG(tidal_volume) AS tidal_volume, AVG(plateau_pressure) AS plateau_pressure

  FROM ce_vent_param
  GROUP BY subject_id, hadm_id, stay_id, charttime
  ORDER BY subject_id, hadm_id, stay_id, charttime;




select * from ce_vent_param   limit 10;
 


