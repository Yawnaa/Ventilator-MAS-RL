-- Code was modified to be campatible with MIMIC IV.
-- ==============================================================================
-- 【全局设置】
-- 设置搜索路径，确保能找到相关的模式
-- ==============================================================================
SET search_path TO mimiciv_icu, mimiciv_hosp, public;

-- 清理旧表，防止冲突
DROP TABLE IF EXISTS getMainDemographics;

-- 创建最终结果表
CREATE TABLE getMainDemographics AS

-- ==============================================================================
-- 第一阶段：提取单次入院的基础信息与死亡标签 (CTE: first_admission_time)
-- 目标：计算患者每次入住 ICU 时的精确年龄，并打上各种时间维度的死亡率标签。
-- ==============================================================================
WITH first_admission_time AS
(
  SELECT
      p.subject_id, 
      a.hadm_id, 
      i.stay_id, 
      p.anchor_year, 
      p.gender, 
      p.dod, -- dod: Date of Death (死亡日期)
      
      -- 获取入院时间
      MIN(a.admittime) AS first_admittime,
      
      -- 【修复核心逻辑】：计算患者本次入院时的真实年龄
      -- MIMIC-IV 为了保护隐私，只提供了 anchor_year 和 anchor_age。
      -- 真实年龄 = 锚点年龄 + (本次入院年份 - 锚点年份)
      MIN(ROUND(CAST(EXTRACT(YEAR FROM a.admittime) - p.anchor_year + p.anchor_age AS NUMERIC), 2))
         AS first_admit_age,
         
      -- 1. ICU 内死亡率 (ICUMort)：如果死亡日期在入ICU和出ICU时间之间，记为1
      (CASE WHEN p.dod > i.intime AND p.dod < i.outtime THEN 1 ELSE 0 END) AS ICUMort,
      
      -- 2. 院内死亡率 (HospMort)：直接使用 admissions 表自带的死亡标志
      a.hospital_expire_flag AS HospMort,
      
      -- 3. 28天死亡率：如果死亡日期早于 (入院时间 + 28天)，记为1
      (CASE WHEN p.dod < a.admittime + interval '28 day' THEN 1 ELSE 0 END)  AS HospMort28day,
      
      -- 4. 90天死亡率：如果死亡日期早于 (入院时间 + 90天)，记为1
      (CASE WHEN p.dod < a.admittime + interval '90 day' THEN 1 ELSE 0 END)  AS HospMort90day,
      
      a.dischtime, -- 出院时间
      a.deathtime  -- 死亡具体时间
    
  -- 指定精确的 Schema 路径
  FROM mimiciv_icu.icustays i 
  INNER JOIN mimiciv_hosp.admissions a
    ON a.hadm_id = i.hadm_id
  INNER JOIN mimiciv_hosp.patients p
    ON p.subject_id = i.subject_id
    
  -- 按单次 ICU 记录进行聚合
  GROUP BY 
    p.subject_id, p.anchor_year, p.gender, p.dod, a.admittime, 
    a.hadm_id, a.dischtime, a.deathtime, a.hospital_expire_flag, 
    i.stay_id, i.intime, i.outtime
  ORDER BY p.subject_id
),

-- ==============================================================================
-- 第二阶段：判断患者是否多次进入 ICU (CTE: hos_admissions)
-- 目标：统计该患者的历史记录，如果他的 ICU stay_id 数量大于 1，则打上“重新入院”标签
-- ==============================================================================
hos_admissions as
(
  SELECT 
    subject_id,
    (CASE WHEN COUNT(stay_id) > 1 THEN 1 ELSE 0 END) as ICU_readm
  FROM first_admission_time
  GROUP BY subject_id
)

-- ==============================================================================
-- 第三阶段：拼接所有信息，包括第一步生成的 Elixhauser 评分 (最终 SELECT)
-- ==============================================================================
SELECT
    f.subject_id, 
    f.hadm_id, 
    f.stay_id, 
    f.first_admit_age, 
    f.gender, 
    h.ICU_readm,
    
    -- ★ 关键点：这里去关联了你刚刚第一步千辛万苦跑出来的 Elixhauser 综合分数！
    eli.elixhauser_vanwalraven as elixhauser_score,
    
    -- 输出各种死亡率和时间指标
    f.ICUMort, 
    f.HospMort, 
    f.HospMort28day, 
    f.HospMort90day, 
    f.dischtime, 
    f.deathtime
    
FROM first_admission_time f
INNER JOIN hos_admissions h
  ON f.subject_id = h.subject_id
-- 这里使用 mimiciv_hosp 模式去找你第一步生成的 getElixhauserScore 表
INNER JOIN mimiciv_hosp.getElixhauserScore eli
  ON f.subject_id = eli.subject_id AND f.hadm_id = eli.hadm_id
  
ORDER BY subject_id, hadm_id;

-- 查看生成的最终结果
SELECT * FROM getMainDemographics LIMIT 10;