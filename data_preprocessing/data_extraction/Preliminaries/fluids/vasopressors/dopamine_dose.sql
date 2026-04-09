-- Initial code was retrieved from https://github.com/MIT-LCP/mimic-code/blob/1754d925ba4e96e376dc29858e8df301fcb69a20/concepts/durations/dopamine-dose.sql
-- Modifications were made when needed for performance improvement, readability or simplification.


-- dopamine_dose.sql (PostgreSQL version)
-- 提取多巴胺（Dopamine）用药剂量区间，基于 MIMIC-IV inputevents 表

DROP TABLE IF EXISTS dopamine_dose;
CREATE TABLE dopamine_dose AS
WITH vasomv AS (
    SELECT stay_id, linkorderid,
           MAX(rate) AS vaso_rate,
           SUM(amount) AS vaso_amount,
           MIN(starttime) AS starttime,
           MAX(endtime) AS endtime
      FROM inputevents
     WHERE itemid = 221662 -- dopamine
       AND statusdescription != 'Rewritten'
     GROUP BY stay_id, linkorderid
)
SELECT stay_id, starttime, endtime, vaso_rate, vaso_amount
  FROM vasomv
 ORDER BY stay_id, starttime;

-- 查看结果
SELECT * FROM dopamine_dose LIMIT 10;