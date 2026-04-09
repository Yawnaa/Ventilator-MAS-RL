-- epinephrine_dose.sql (PostgreSQL version)
-- 提取肾上腺素（Epinephrine）用药剂量区间，基于 MIMIC-IV inputevents 表
-- 得到的数据：stay_id, starttime, endtime, vaso_rate (最大速率), vaso_amount (总剂量)

DROP TABLE IF EXISTS epinephrine_dose;
CREATE TABLE epinephrine_dose AS
WITH vasomv AS (
    SELECT stay_id, linkorderid,
           MAX(rate) AS vaso_rate,
           SUM(amount) AS vaso_amount,
           MIN(starttime) AS starttime,
           MAX(endtime) AS endtime
      FROM inputevents
     WHERE itemid = 221289 -- epinephrine
       AND statusdescription != 'Rewritten'
     GROUP BY stay_id, linkorderid
)
SELECT stay_id, starttime, endtime, vaso_rate, vaso_amount
  FROM vasomv
 ORDER BY stay_id, starttime;


