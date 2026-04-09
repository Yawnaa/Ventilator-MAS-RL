-- getAllFluids.sql (PostgreSQL version)
-- 合并所有液体相关数据（尿液、血管活性药物、静脉输液、液体平衡），基于 MIMIC-IV 各表
-- 得到的数据：subject_id, hadm_id, stay_id, charttime, urineoutput, rate_norepinephrine, rate_epinephrine, rate_phenylephrine, rate_vasopressin, rate_dopamine, vaso_total, iv_total, cum_fluid_balance

DROP TABLE IF EXISTS getallfluids;
CREATE TABLE getallfluids AS
WITH
UrineOutputTable AS (SELECT subject_id, hadm_id, stay_id, charttime
         , urineoutput
         , CAST(NULL AS DOUBLE PRECISION) AS rate_norepinephrine
         , CAST(NULL AS DOUBLE PRECISION) AS rate_epinephrine
		, CAST(NULL AS DOUBLE PRECISION) AS rate_phenylephrine
		, CAST(NULL AS DOUBLE PRECISION) AS rate_vasopressin
		, CAST(NULL AS DOUBLE PRECISION) AS rate_dopamine
		, CAST(NULL AS DOUBLE PRECISION) AS vaso_total
		, CAST(NULL AS DOUBLE PRECISION) AS iv_total
		, CAST(NULL AS DOUBLE PRECISION) AS cum_fluid_balance
FROM geturineoutput),
VasopressorsTable AS (SELECT ic.subject_id, ic.hadm_id, ic.stay_id, starttime AS charttime
         , CAST(NULL AS DOUBLE PRECISION) AS urineoutput
         , rate_norepinephrine
         , rate_epinephrine
		 , rate_phenylephrine
		 , rate_vasopressin
		, rate_dopamine
		, vaso_total
	 , CAST(NULL AS DOUBLE PRECISION) AS iv_total
	 , CAST(NULL AS DOUBLE PRECISION) AS cum_fluid_balance
FROM getvasopressors vp INNER JOIN icustays ic
ON vp.stay_id = ic.stay_id
),
IntravenousTable AS (SELECT subject_id, hadm_id, stay_id, charttime
         , CAST(NULL AS DOUBLE PRECISION) AS urineoutput
         , CAST(NULL AS DOUBLE PRECISION) AS rate_norepinephrine
         , CAST(NULL AS DOUBLE PRECISION) AS rate_epinephrine
		 , CAST(NULL AS DOUBLE PRECISION) AS rate_phenylephrine
		 , CAST(NULL AS DOUBLE PRECISION) AS rate_vasopressin
		 , CAST(NULL AS DOUBLE PRECISION) AS rate_dopamine
		 , CAST(NULL AS DOUBLE PRECISION) AS vaso_total
		 , amount AS iv_total
		 , CAST(NULL AS DOUBLE PRECISION) AS cum_fluid_balance
FROM getintravenous),

CumFluidTable AS (SELECT subject_id, hadm_id, stay_id, charttime
         , CAST(NULL AS DOUBLE PRECISION) AS urineoutput
         , CAST(NULL AS DOUBLE PRECISION) AS rate_norepinephrine
         , CAST(NULL AS DOUBLE PRECISION) AS rate_epinephrine
		 , CAST(NULL AS DOUBLE PRECISION) AS rate_phenylephrine
		 , CAST(NULL AS DOUBLE PRECISION) AS rate_vasopressin
		 , CAST(NULL AS DOUBLE PRECISION) AS rate_dopamine
		 , CAST(NULL AS DOUBLE PRECISION) AS vaso_total
		 , CAST(NULL AS DOUBLE PRECISION) AS iv_total
		 , cum_fluid_balance
FROM getcumfluid)

(SELECT subject_id, hadm_id, stay_id, charttime,
	 -- urine output
       AVG(urineoutput) AS urineoutput
	 -- vasopressors
	 , AVG(rate_norepinephrine) AS rate_norepinephrine
     , AVG(rate_epinephrine) AS rate_epinephrine
	 , AVG(rate_phenylephrine) AS rate_phenylephrine
     , AVG(rate_vasopressin) AS rate_vasopressin
	 , AVG(rate_dopamine) AS rate_dopamine
     , AVG(vaso_total) AS vaso_total
	 -- intravenous fluids
	 , AVG(iv_total) AS iv_total
	 -- cumulated fluid balance
	 , AVG(cum_fluid_balance) AS cum_fluid_balance
FROM
(SELECT * FROM UrineOutputTable
UNION ALL
  SELECT * FROM VasopressorsTable
UNION ALL
 SELECT * FROM IntravenousTable
UNION ALL
  SELECT * FROM CumFluidTable
) AS allTables

GROUP BY subject_id, hadm_id, stay_id, charttime
ORDER BY subject_id, hadm_id, stay_id, charttime);