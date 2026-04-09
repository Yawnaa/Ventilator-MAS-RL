-- getOverallTable2.sql (PostgreSQL version)
-- 按 4 小时分辨率对 OverallTable 中的数据进行采样，基于 MIMIC-IV
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/sampling_lab_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化

-- 此代码使用 4 小时的分辨率对"overalltable"表中的数据进行采样

-- 创建用于生成时间序列的数字表 (0-4000)
DROP TABLE IF EXISTS numbers CASCADE;

CREATE TABLE numbers (n INT);

-- PostgreSQL 函数替代 MySQL 存储过程：生成序列数字 0-4000
-- 用于时间间隔生成
WITH RECURSIVE seq AS (
  SELECT 0 as n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 4000
)
INSERT INTO numbers (n) SELECT n FROM seq;

-- 创建 grid 表：生成采样时间点
DROP TABLE IF EXISTS grid CASCADE;

CREATE TABLE grid AS
WITH minmax AS (
  SELECT subject_id, hadm_id, stay_id, min(charttime) as mint, max(charttime) as maxt
  FROM overalltable
  GROUP BY stay_id, subject_id, hadm_id
  ORDER BY stay_id, subject_id, hadm_id
)
SELECT
    stay_id,
    subject_id,
    hadm_id,
    CAST(mint + (INTERVAL '4' HOUR) * numbers.n AS TIMESTAMP) AS start_time
FROM minmax JOIN numbers
ON (mint + (INTERVAL '4' HOUR) * numbers.n) <= maxt;

-- 创建 OverallTable2：从 grid 和 overalltable 进行最近邻插值
DROP TABLE IF EXISTS overalltable2 CASCADE;

CREATE TABLE overalltable2 AS
SELECT
    gr.stay_id,
    gr.subject_id,
    gr.hadm_id,
    gr.start_time,
    -- 选择与 gr.start_time 最接近的 overalltable 行
    (array_agg(ot.gcs ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as gcs,
    (array_agg(ot.heartrate ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as heartrate,
    (array_agg(ot.sysbp ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as sysbp,
    (array_agg(ot.diasbp ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as diasbp,
    (array_agg(ot.meanbp ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as meanbp,
    (array_agg(ot.shockindex ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as shockindex,
    (array_agg(ot.resprate ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as resprate,
    (array_agg(ot.tempc ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as tempc,
    (array_agg(ot.spo2 ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as spo2,
    (array_agg(ot.potassium ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as potassium,
    (array_agg(ot.sodium ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as sodium,
    (array_agg(ot.chloride ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as chloride,
    (array_agg(ot.glucose ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as glucose,
    (array_agg(ot.bun ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as bun,
    (array_agg(ot.creatinine ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as creatinine,
    (array_agg(ot.magnesium ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as magnesium,
    (array_agg(ot.calcium ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as calcium,
    (array_agg(ot.ionizedcalcium ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as ionizedcalcium,
    (array_agg(ot.carbondioxide ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as carbondioxide,
    (array_agg(ot.sgot ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as sgot,
    (array_agg(ot.sgpt ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as sgpt,
    (array_agg(ot.bilirubin ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as bilirubin,
    (array_agg(ot.albumin ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as albumin,
    (array_agg(ot.hemoglobin ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as hemoglobin,
    (array_agg(ot.wbc ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as wbc,
    (array_agg(ot.platelet ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as platelet,
    (array_agg(ot.ptt ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as ptt,
    (array_agg(ot.pt ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as pt,
    (array_agg(ot.inr ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as inr,
    (array_agg(ot.ph ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as ph,
    (array_agg(ot.pao2 ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as pao2,
    (array_agg(ot.paco2 ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as paco2,
    (array_agg(ot.base_excess ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as base_excess,
    (array_agg(ot.bicarbonate ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as bicarbonate,
    (array_agg(ot.lactate ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as lactate,
    (array_agg(ot.pao2fio2ratio ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as pao2fio2ratio,
    (array_agg(ot.bands ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as bands,
    (array_agg(ot.mechvent ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as mechvent,
    (array_agg(ot.fio2 ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as fio2,
    (array_agg(ot.urineoutput ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as urineoutput,
    (array_agg(ot.vaso_total ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as vaso_total,
    (array_agg(ot.iv_total ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as iv_total,
    (array_agg(ot.cum_fluid_balance ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as cum_fluid_balance,
    (array_agg(ot.peep ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as peep,
    (array_agg(ot.tidal_volume ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as tidal_volume,
    (array_agg(ot.plateau_pressure ORDER BY ABS(EXTRACT(EPOCH FROM (ot.charttime - gr.start_time)))))[1] as plateau_pressure
FROM grid gr
LEFT JOIN overalltable ot ON gr.stay_id = ot.stay_id
  AND ot.charttime <= gr.start_time
GROUP BY gr.stay_id, gr.subject_id, gr.hadm_id, gr.start_time
ORDER BY gr.stay_id, gr.subject_id, gr.hadm_id, gr.start_time;
ORDER BY
    stay_id, subject_id, hadm_id, start_time;



select count(*) from grid;

CREATE INDEX grid_index_stay_id ON grid (stay_id);
CREATE INDEX grid_index_subject_id ON grid (subject_id);
CREATE INDEX grid_index_hadm_id ON grid (hadm_id);
CREATE INDEX grid_index_start_time ON grid(start_time);




CREATE INDEX OverallTable_index_stay_id2 ON OverallTable(stay_id);
CREATE INDEX OverallTable_index_subject_id2 ON OverallTable (subject_id);
CREATE INDEX OverallTable_index_hadm_id2 ON OverallTable (hadm_id);
CREATE INDEX OverallTable_index_start_time2 ON OverallTable(charttime);



DROP table IF EXISTS `OverallTable2`;
CREATE table `OverallTable2` as
	
SELECT ot.stay_id, ot.subject_id, ot.hadm_id, start_time
     , round(avg(gcs)) as gcs , avg(heartrate) as heartrate , avg(sysbp) as sysbp , avg(diasbp) as diasbp , avg(meanbp) as meanbp
	 , avg(shockindex) as shockindex, avg(RespRate) as RespRate
     , avg(TempC) as TempC , avg(SpO2) as SpO2 
	 -- lab values
	 , avg(POTASSIUM) as POTASSIUM , avg(SODIUM) as SODIUM , avg(CHLORIDE) as CHLORIDE , avg(GLUCOSE) as GLUCOSE
	 , avg(BUN) as BUN , avg(CREATININE) as CREATININE , avg(MAGNESIUM) as MAGNESIUM , avg(CALCIUM) as CALCIUM , avg(ionizedcalcium) ionizedcalcium
	 , avg(CARBONDIOXIDE) as CARBONDIOXIDE , avg(SGOT) as SGOT , avg(SGPT) as SGPT, avg(BILIRUBIN) as BILIRUBIN , avg(ALBUMIN) as ALBUMIN 
	 , avg(HEMOGLOBIN) as HEMOGLOBIN , avg(WBC) as WBC , avg(PLATELET) as PLATELET , avg(PTT) as PTT
     , avg(PT) as PT , avg(INR) as INR , avg(PH) as PH , avg(PaO2) as PaO2 , avg(PaCO2) as PaCO2
     , avg(BASE_EXCESS) as BASE_EXCESS , avg(BICARBONATE) as BICARBONATE , avg(LACTATE) as LACTATE 
	 ,avg(pao2fio2ratio) as pao2fio2ratio, avg(BANDS) as BANDS --  this is only included in order to calculate SIRS score
	 -- ventilation parameters
	 , CAST(avg(mechvent)>0 AS DECIMAL) as MechVent -- as long as at least one flag is 1 at the timepoint make overall as 1
	 , avg(FiO2) as FiO2
	 -- urine output
	 , sum(urineoutput) as urineoutput
	 --  vasopressors
	 , max(rate_norepinephrine) as rate_norepinephrine , max(rate_epinephrine) as rate_epinephrine 
	 , max(rate_phenylephrine) as rate_phenylephrine , max(rate_vasopressin) as rate_vasopressin 
	 , max(rate_dopamine) as rate_dopamine , max(vaso_total) as vaso_total
	 --  intravenous fluids
	 , sum(iv_total) as iv_total
	 --  cumulative fluid balance
	 , avg(cum_fluid_balance) as cum_fluid_balance
	 --  ventilation parameters
	 , max(PEEP) as PEEP, max(tidal_volume) as tidal_volume, max(plateau_pressure) as plateau_pressure
FROM grid g
LEFT JOIN `OverallTable` ot ON ot.charttime >= g.start_time
				   AND ot.charttime <  DATE_ADD(g.start_time, INTERVAL 4 hour)
				   AND ot.stay_id=g.stay_id
				   AND ot.subject_id=g.subject_id
				   AND ot.hadm_id=g.hadm_id

GROUP  BY ot.stay_id,ot.subject_id, ot.hadm_id, start_time
ORDER  BY stay_id,subject_id, hadm_id, start_time;
