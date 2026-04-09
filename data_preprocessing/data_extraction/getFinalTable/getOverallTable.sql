-- getOverallTable.sql (PostgreSQL version)
-- 合并所有临床数据（生命体征、实验室值、液体、通气参数）创建综合表，基于 MIMIC-IV
-- 初始代码来自 https://github.com/arnepeine/ventai/blob/main/overalltable_Lab_withventparams.sql
-- 和 https://github.com/arnepeine/ventai/blob/main/overalltable_withoutLab_withventparams.sql
-- 进行了修改以兼容 MIMIC-IV，提高性能、可读性或简化

DROP TABLE IF EXISTS overalltable;
CREATE TABLE overalltable AS

SELECT merged.subject_id, hadm_id, stay_id, charttime 
     -- vital signs
	 , avg(gcs) as gcs
     , avg(HeartRate) as HeartRate 
     , avg(SysBP) as SysBP
     , avg(DiasBP) as DiasBP 
     , avg(MeanBP) as MeanBP 
     , avg(SysBP)/avg(HeartRate) as shockindex
     , avg(RespRate) as RespRate
     , avg(TempC) as TempC 
     , avg(SpO2) as SpO2 
	 --  lab values
	 , avg(POTASSIUM) as POTASSIUM 
     , avg(SODIUM) as SODIUM 
     , avg(CHLORIDE) as CHLORIDE 
     , avg(GLUCOSE) as GLUCOSE
	 , avg(BUN) as BUN 
     , avg(CREATININE) as CREATININE 
     , avg(MAGNESIUM) as MAGNESIUM 
     , avg(CALCIUM) as CALCIUM 
     , avg(ionizedcalcium) ionizedcalcium
	 , avg(CARBONDIOXIDE) as CARBONDIOXIDE 
     , avg(SGOT) as SGOT 
     , avg(SGPT) as SGPT 
     , avg(BILIRUBIN) as BILIRUBIN 
     , avg(ALBUMIN) as ALBUMIN 
	 , avg(HEMOGLOBIN) as HEMOGLOBIN 
     , avg(WBC) as WBC 
     , avg(PLATELET) as PLATELET 
     , avg(PTT) as PTT
     , avg(PT) as PT 
     , avg(INR) as INR 
     , avg(PH) as PH 
     , avg(PaO2) as PaO2 
     , avg(PaCO2) as PaCO2
     , avg(BASE_EXCESS) as BASE_EXCESS 
     , avg(BICARBONATE) as BICARBONATE 
     , avg(LACTATE) as LACTATE 
	 --  multiply by 100 because FiO2 is in a % but should be a fraction. This idea is retrieved from https://github.com/MIT-LCP/mimic-code/blob/master/concepts/firstday/blood-gas-first-day-arterial.sql
	 , avg(PaO2)/avg(Fio2)*100 as PaO2FiO2ratio 
	 , avg(BANDS) as BANDS 
	 --  fluids
	 , avg(urineoutput) as urineoutput
     , avg(iv_total) as iv_total
     , avg(cum_fluid_balance) as cum_fluid_balance
	 , avg(rate_norepinephrine) as rate_norepinephrine 
     , avg(rate_epinephrine) as rate_epinephrine 
	 , avg(rate_phenylephrine) as rate_phenylephrine 
     , avg(rate_vasopressin) as rate_vasopressin 
	 , avg(rate_dopamine) as rate_dopamine 
     , avg(vaso_total) as vaso_total
	 --  ventilation parameters
	 , CAST((avg(mechvent)>0) AS DECIMAL) as MechVent
     , avg(FiO2) as FiO2
	 , max(PEEP) as PEEP
     , max(tidal_volume) as tidal_volume
     , max(plateau_pressure) as plateau_pressure

FROM
(
SELECT lab.subject_id, lab.hadm_id, lab.stay_id, lab.charttime
	--  vital signs
	 , CAST(NULL AS DOUBLE PRECISION) as gcs
     , CAST(NULL AS DOUBLE PRECISION) as heartrate
     , CAST(NULL AS DOUBLE PRECISION) as sysbp
     , CAST(NULL AS DOUBLE PRECISION) as diasbp
     , CAST(NULL AS DOUBLE PRECISION) as meanbp
     , CAST(NULL AS DOUBLE PRECISION) as resprate
     , CAST(NULL AS DOUBLE PRECISION) as tempc
     , CAST(NULL AS DOUBLE PRECISION) as spo2 
	--  lab values 
	 , POTASSIUM 
     , SODIUM 
     , CHLORIDE 
     , GLUCOSE 
     , BUN 
     , CREATININE 
     , MAGNESIUM 
     , CALCIUM 
     , CARBONDIOXIDE 
	 , BILIRUBIN 
     , ALBUMIN 
     , HEMOGLOBIN 
     , WBC 
     , PLATELET 
     , PTT 
     , PT 
     , INR 
     , PH 
     , PaO2 
     , PaCO2
     , BASE_EXCESS 
     , BICARBONATE 
     , LACTATE 
     , BANDS
     , SGOT 
     , SGPT 
     , IONIZEDCALCIUM
	--  fluids
	 , CAST(NULL AS DOUBLE PRECISION) as urineoutput, CAST(NULL AS DOUBLE PRECISION) as iv_total, CAST(NULL AS DOUBLE PRECISION) as cum_fluid_balance
	 , CAST(NULL AS DOUBLE PRECISION) as rate_norepinephrine , CAST(NULL AS DOUBLE PRECISION) as rate_epinephrine 
	 , CAST(NULL AS DOUBLE PRECISION) as rate_phenylephrine , CAST(NULL AS DOUBLE PRECISION) as rate_vasopressin 
	 , CAST(NULL AS DOUBLE PRECISION) as rate_dopamine , CAST(NULL AS DOUBLE PRECISION) as vaso_total
	--  ventilation parameters
	 , CAST(NULL AS DECIMAL) as MechVent , CAST(NULL AS DOUBLE PRECISION) as FiO2
	 , CAST(NULL AS DOUBLE PRECISION) as PEEP, CAST(NULL AS DOUBLE PRECISION) as tidal_volume, CAST(NULL AS DOUBLE PRECISION) as plateau_pressure
FROM getalllabvalues lab 
UNION ALL
SELECT subject_id, hadm_id, stay_id, charttime
	 --  vital signs
	 , gcs, heartrate, sysbp, diasbp, meanbp, resprate, tempc, spo2 
	 --  lab values
	 , CAST(NULL AS DOUBLE PRECISION) as POTASSIUM 
     , CAST(NULL AS DOUBLE PRECISION) as SODIUM 
     , CAST(NULL AS DOUBLE PRECISION) as CHLORIDE 
     , CAST(NULL AS DOUBLE PRECISION) as GLUCOSE 
     , CAST(NULL AS DOUBLE PRECISION) as BUN 
     , CAST(NULL AS DOUBLE PRECISION) as CREATININE 
     , CAST(NULL AS DOUBLE PRECISION) as MAGNESIUM 
     , CAST(NULL AS DOUBLE PRECISION) as IONIZEDCALCIUM 
     , CAST(NULL AS DOUBLE PRECISION) as CALCIUM 
     , CAST(NULL AS DOUBLE PRECISION) as CARBONDIOXIDE 
	 , CAST(NULL AS DOUBLE PRECISION) as SGOT 
     , CAST(NULL AS DOUBLE PRECISION) as SGPT 
     , CAST(NULL AS DOUBLE PRECISION) as BILIRUBIN 
     , CAST(NULL AS DOUBLE PRECISION) as ALBUMIN 
     , CAST(NULL AS DOUBLE PRECISION) as HEMOGLOBIN 
     , CAST(NULL AS DOUBLE PRECISION) as WBC 
     , CAST(NULL AS DOUBLE PRECISION) as PLATELET 
     , CAST(NULL AS DOUBLE PRECISION) as PTT 
     , CAST(NULL AS DOUBLE PRECISION) as PT 
     , CAST(NULL AS DOUBLE PRECISION) as INR 
     , CAST(NULL AS DOUBLE PRECISION) as PH 
     , CAST(NULL AS DOUBLE PRECISION) as PaO2 
     , CAST(NULL AS DOUBLE PRECISION) as PaCO2
     , CAST(NULL AS DOUBLE PRECISION) as BASE_EXCESS 
     , CAST(NULL AS DOUBLE PRECISION) as BICARBONATE 
     , CAST(NULL AS DOUBLE PRECISION) as LACTATE 
     , CAST(NULL AS DOUBLE PRECISION) as BANDS
	--  fluids
	 , CAST(NULL AS DOUBLE PRECISION) as urineoutput
     , CAST(NULL AS DOUBLE PRECISION) as iv_total
     , CAST(NULL AS DOUBLE PRECISION) as cum_fluid_balance
	 , CAST(NULL AS DOUBLE PRECISION) as rate_norepinephrine , CAST(NULL AS DOUBLE PRECISION) as rate_epinephrine 
	 , CAST(NULL AS DOUBLE PRECISION) as rate_phenylephrine , CAST(NULL AS DOUBLE PRECISION) as rate_vasopressin 
	 , CAST(NULL AS DOUBLE PRECISION) as rate_dopamine , CAST(NULL AS DOUBLE PRECISION) as vaso_total
	-- ventilation parameters
	 , CAST(NULL AS DECIMAL) as MechVent , CAST(NULL AS DOUBLE PRECISION) as FiO2
	 , CAST(NULL AS DOUBLE PRECISION) as PEEP, CAST(NULL AS DOUBLE PRECISION) as tidal_volume, CAST(NULL AS DOUBLE PRECISION) as plateau_pressure		
FROM getallvitalsigns vit
UNION ALL
SELECT subject_id, hadm_id, stay_id, charttime
	--  vital signs
	 , null as gcs, null as heartrate, null as sysbp, null as diasbp, null as meanbp,  null as resprate, null as tempc, null as spo2 
     -- lab values
	 , CAST(NULL AS DOUBLE PRECISION) as POTASSIUM , CAST(NULL AS DOUBLE PRECISION) as SODIUM , CAST(NULL AS DOUBLE PRECISION) as CHLORIDE , CAST(NULL AS DOUBLE PRECISION) as GLUCOSE , CAST(NULL AS DOUBLE PRECISION) as BUN , CAST(NULL AS DOUBLE PRECISION) as CREATININE , CAST(NULL AS DOUBLE PRECISION) as MAGNESIUM , CAST(NULL AS DOUBLE PRECISION) as IONIZEDCALCIUM , CAST(NULL AS DOUBLE PRECISION) as CALCIUM , CAST(NULL AS DOUBLE PRECISION) as CARBONDIOXIDE 
	 , CAST(NULL AS DOUBLE PRECISION) as SGOT , CAST(NULL AS DOUBLE PRECISION) as SGPT , CAST(NULL AS DOUBLE PRECISION) as BILIRUBIN , CAST(NULL AS DOUBLE PRECISION) as ALBUMIN , CAST(NULL AS DOUBLE PRECISION) as HEMOGLOBIN , CAST(NULL AS DOUBLE PRECISION) as WBC , CAST(NULL AS DOUBLE PRECISION) as PLATELET , CAST(NULL AS DOUBLE PRECISION) as PTT , CAST(NULL AS DOUBLE PRECISION) as PT , CAST(NULL AS DOUBLE PRECISION) as INR , CAST(NULL AS DOUBLE PRECISION) as PH , CAST(NULL AS DOUBLE PRECISION) as PaO2 , CAST(NULL AS DOUBLE PRECISION) as PaCO2
     , CAST(NULL AS DOUBLE PRECISION) as BASE_EXCESS , CAST(NULL AS DOUBLE PRECISION) as BICARBONATE , CAST(NULL AS DOUBLE PRECISION) as LACTATE , CAST(NULL AS DOUBLE PRECISION) as BANDS
	--  fluids
	 , urineoutput
     , iv_total
     , cum_fluid_balance
	 , rate_norepinephrine 
     , rate_epinephrine 
     , rate_phenylephrine 
	 , rate_vasopressin 
     , rate_dopamine 
     , vaso_total
	-- ventilation parameters
	 , CAST(NULL AS DECIMAL) as MechVent 
     , CAST(NULL AS DOUBLE PRECISION) as FiO2
	 , CAST(NULL AS DOUBLE PRECISION) as PEEP
     , CAST(NULL AS DOUBLE PRECISION) as tidal_volume
     , CAST(NULL AS DOUBLE PRECISION) as plateau_pressure
FROM getallfluids fl
UNION ALL
SELECT subject_id, hadm_id, stay_id, charttime
	 --  vital signs
	 , NULL as gcs
     , NULL as heartrate
     , NULL as sysbp
     , NULL as diasbp
     , NULL as meanbp
     , NULL as resprate
     , NULL as tempc
     , NULL as spo2 
	 -- lab values
	 , CAST(NULL AS DOUBLE PRECISION) as POTASSIUM 
     , CAST(NULL AS DOUBLE PRECISION) as SODIUM 
     , CAST(NULL AS DOUBLE PRECISION) as CHLORIDE 
     , CAST(NULL AS DOUBLE PRECISION) as GLUCOSE 
     , CAST(NULL AS DOUBLE PRECISION) as BUN 
     , CAST(NULL AS DOUBLE PRECISION) as CREATININE 
     , CAST(NULL AS DOUBLE PRECISION) as MAGNESIUM 
     , CAST(NULL AS DOUBLE PRECISION) as IONIZEDCALCIUM 
     , CAST(NULL AS DOUBLE PRECISION) as CALCIUM 
     , CAST(NULL AS DOUBLE PRECISION) as CARBONDIOXIDE 
	 , CAST(NULL AS DOUBLE PRECISION) as SGOT 
     , CAST(NULL AS DOUBLE PRECISION) as SGPT 
     , CAST(NULL AS DOUBLE PRECISION) as BILIRUBIN 
     , CAST(NULL AS DOUBLE PRECISION) as ALBUMIN 
     , CAST(NULL AS DOUBLE PRECISION) as HEMOGLOBIN 
     , CAST(NULL AS DOUBLE PRECISION) as WBC 
     , CAST(NULL AS DOUBLE PRECISION) as PLATELET 
     , CAST(NULL AS DOUBLE PRECISION) as PTT 
     , CAST(NULL AS DOUBLE PRECISION) as PT 
     , CAST(NULL AS DOUBLE PRECISION) as INR 
     , CAST(NULL AS DOUBLE PRECISION) as PH 
     , CAST(NULL AS DOUBLE PRECISION) as PaO2 
     , CAST(NULL AS DOUBLE PRECISION) as PaCO2
     , CAST(NULL AS DOUBLE PRECISION) as BASE_EXCESS 
     , CAST(NULL AS DOUBLE PRECISION) as BICARBONATE 
     , CAST(NULL AS DOUBLE PRECISION) as LACTATE 
     , CAST(NULL AS DOUBLE PRECISION) as BANDS
	--  fluids
	 , CAST(NULL AS DOUBLE PRECISION) as urineoutput
     , CAST(NULL AS DOUBLE PRECISION) as iv_total
     , CAST(NULL AS DOUBLE PRECISION) as cum_fluid_balance
	 , CAST(NULL AS DOUBLE PRECISION) as rate_norepinephrine 
     , CAST(NULL AS DOUBLE PRECISION) as rate_epinephrine 
	 , CAST(NULL AS DOUBLE PRECISION) as rate_phenylephrine 
     , CAST(NULL AS DOUBLE PRECISION) as rate_vasopressin 
	 , CAST(NULL AS DOUBLE PRECISION) as rate_dopamine 
     , CAST(NULL AS DOUBLE PRECISION) as vaso_total
	-- ventilation parameters
	 , MechVent 
     , fio2_chartevents as FiO2
	 , PEEP as PEEP
     , tidal_volume as tidal_volume
     , plateau_pressure as plateau_pressure	
FROM getallventilationparams cumflu

) merged 


group by subject_id, hadm_id, stay_id, charttime	
order by subject_id, hadm_id, stay_id, charttime
