-- Code retrieved from https://github.com/MIT-LCP/mimic-code/blob/master/concepts/demographics/HeightWeightQuery.sql
-- Code was modified to be campatible with MIMIC IV.

-- Modifications were made when needed for performance improvement, readability or simplification.

-- ==============================================================================
-- 【全局设置】
-- chartevents 在 icu 模式下，patients 在 hosp 模式下
-- ==============================================================================
SET search_path TO mimiciv_icu, mimiciv_hosp, public;

DROP TABLE IF EXISTS idealbodyweight;

CREATE TABLE idealbodyweight AS

-- ==============================================================================
-- 第一阶段：提取原始数据并统一单位 (CTE: FirstVRawData)
-- ==============================================================================
WITH FirstVRawData AS
  (SELECT 
    c.charttime,
    c.itemid,
    c.subject_id,
    c.stay_id,
    
    -- 1. 给不同的 itemid 打上 'WEIGHT' (体重) 或 'HEIGHT' (身高) 的标签
    CASE
      WHEN c.itemid IN (762, 763, 3723, 3580, 3581, 3582, 226512) 
        THEN 'WEIGHT'
      WHEN c.itemid IN (920, 1394, 4187, 3486, 3485, 4188, 226707) 
        THEN 'HEIGHT'
    END AS parameter,
    
    -- 2. 统一单位：将所有的磅(lbs)/盎司(oz)转为公斤(kg)，英寸(inches)转为厘米(cm)
    CASE
      WHEN c.itemid IN (3581, 226531) THEN c.valuenum * 0.45359237      -- 磅转公斤
      WHEN c.itemid IN (3582)         THEN c.valuenum * 0.0283495231    -- 盎司转公斤
      WHEN c.itemid IN (920, 1394, 4187, 3486, 226707) THEN c.valuenum * 2.54 -- 英寸转厘米
      ELSE c.valuenum
    END AS valuenum
    
  FROM chartevents c
  WHERE c.valuenum IS NOT NULL
  -- 排除被护士标记为错误的记录
  AND c.warning != 1
  -- 限定只查询身高和体重的 itemid
  AND ( ( c.itemid IN (762, 763, 3723, 3580, 3581, 3582, 920, 1394, 4187, 3486, 3485, 4188, 226707, 226512)
  AND c.valuenum <> 0 )
    ) )

-- ==============================================================================
-- 第二阶段：提取单次 ICU 住院的最大、最小和首个记录值 (CTE: SingleParameters)
-- ==============================================================================
, SingleParameters AS (
  SELECT DISTINCT 
         subject_id,
         stay_id,
         parameter,
         -- 使用窗口函数提取排序后的第一个值（入院首个记录）
         first_value(valuenum) over
            (partition BY subject_id, stay_id, parameter
             order by charttime ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
             AS first_valuenum,
         -- 提取最小值
         MIN(valuenum) over
            (partition BY subject_id, stay_id, parameter
             order by charttime ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
             AS min_valuenum,
         -- 提取最大值
         MAX(valuenum) over
            (partition BY subject_id, stay_id, parameter
             order by charttime ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
             AS max_valuenum
    FROM FirstVRawData
  )

-- ==============================================================================
-- 第三阶段：行转列 (Pivot) - 将数据压平 (CTE: PivotParameters)
-- ==============================================================================
, PivotParameters AS (
  SELECT 
    subject_id, 
    stay_id,
    -- 把 HEIGHT 和 WEIGHT 两行数据，展开变成宽表里的列
    MAX(case when parameter = 'HEIGHT' then first_valuenum else NULL end) AS height_first,
    MAX(case when parameter = 'HEIGHT' then min_valuenum else NULL end)   AS height_min,
    MAX(case when parameter = 'HEIGHT' then max_valuenum else NULL end)   AS height_max,
    MAX(case when parameter = 'WEIGHT' then first_valuenum else NULL end) AS weight_first,
    MAX(case when parameter = 'WEIGHT' then min_valuenum else NULL end)   AS weight_min,
    MAX(case when parameter = 'WEIGHT' then max_valuenum else NULL end)   AS weight_max
  FROM SingleParameters
  GROUP BY subject_id, stay_id
  )

-- ==============================================================================
-- 第四阶段：关联性别并套用公式计算理想体重 (CTE: ideal_weight_tmp)
-- ==============================================================================
, ideal_weight_tmp as
  (
SELECT 
  f.stay_id,
  f.subject_id,
  pat.gender,
  ROUND(cast(f.height_first as numeric), 2) AS height_first,
  ROUND(cast(f.height_min as numeric), 2)   AS height_min,
  ROUND(cast(f.height_max as numeric), 2)   AS height_max,
  ROUND(cast(f.weight_first as numeric), 2) AS weight_first,
  ROUND(cast(f.weight_min as numeric), 2)   AS weight_min,
  ROUND(cast(f.weight_max as numeric), 2)   AS weight_max,
  
  -- 理想体重公式 (Devine Formula): 
  -- 男性 = 50kg + 2.3kg * (身高超过 5英尺 的英寸数)
  -- 女性 = 45.5kg + 2.3kg * (身高超过 5英尺 的英寸数)
  (CASE 
    when gender='M' then 50 + (f.height_first/100*3.28-5)*12*2.3
    when gender='F' then 45.5 + (f.height_first/100*3.28-5)*12*2.3 
   end) as ideal_body_weight_kg

FROM PivotParameters f
-- 连接 patients 表获取性别
LEFT JOIN patients pat
ON f.subject_id = pat.subject_id
    )

-- ==============================================================================
-- 最终输出：处理缺失值并生成最终表
-- ==============================================================================
SELECT 
  stay_id,
  subject_id,
  gender,
  height_first,
  height_min,
  height_max,
  weight_first,
  weight_min,
  weight_max,
  
  -- 如果由于缺少身高数据导致理想体重无法计算（或算出来是负数），
  -- 则直接用患者首次称重体重的 82% 作为估算替代值。
  -- (0.82 是通过大规模统计得到的 理想体重/实际体重 的平均比率)
  (CASE 
    WHEN ideal_body_weight_kg IS NULL OR ideal_body_weight_kg < 0 
      THEN weight_first * 0.82
    ELSE ideal_body_weight_kg 
  END) as ideal_body_weight_kg
  
FROM ideal_weight_tmp
ORDER BY stay_id, subject_id;



