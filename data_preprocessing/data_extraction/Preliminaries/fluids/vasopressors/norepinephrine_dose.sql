-- norepinephrine_dose.sql (PostgreSQL version)
-- 提取去甲肾上腺素（Norepinephrine）用药剂量区间，基于 MIMIC-IV inputevents 表
-- 得到的数据：stay_id, starttime, endtime, vaso_rate (最大速率), vaso_amount (总剂量)

DROP TABLE IF EXISTS norepinephrine_dose;
CREATE TABLE norepinephrine_dose AS
WITH vasomv AS (
    SELECT stay_id, linkorderid,
           MAX(rate) AS vaso_rate,
           SUM(amount) AS vaso_amount,
           MIN(starttime) AS starttime,
           MAX(endtime) AS endtime
      FROM inputevents
     WHERE itemid = 221906 -- norepinephrine
       AND statusdescription != 'Rewritten'
     GROUP BY stay_id, linkorderid
)
SELECT stay_id, starttime, endtime, vaso_rate, vaso_amount
  FROM vasomv
 ORDER BY stay_id, starttime;
