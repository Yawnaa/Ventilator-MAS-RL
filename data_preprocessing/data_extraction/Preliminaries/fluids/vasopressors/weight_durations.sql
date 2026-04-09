-- weight_durations.sql (PostgreSQL version)
-- 提取ICU患者体重数据的时间区间，基于 MIMIC-IV chartevents 和 icustays 表
-- 得到的数据：stay_id, starttime, endtime, weight (kg)
-- 处理入院体重和每日体重，填充时间间隔

DROP TABLE IF EXISTS weightdurations;
CREATE TABLE weightdurations AS

WITH wt_stg AS (
    SELECT
        c.stay_id, c.charttime
      , CASE WHEN c.itemid IN (226512,226531) THEN 'admit'
          ELSE 'daily' END AS weight_type
      , CASE WHEN c.itemid IN (226531) THEN c.valuenum * 0.453592
       ELSE c.valuenum
       END AS weight
    FROM chartevents c
    WHERE c.valuenum IS NOT NULL
      AND c.itemid IN (
         762,226512 -- Admit Wt
         ,226531 -- Admit Wt lbs
        ,763,224639 -- Daily Weight
      )
      AND c.valuenum != 0
)
-- assign ascending row number
, wt_stg1 AS (
  SELECT
      stay_id
    , charttime
    , weight_type
    , weight
    , ROW_NUMBER() OVER (PARTITION BY stay_id, weight_type ORDER BY charttime) AS rn
  FROM wt_stg
)
-- change charttime to starttime - for admit weight, we use ICU admission time
, wt_stg2 AS (
  SELECT
      wt_stg1.stay_id
    , ie.intime, ie.outtime
    , CASE WHEN wt_stg1.weight_type = 'admit' AND wt_stg1.rn = 1
        THEN ie.intime - INTERVAL '2' HOUR
      ELSE wt_stg1.charttime END AS starttime
    , wt_stg1.weight
  FROM icustays ie
  INNER JOIN wt_stg1
    ON ie.stay_id = wt_stg1.stay_id
  WHERE NOT (weight_type = 'admit' AND rn = 1)
)
, wt_stg3 AS (
  SELECT
    stay_id
    , starttime
    , COALESCE(
        LEAD(starttime) OVER (PARTITION BY stay_id ORDER BY starttime),
        outtime + INTERVAL '2' HOUR
      ) AS endtime
    , weight
  FROM wt_stg2
)
-- this table is the start/stop times from admit/daily weight in charted data
, wt1 AS (
  SELECT
      ie.stay_id
    , wt.starttime
    , CASE WHEN wt.stay_id IS NULL THEN NULL
      ELSE
        COALESCE(wt.endtime,
        LEAD(wt.starttime) OVER (PARTITION BY ie.stay_id ORDER BY wt.starttime),
          -- we add a 2 hour "fuzziness" window
        ie.outtime + INTERVAL '2' HOUR)
      END AS endtime
    , wt.weight
  FROM icustays ie
  LEFT JOIN wt_stg3 wt
    ON ie.stay_id = wt.stay_id
)
-- if the intime for the patient is < the first charted daily weight
-- then we will have a "gap" at the start of their stay
-- to prevent this, we look for these gaps and backfill the first weight
, wt_fix AS (
  SELECT ie.stay_id
    -- we add a 2 hour "fuzziness" window
    , ie.intime - INTERVAL '2' HOUR AS starttime
    , wt.starttime AS endtime
    , wt.weight
  FROM icustays ie
  INNER JOIN
  -- the below subquery returns one row for each unique stay_id
  -- the row contains: the first starttime and the corresponding weight
  (
    SELECT wt1.stay_id, wt1.starttime, wt1.weight
    FROM wt1
    INNER JOIN
      (
        SELECT stay_id, MIN(starttime) AS starttime
        FROM wt1
        GROUP BY stay_id
      ) wt2
    ON wt1.stay_id = wt2.stay_id
    AND wt1.starttime = wt2.starttime
  ) wt
    ON ie.stay_id = wt.stay_id
    AND ie.intime < wt.starttime
)
, wt2 AS (
  SELECT
      wt1.stay_id
    , wt1.starttime
    , wt1.endtime
    , wt1.weight
  FROM wt1
  UNION ALL
  SELECT
      wt_fix.stay_id
    , wt_fix.starttime
    , wt_fix.endtime
    , wt_fix.weight
  FROM wt_fix
)

SELECT
  wt2.stay_id, wt2.starttime, wt2.endtime, wt2.weight
FROM wt2
ORDER BY stay_id, starttime, endtime;


