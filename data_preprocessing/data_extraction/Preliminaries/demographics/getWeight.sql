-- Initial code was retrieved from https://github.com/MIT-LCP/mimic-code/blob/1754d925ba4e96e376dc29858e8df301fcb69a20/concepts/durations/weight-durations.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- Code was modified to be campatible with MIMIC IV.
-- This query extracts weights for adult ICU patients with start/stop times
-- if an admission weight is given, then this is assigned from intime to outtime

-- ==============================================================================
-- 【全局设置】
-- chartevents 和 icustays 都在 mimiciv_icu 模式下
-- ==============================================================================
SET search_path TO mimiciv_icu, mimiciv_hosp, public;

-- 这两句是供你单独查询字典和样本看的，可以独立运行
-- select * from d_items where label like '%weight%';
-- select * from chartevents limit 10;

DROP TABLE IF EXISTS getWeight;

CREATE TABLE getWeight AS

-- ==============================================================================
-- 第一阶段：提取原始体重数据并转换单位 (CTE: wt_stg)
-- 目标：从生命体征事件表(chartevents)中捞出所有体重记录，把磅(lbs)换算成公斤(kg)
-- ==============================================================================
with wt_stg as
(
    SELECT
        c.stay_id, 
        c.charttime,
        -- 判断是入院体重 (admit) 还是日常称重 (daily)
        case when c.itemid in (762, 226512) then 'admit'
             else 'daily' end as weight_type,
        -- 单位换算：如果是 lbs (226531)，乘以 0.453592 转为 kg
        case when c.itemid in (226531) then c.valuenum * 0.453592
             else c.valuenum end as weight
    FROM chartevents c
    WHERE c.valuenum IS NOT NULL
      AND c.itemid in
      (
         762, 226512  -- Admit Wt (入院体重)
        ,226531       -- Admit Wt lbs (入院体重-磅)
        ,763, 224639  -- Daily Weight (日常体重)
      )
      AND c.valuenum != 0
)

-- ==============================================================================
-- 第二阶段：按时间排序打上行号 (CTE: wt_stg1)
-- ==============================================================================
, wt_stg1 as
(
  select
      stay_id
    , charttime
    , weight_type
    , weight
    -- 按照时间先后顺序给每次称重排个号 (1, 2, 3...)
    , ROW_NUMBER() OVER (partition by stay_id, weight_type order by charttime) as rn
  from wt_stg
)

-- ==============================================================================
-- 第三阶段：对齐 ICU 入院时间 (CTE: wt_stg2)
-- 目标：如果有入院体重记录，尝试将其时间提前到刚好入 ICU 之前 (作为基准)
-- ==============================================================================
, wt_stg2 as
(
  select
      wt_stg1.stay_id
    , ie.intime
    , ie.outtime
    -- 如果是第一笔入院体重，把它的生效时间往前推2小时 (覆盖刚入科还没来得及记录的盲区)
    , case when wt_stg1.weight_type = 'admit' and wt_stg1.rn = 1
        then ie.intime - interval '2 hour'
      else wt_stg1.charttime end as starttime
    , wt_stg1.weight
  from icustays ie
  inner join wt_stg1
    on ie.stay_id = wt_stg1.stay_id
  -- 注：这里原代码有一处过滤逻辑，排除了所有入院第一笔记录，保留原样以维持特征分布一致性
  where not (weight_type = 'admit' and rn = 1)
)

-- ==============================================================================
-- 第四阶段：计算每次体重的“有效期” (CTE: wt_stg3)
-- 目标：体重不是一个瞬间值，而是一个状态段。比如1号测了体重，3号才测下一次，那么1-3号都用1号的体重
-- ==============================================================================
, wt_stg3 as
(
  select
    stay_id
    , starttime
    -- 寻找下一次称重的时间 (LEAD函数)，如果没有下一次了，就用出ICU的时间+2小时作为结束
    , coalesce(
        LEAD(starttime) OVER (PARTITION BY stay_id ORDER BY starttime),
        outtime + interval '2 hour'
      ) as endtime
    , weight
  from wt_stg2
)

-- ==============================================================================
-- 第五阶段：关联 ICU 主表，确保数据对齐 (CTE: wt1)
-- ==============================================================================
, wt1 as
(
  select
      ie.stay_id
    , wt.starttime
    , case when wt.stay_id is null then null
      else
        coalesce(wt.endtime,
        LEAD(wt.starttime) OVER (partition by ie.stay_id order by wt.starttime),
          -- 加上两小时的宽容度 (fuzziness window)
        ie.outtime + interval '2 hour')
      end as endtime
    , wt.weight
  from icustays ie
  left join wt_stg3 wt
    on ie.stay_id = wt.stay_id
)

-- ==============================================================================
-- 第六阶段：填补开头的空白期 (Backfill) (CTE: wt_fix)
-- 目标：如果病人在入 ICU 后过了好几个小时才第一次称重，我们要把这第一次体重复用到入 ICU 的那一刻
-- ==============================================================================
, wt_fix as
(
  select ie.stay_id
    -- 把 ICU 入科时间往前推两小时作为开始时间
    , ie.intime - interval '2 hour' as starttime
    , wt.starttime as endtime
    , wt.weight
  from icustays ie
  inner join
  -- 找出每个患者最早的一次体重记录
  (
    select wt1.stay_id, wt1.starttime, wt1.weight
    from wt1
    inner join
      (
        select stay_id, min(Starttime) as starttime
        from wt1
        group by stay_id
      ) wt2
    on wt1.stay_id = wt2.stay_id
    and wt1.starttime = wt2.starttime
  ) wt
    on ie.stay_id = wt.stay_id
    -- 只有当第一次称重时间晚于入ICU时间时，才需要填补前面的空白
    and ie.intime < wt.starttime
)

-- ==============================================================================
-- 第七阶段：将正常记录和填补的空白期合并 (CTE: wt2)
-- ==============================================================================
, wt2 as
(
  select
      wt1.stay_id
    , wt1.starttime
    , wt1.endtime
    , wt1.weight
  from wt1
  UNION ALL
  SELECT
      wt_fix.stay_id
    , wt_fix.starttime
    , wt_fix.endtime
    , wt_fix.weight
  from wt_fix
)

-- ==============================================================================
-- 最终输出：求患者在 ICU 期间的平均体重
-- ==============================================================================
select
  wt2.stay_id,
  ic.subject_id,
  ic.hadm_id, 
  -- 取平均值并保留两位小数，让数据看起来更干净
  ROUND(CAST(AVG(wt2.weight) AS NUMERIC), 2) as weight
from wt2
INNER JOIN icustays ic
  ON wt2.stay_id = ic.stay_id
GROUP BY wt2.stay_id, ic.subject_id, ic.hadm_id
ORDER BY stay_id, subject_id, hadm_id;

-- 验证：看看有多少病人的体重由于完全没有记录而变成了空值 (Null)
-- select count(*) from getWeight where weight is null;