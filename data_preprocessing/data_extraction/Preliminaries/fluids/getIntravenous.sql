-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getIntravenous.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- getIntravenous.sql (PostgreSQL version)
-- 提取静脉输液数据，基于 MIMIC-IV inputevents 表
-- 得到的数据：subject_id, hadm_id, stay_id, charttime, amount (平均总剂量)

DROP TABLE IF EXISTS getIntravenous;
CREATE TABLE getIntravenous AS

WITH intra AS (SELECT *
FROM inputevents
WHERE ordercategoryname IN ('03-IV Fluid Bolus','02-Fluids (Crystalloids)','04-Fluids (Colloids)','07-Blood Products')
	OR secondaryordercategoryname IN ('03-IV Fluid Bolus','02-Fluids (Crystalloids)','04-Fluids (Colloids)','07-Blood Products')
 )

SELECT subject_id, hadm_id, stay_id, starttime AS charttime
	 , AVG(totalamount) AS amount
FROM intra

GROUP BY subject_id, hadm_id, stay_id, charttime
ORDER BY subject_id, hadm_id, stay_id, charttime;
