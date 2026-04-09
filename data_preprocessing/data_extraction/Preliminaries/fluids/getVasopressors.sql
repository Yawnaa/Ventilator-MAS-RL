-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getVasopressors.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- getVasopressors.sql (PostgreSQL version)
-- 合并所有血管活性药物数据，基于之前创建的各药物剂量表
-- 得到的数据：stay_id, starttime, rate_norepinephrine, rate_epinephrine, rate_phenylephrine, rate_dopamine, rate_vasopressin, vaso_total

DROP TABLE IF EXISTS getVasopressors;
CREATE TABLE getVasopressors AS

WITH vaso_union AS (
SELECT stay_id, starttime,
	vaso_rate AS rate_norepinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_epinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_phenylephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_dopamine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_vasopressin

FROM norepinephrine_dose



UNION ALL

SELECT stay_id, starttime,
	CAST(NULL AS DOUBLE PRECISION) AS rate_norepinephrine,
	vaso_rate AS rate_epinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_phenylephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_dopamine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_vasopressin

FROM epinephrine_dose

UNION ALL

SELECT stay_id, starttime,
	CAST(NULL AS DOUBLE PRECISION) AS rate_norepinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_epinephrine,
	vaso_rate AS rate_phenylephrine,
        CAST(NULL AS DOUBLE PRECISION) AS rate_dopamine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_vasopressin

FROM phenylephrine_dose

UNION ALL

SELECT stay_id, starttime,
	CAST(NULL AS DOUBLE PRECISION) AS rate_norepinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_epinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_phenylephrine,
	vaso_rate AS rate_dopamine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_vasopressin

FROM dopamine_dose

UNION ALL

SELECT stay_id, starttime,
	CAST(NULL AS DOUBLE PRECISION) AS rate_norepinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_epinephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_phenylephrine,
	CAST(NULL AS DOUBLE PRECISION) AS rate_dopamine,
	vaso_rate AS rate_vasopressin

FROM vasopressin_dose
), vaso AS (
SELECT stay_id, starttime,
  -- max command is used to merge different vasopressors taken at the same time into a single row.
	MAX(rate_norepinephrine) AS rate_norepinephrine,
	MAX(rate_epinephrine) AS rate_epinephrine,
	MAX(rate_phenylephrine) AS rate_phenylephrine,
	MAX(rate_dopamine) AS rate_dopamine,
	MAX(rate_vasopressin) AS rate_vasopressin

FROM vaso_union

GROUP BY stay_id, starttime
 )
 SELECT *,
    COALESCE(rate_norepinephrine, 0) + COALESCE(rate_epinephrine, 0) +
	COALESCE(rate_phenylephrine/2.2, 0) + COALESCE(rate_dopamine/100, 0) +
	COALESCE(rate_vasopressin*8.33, 0) AS vaso_total

FROM vaso

ORDER BY stay_id, starttime;
