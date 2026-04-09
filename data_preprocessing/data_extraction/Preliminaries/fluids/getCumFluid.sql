-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getCumFluid.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- getCumFluid.sql (PostgreSQL version)
-- 计算ICU患者的累积液体平衡，基于 MIMIC-IV inputevents 和 outputevents 表
-- 得到的数据：subject_id, hadm_id, stay_id, charttime, in_amount, in_cum_amt, out_amount, out_cum_amt, cum_fluid_balance

DROP TABLE IF EXISTS getCumFluid;
CREATE TABLE getCumFluid AS

SELECT subject_id, hadm_id, stay_id, charttime, in_amount, in_cum_amt, out_amount, out_cum_amt,
       SUM(out_amount) OVER (PARTITION BY in_out.stay_id ORDER BY charttime)
	   - SUM(in_amount) OVER (PARTITION BY in_out.stay_id ORDER BY charttime) AS cum_fluid_balance
FROM (

SELECT subject_id, hadm_id, merged.stay_id, charttime, in_amount,
       SUM(in_amount) OVER (PARTITION BY merged.stay_id ORDER BY charttime) AS in_cum_amt,
	   CAST(NULL AS DOUBLE PRECISION) AS out_amount, CAST(NULL AS DOUBLE PRECISION) AS out_cum_amt
FROM (
	SELECT stay_id, starttime AS charttime,
	-- Some unit conversions that will end up in 'mL'.
	(CASE WHEN amountuom IN ('cc','ml') THEN SUM(amount)
	      WHEN amountuom='L'  THEN SUM(amount)*0.001
	      WHEN amountuom='uL' THEN SUM(amount)*1000  END) AS in_amount
	FROM inputevents inevmv
	WHERE amountuom IN ('L','ml','uL','cc')
	GROUP BY stay_id, charttime, amountuom) AS merged
INNER JOIN icustays ic
ON ic.stay_id = merged.stay_id

UNION ALL

-- Output events.

SELECT subject_id, hadm_id, merged.stay_id, charttime,
       CAST(NULL AS DOUBLE PRECISION) AS in_amount, CAST(NULL AS DOUBLE PRECISION) AS in_cum_amt, out_amount,
       SUM(out_amount) OVER (PARTITION BY merged.stay_id ORDER BY charttime) AS out_cum_amt
FROM (
	SELECT stay_id, charttime, SUM(value) AS out_amount
	FROM outputevents outev
	WHERE valueuom IN ('mL','ml')
	GROUP BY stay_id, charttime) AS merged
INNER JOIN icustays ic
ON ic.stay_id = merged.stay_id
	) AS in_out

ORDER BY stay_id, charttime;
