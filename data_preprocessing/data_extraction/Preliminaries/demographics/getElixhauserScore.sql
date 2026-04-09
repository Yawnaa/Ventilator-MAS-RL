-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getElixhauser_score.sql
-- Modifications were made when needed for performance improvement, readability or simplification.

-- This code derives each comorbidity as follows:
--  1) ICD9_CODE is directly compared to 5 character codes
--  2) The first 4 characters of ICD9_CODE are compared to 4 character codes
--  3) The first 3 characters of ICD9_CODE are compared to 3 character codes
-- code retrieved from https://github.com/MIT-LCP/mimic-code/blob/ddd4557423c6b0505be9b53d230863ef1ea78120/concepts/comorbidity/elixhauser-quan.sql

-- ==============================================================================
-- 【全局设置】
-- 设置搜索路径，将你查出来的 mimiciv_hosp 放在首位
-- ==============================================================================
SET search_path TO mimiciv_hosp, mimic_core, public;

-- 清理旧表，防止冲突
DROP TABLE IF EXISTS getElixhauserScore;

-- 创建最终结果表
CREATE TABLE getElixhauserScore AS

-- ==============================================================================
-- 第一阶段：诊断记录预处理 (CTE: icd)
-- 目标：从海量的原始诊断表中提取数据，排除主诊断，并分离 ICD-9 和 ICD-10 编码
-- ==============================================================================
with icd as
(
  select 
    subject_id, -- 患者ID
    hadm_id,    -- 住院ID
    seq_num,    -- 诊断顺序
    
    -- 提取 ICD-10 编码
    Case when icd_version = 10 then icd_code
         when icd_version = 9 then null 
    end as icd10_code,
  
    -- 提取 ICD-9 编码
    Case when icd_version = 9 then icd_code
         when icd_version = 10 then null 
    end as icd9_code
  
  -- ★ 修改完毕：精确指定为你查找到的真实表路径
  from mimiciv_hosp.diagnoses_icd 
  -- 排除 seq_num = 1 的主诊断，因为 Elixhauser 评估的是“并发症”和基础疾病负担
  where seq_num != 1 
)

-- ==============================================================================
-- 第二阶段：疾病字典匹配与打标 (CTE: eliflg)
-- 目标：逐条诊断记录比对，只要匹配上特定的 ICD 编码，就在对应的疾病列标记为 1
-- ==============================================================================
, eliflg as
(
select subject_id, hadm_id, seq_num
, CASE
  when icd9_code in ('39891','40201','40211','40291','40401','40403','40411','40413','40491','40493') then 1
  when icd10_code in ('I0981','I110','I110','I110','I130','I132','I130','I132','I130','I132') then 1
  when SUBSTRING(icd9_code, 1, 4) in ('4254','4255','4257','4258','4259') then 1
  when icd10_code in ('I425','I428','I426','I43','I43','I427') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('428') then 1
  when SUBSTRING(icd10_code, 1, 3) in ('I50') then 1
  else 0 end as CHF       /* 1. 充血性心力衰竭 (Congestive heart failure) */

, CASE
  when icd9_code in ('42613','42610','42612','99601','99604') then 1
  when icd10_code in ('I441','I4430','T82110A','T82111A','T82120A','T82121A','T82190A','T82191A') then 1
  when SUBSTRING(icd9_code, 1, 4) in ('4260','4267','4269','4270','4271','4272','4273','4274','4276','4278','4279','7850','V450','V533') then 1
  when icd10_code in ('I442','I456','I459','I471','I472','I479','I4891','I4892','I4901','I4902','I4940','I491','I493','I4949','I495','R001','I499','R000'
,'Z959','Z950','Z95810','Z95818','Z450110','Z45018','Z4502','Z4509') then 1
  else 0 end as ARRHY     /* 2. 心律失常 (Cardiac arrhythmias) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('0932','7463','7464','7465','7466','V422','V433') then 1
  when icd10_code in ('A5203','Q230','Q231','Q232','Q233','Z953','Z952')then 1
  when SUBSTRING(icd9_code, 1, 3) in ('394','395','396','397','424') then 1
  when icd10_code in('I050','I051','I052','I058','I052','I060','I061','I062','I068','I069','I080','I088','I089',
  'I071','I072','I078','I0989','I091','I340','I348','I360','I368','I378','I370','I38','I39')then 1
  else 0 end as VALVE     /* 3. 瓣膜病 (Valvular disease) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('4150','4151','4170','4178','4179') then 1
  when icd10_code in('I2609','I2690','I2699','T800XXA','T81718A','T8172XA','T82817A','T82818A','I280','I2699','I2692','I2690','I288','I289')then 1
  when SUBSTRING(icd9_code, 1, 3) in ('416') then 1
  when icd10_code in('I270','I271','I2782','I2720','I2721','I27222','I2723','I2724','I2729','I2789','I2781','I279')then 1
  else 0 end as PULMCIRC  /* 4. 肺循环障碍 (Pulmonary circulation disorder) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('0930','4373','4431','4432','4438','4439','4471','5571','5579','V434') then 1
  when icd10_code in('A5201','I671','I731','I7771','I7772','I7773','I7774','I7775','I7776','I7777','I7779','I798','I7381','I7389','I771','K551','Z95828') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('440','441') then 1
  when icd10_code in('I700','I701','I70209','I70219','I70229','I7025','I70269','I70299','I70399','I70499',
            'I70599','I7092','I708','I7090','I7091','I7001','I702','I703','I704','I708','I705','I706','I719')then 1
  else 0 end as PERIVASC  /* 5. 外周血管病 (Peripheral vascular disorder) */

, CASE
  when SUBSTRING(icd9_code, 1, 3) in ('401') then 1
  when icd10_code in('I10','I169') then 1
  else 0 end as HTN       /* 6. 无并发症高血压 (Hypertension, uncomplicated) */

, CASE
  when SUBSTRING(icd9_code, 1, 3) in ('402','403','404','405') then 1
  when icd10_code in('I119','I110','I119','I110','I119','I110','I129','I120','I129','I130','I1310','I132','I1311','I150','I15.8') then 1
  else 0 end as HTNCX     /* 7. 复杂高血压 (Hypertension, complicated) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('3341','3440','3441','3442','3443','3444','3445','3446','3449') then 1
  when icd10_code in  ('G114','G8250','G8251','G8253','G8252','G8254','G8220','G820','G8210','G8211','G8212','G8230',
'G8223','G8224','G8221','G8222','G8220','G8213','G8214','G824','G824','G829') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('342','343') then 1
  -- ★ 已修复原代码报错：补充了 G8114 和 G8190 之间的逗号
  when icd10_code in ('G8100','G8101','G8102','G8103','G8104','G8110','G8111','G8112','G8113','G8114',
 'G8190','G8191','G8192','G8190','G8191','G8193','G8194','G801','G802','G800','G808','G809') then 1
  else 0 end as PARA      /* 8. 瘫痪 (Paralysis) */

, CASE
  when icd9_code in ('33392') then 1
  when icd10_code in ('G210') then 1
  when SUBSTRING(icd9_code, 1, 4) in ('3319','3320','3321','3334','3335','3362','3481','3483','7803','7843') then 1
  when icd10_code in('G319','G20','G2111','G2119','G218','G10','G254','G255','G320','G931','G9340','G9341',
'G9349','I6783','R5600','R5601','R561','R569','R4701') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('334','335','340','341','345') then 1
  when icd10_code in ('G111','G112','G111','G119','G3281','G113','G118','G120','G1225','G129','G121',
'G128','G1221','G1222','G1223','G128','G129','G1224','G1229','G35','G36.0','G370','G375','G373','G373','G371','G372','G378','G373',
'G40A01','G40A09','G40A11','G40A19','G40309','G40410','G40409','G40311','G40411','G40419','G379','G40A01','G40A09','G40A11','G40A19','G40301','G40201','G40209',
'G40101','G40109','G40111','G40119','G40821','G40822','G40823','G40824','G40101','G40109','G40501','G40509','G40802','G40804','G40901','G40909','G40911','G40919'
) then 1
  else 0 end as NEURO     /* 9. 其他神经系统疾病 (Other neurological) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('4168','4169','5064','5081','5088') then 1
  when icd10_code in ('I2720','I2721','I2722','I2723','I2724','I2729','I2789','I2781','I279','J684','J701','J708') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('490','491','492','493','494','495','496','500','501','502','503','504','505') then 1
  when icd10_code in ('J410','J40','J411','J449','J441','J440','J4520','J418','J42','J439','J4522','J4521','J4520',
'J440','J440','J441','J45990','J45991','J45909','J45998','J45902','J45901','J479','J471','J670','J671','J672','J673','J674','J675','J676',
'J677','J678','J679','J449','J60','J61','J628','J630','J631','J632','J633','J634','J635','J635','J636','J660','J661','J662','J668','J64') then 1
  else 0 end as CHRNLUNG  /* 10. 慢性肺病 (Chronic pulmonary disease) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2500','2501','2502','2503') then 1
  when icd10_code in ('E119','E109','E1165','E1065','E1110','E1169','E13.10','E1010','E1165','E1100','E1101','E1069','E11641','E1011',
'E10641','E1101','E1165') then 1
  else 0 end as DM        /* 11. 无并发症糖尿病 (Diabetes w/o chronic complications) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2504','2505','2506','2507','2508','2509') then 1
  when icd10_code in ('E1129','E129','E1121','E1165','E121','E165','E11311','E11319','E1136','E1139','E1311','E1319','E136','E139',
'E1140','E140','E1151','E151','E11618','E11620','E11621','E11622','E11628','E11630','E11638','E11649','E1165','E1169',
'E1618','E1620','E1621','E1622','E1628','E1630','E1638','E1649','E165','E169','E118','E18')  then 1
  else 0 end as DMCX      /* 12. 复杂糖尿病 (Diabetes w/ chronic complications) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2409','2461','2468') then 1
  when icd10_code in ('E012','E049','E071','E034','E0789') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('243','244') then 1
  when icd10_code in ('E009','E890','E032','E018','E038') then 1
  else 0 end as HYPOTHY   /* 13. 甲状腺功能减退 (Hypothyroidism) */

, CASE
  when icd9_code in ('40301','40311','40391','40402','40403','40412','40413','40492','40493') then 1
  when icd9_code  in ('I120','I1311','I132') then 1
  when SUBSTRING(icd9_code, 1, 4) in ('5880','V420','V451') then 1
  when icd10_code in ('N250','Z940','Z992','Z9115') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('585','586','V56') then 1
  when icd10_code  in ('N181','N182','N184','N185','N186','Z4931','N189','N19','Z4901','Z4902','Z4902','Z4931','Z4932','Z4932') then 1
  else 0 end as RENLFAIL  /* 14. 肾衰竭 (Renal failure) */

, CASE
  when icd9_code in ('07022','07023','07032','07033','07044','07054') then 1
  when icd10_code in  ('B181','B180','B181','B180','B182','B182') then 1
  when SUBSTRING(icd9_code, 1, 4) in ('0706','0709','4560','4561','4562','5722','5723','5724','5728','5733','5734','5738','5739','V427') then 1
  when  icd10_code in ('B190','B199','I8501','I8500','I8511','I8510','K7290','K7291','K766','K767','K7210','K7290','K716','K759'
,'K763','K761','K7689','K769','Z944') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('570','571') then 1
  when icd10_code in ('K7200','K762','K700','K7030','K7010','K7030','K709','K739','K730','K75.4','K732','K738',
'K740','K7460','K7469','K743','K744','K745','K760','K7689','K741','K769') then 1
  else 0 end as LIVER     /* 15. 肝病 (Liver disease) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('5317','5319','5327','5329','5337','5339','5347','5349') then 1
  when icd10_code in ('K257','K257','K56699','K259','K259','K56699','K267','K267','K269','K277','K277','K279','K287','K289') then 1
  else 0 end as ULCER     /* 16. 消化性溃疡 (Chronic Peptic ulcer disease) */

, CASE
  when SUBSTRING(icd9_code, 1, 3) in ('042','043','044') then 1
  when icd10_code in ('B20')then 1
  else 0 end as AIDS      /* 17. 艾滋病 (HIV and AIDS) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2030','2386') then 1
  when icd10_code in ('C9000','C9001','C9002','D47Z9') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('200','201','202') then 1
  when icd10_code in ('I10','I169') then 1
  else 0 end as LYMPH     /* 18. 淋巴瘤 (Lymphoma) */

, CASE
  when SUBSTRING(icd9_code, 1, 3) in ('196','197','198','199') then 1
  when icd10_code in ('C770','C771','C772','C774','C775','C778','C7800','C781','C782','C784','C7839','C785',
'C786','C787','C7889','C7900','C7911','C7919','C792','C7931','C7932','C7949','C7951','C7952','C7960','C7970','C7981','C7982','C7989','C800','C801','C802') then 1
  else 0 end as METS      /* 19. 转移癌 (Metastatic cancer) */

, CASE
  when SUBSTRING(icd9_code, 1, 3) in
  (
     '140','141','142','143','144','145','146','147','148','149','150','151','152'
    ,'153','154','155','156','157','158','159','160','161','162','163','164','165'
    ,'166','167','168','169','170','171','172','174','175','176','177','178','179'
    ,'180','181','182','183','184','185','186','187','188','189','190','191','192'
    ,'193','194','195'
  ) then 1
  
  when icd10_code  in (
'C000','C001','C003','C005','C004','C006','C008','C002','C01','C020','C021','C022',
'C023','C028','C024','C028','C029','C07','C080','C081','C089','C030','C039','C031',
'C040','C041','C048','C049','C060','C061','C050','C051','C052','C059','C062','C069',
'C0689','C090','C091','C100','C101','C108','C102','C103','C104','C108','C109','C110',
'C111','C112','C113','C118','C119','C130','C12','C131','C132','C138','C139','C140',
'C142','C148','C153','C154','C155','C153','C154','C155','C158','C159','C164','C163',
'C161','C162','C165','C166','C168','C169','C170','C171','C173','C172','C178','C179',
'C183','C184','C186','C187','C180','C181','C182','C185','C188','C189','C19','C20',
'C211','C210','C218','C220','C222','C227','C228','C221','C229','C23','C240','C241',
'C248','C249','C250','C252','C253','C254','C258','C257','C480','C481','C488','C482',
'C260','C261','C269','C269','C300','C301','C310','C311','C312','C313','C318','C319',
'C320','C321','C322','C323','C328','C33','C3400','C3410','C342','C3430','C3480','C3490',
'C384','C37','C380','C381','C382','C388','C383','C390','C399','C410','C411','C412','C413',
'C4000','C4010','C414','C4020','C4030','C419','C490','C4910','C4920','C493','C494','C49A0',
'C49A1','C49A2','C49A3','C49A4','C49A5','C49A9','C495','C496','C478','C498','C499','C430',
'D030','C4310','D0310','D0311','D0312','C4320','D0320','D0321','D0322','C4330','C4331',
'C4339','D0330','D0339','C434','D034','C4359','D0351','D0352','D0359','C4360','D0360','D0361',
'D0362','C4370','D0370','D0371','D0372','C438','D038','C439','D039','C50019','C50119','C50219',
'C50319','C50419','C50519','C50619','C50819','C50919','C50029','C50929','C460','C461','C462',
'C464','C4650','C463','C467','C469','C55','C530','C531','C538','C539','C58','C541','C542','C543',
'C549','C540','C548','C569','C5700','C5710','C573','C5720','C574','C52','C510','C511','C512',
'C519','C577','C578','C579','C61','C6200','C6210','C6290','C600','C601','C602','C609','C6300',
'C6310','C632','C608','C637','C638','C639','C670','C671','C672','C673','C674','C675','C676',
'C677','C678','C679','C649','C659','C669','C680','C681','C688','C689','C6940','C6960','C6950',
'C6900','C6910','C6920','C6930','C6950','C6980','C6990','C710','C711','C712','C713','C714',
'C715','C716','C717','C718','C719','C7250','C700','C709','C720','C721','C701','C729','C729',
'C73','C7490','C750','C751','C752','C753','C754','C755','C758','C759','C760','C761','C762',
'C763','C7640','C768','C7650') then 1
  else 0 end as TUMOR     /* 20. 实体瘤(无转移) (Solid tumor without metastasis) */

, CASE
  when icd9_code in ('72889','72930') then 1
  when icd10_code in ('M62.89','M79.3') then 1
  when SUBSTRING(icd9_code, 1, 4) in ('7010','7100','7101','7102','7103','7104','7108','7109','7112','7193','7285') then 1
  when icd10_code in ('L900','L943','L940','M3210','M340','M349','M3500','M3501','M3303','M3313','M3390','M3393','M3320','M355','M359','M357') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('446','714','720','725') then 1
  when icd10_code in('M300','M303','M310','M312','M3130','M316','M311','M314','M069',
'M0530','M0560','M061','M0800','M083','M0840','M1200','M0510','M064','M064','M459','M4600','M461','M4980','M4680','M4690','M353') then 1
  else 0 end as ARTH      /* 21. 类风湿关节炎/胶原血管病 (Rheumatoid arthritis) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2871','2873','2874','2875') then 1
  when icd10_code in ('D691','D6949','D693','D6941','D6942','D693','D6949','D6951','D6959','D696')then 1
  when SUBSTRING(icd9_code, 1, 3) in ('286') then 1
  when icd10_code in ('D66','D67','M839','E559','D681','D682','D680','D65','D6832','D684','D688','D689','D68311','D68312','D68318')then 1
  else 0 end as COAG      /* 22. 凝血功能障碍 (Coagulation deficiency) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2780') then 1
  when icd10_code in ('E669','E6601','E663','E662') then 1
  else 0 end as OBESE     /* 23. 肥胖 (Obesity) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('7832','7994') then 1
  when icd10_code in ('R634','R636','R64') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('260','261','262','263') then 1
  when icd10_code in ('I10','I169')  then 1
  else 0 end as WGHTLOSS  /* 24. 体重减轻 (Weight loss) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2536') then 1
  when icd10_code in ('E222') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('276') then 1
  when icd10_code in ('E870','E871','E872','E873','E874','E878','E876','E875','E869','E860','E861','E8771','E8770','E8779') then 1
  else 0 end as LYTES     /* 25. 水和电解质紊乱 (Fluid and electrolyte disorders) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2800') then 1
  when icd10_code in ('D50.0') then 1
  else 0 end as BLDLOSS   /* 26. 失血性贫血 (Blood loss anemia) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2801','2808','2809') then 1
  when icd10_code in ('D501','D508','D509') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('281') then 1
  when icd10_code in ('D510','D511','D513','D518','D520','D521','D528','D529','D531','D530','D532','D538','D539') then 1
  else 0 end as ANEMDEF   /* 27. 缺乏性贫血 (Deficiency anemias) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2652','2911','2912','2913','2915','2918','2919','3030','3039','3050','3575','4255','5353','5710','5711','5712','5713','V113') then 1
  when icd10_code in  ('E52','F1096','F1027','F10951','F10950','F10239','F10182','F10282','F10982','F10159','F10180','F10181',
  'F10188','F10259','F10280','F10281','F10288','F10959','F10980','F1099','F10229','F1020','F1021','F1010','F1011','G621','I426',
  'K2920','K2921','K700','K7010','K7030','K709','Z658') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('980') then 1
  when icd10_code in ('T510X1A','T510X2A','T510X3A','T510X4A','T511X1A','T511X2A','T511X3A','T511X4A'
,'T512X1A','T512X2A','T512X3A','T512X4A','T513X1A','T513X2A','T513X3A','T513X4A','T518X1A','T518X2A','T518X3A','T518X4A'
,'T5191XA','T5192XA','T5193XA','T5194XA') then 1
  else 0 end as ALCOHOL   /* 28. 酒精滥用 (Alcohol abuse) */

, CASE
  when icd9_code in ('V6542') then 1
  when icd10_code in ('Z7141') then 1
  when SUBSTRING(icd9_code, 1, 4) in ('3052','3053','3054','3055','3056','3057','3058','3059') then 1
  when icd10_code in  ('F1210','F1210','F1290','F1211','F1610','F1611','F1310','F1311','F1110','F1111','F1410','F1411',
            'F1510','F1511','F1910','F1911','F1810','F1910','F1811','F1911') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('292','304') then 1
  when icd10_code in ('F19939','F19950','F19951','F15920','F19921','F1997','F1996','F1994','F11182',
'F11282','F11982','F13182','F13282','F13982','F14182','F14282','F14982','F15182','F15282','F15982',
'F19182','F19282','F19982','F11159','F11181','F11188','F11222','F11259','F11281','F11288','F11922',
'F11959','F11981','F12122','F12159','F12180','F12188','F12222','F12259','F12280','F12288','F12922',
'F12959','F12980','F12988','F13159','F13181','F13180','F13188','F13259','F13280','F13281','F13288',
'F13959','F13980','F13981','F13988','F14122','F14159','F14180','F14181','F14188','F14222','F14259',
'F14280','F14281','F14288','F12922','F14959','F14980','F14981','F14988','F15122','F15159','F15180',
'F15181','F15188','F15222','F15259','F15280','F14281','F15288','F15922','F15959','F15980','F15981',
'F15988','F16122','F16159','F16180','F16183','F16188','F16259','F16280','F16283','F16288','F16959',
'F15980','F16983','F16988','17208' ,'17218' ,'17228' ,'17298' ,'F18159','F18180','F18188','F18259',
'F18280','F18288','F18959','F18980','F18988','F19122','F19159','F19180','F19181','F19188','F19222',
'F19259','F19280','F19281','F19288','F19922','F19959','F19980','F19981','F19988','F1999','F1120',
'F1121','F1320','F1321','F1420','F1421','F1220','F1221','F1520','F1521','F1620','F1621','F1920','F1921') then 1
  else 0 end as DRUG      /* 29. 药物滥用 (Drug abuse) */

, CASE
  when icd9_code in ('29604','29614','29644','29654') then 1
  when  icd10_code in ('F302','F302','F312','F315') then 1 
  when SUBSTRING(icd9_code, 1, 4) in ('2938') then 1
  when icd10_code in ('I10','I16.9') then 1
  when SUBSTRING(icd9_code, 1, 3) in ('295','297','298') then 1
  when icd10_code in ('F2089','F201','F202','F200','F2081','F2089','F205','F259','F2089','F209','F22','F23','F24',
            'F32.3','F28','F44.89','F29') then 0
  else 0 end as PSYCH     /* 30. 精神病 (Psychoses) */

, CASE
  when SUBSTRING(icd9_code, 1, 4) in ('2962','2963','2965','3004') then 1
  when icd10_code in ('F329','F320','F321','F322','F323','F324','F325','F339','F330','F331','F332','F333','F3341','F3342',
            'F3130','F3131','F3132','F314','F315','F3175','F3176','F341')then 1
  when SUBSTRING(icd9_code, 1, 3) in ('309','311') then 1
  when icd10_code in ('F4321','F4321','F930','F948','F4322','F4323','F4329','F948','F4324','F4325',
'F4310','F4312','F438','F4320','F329') then 1
  else 0 end as DEPRESS   /* 31. 抑郁症 (Depression) */
from icd
)

-- ==============================================================================
-- 第三阶段：按单次住院聚合 (CTE: eligrp)
-- 目标：将同一患者单次住院(hadm_id)期间的多条诊断记录压缩成一行，提取最大值
-- ==============================================================================
, eligrp as
(
  select hadm_id
  , max(chf) as chf  , max(arrhy) as arrhy  , max(valve) as valve  , max(pulmcirc) as pulmcirc  , max(perivasc) as perivasc  , max(htn) as htn
  , max(htncx) as htncx  , max(para) as para  , max(neuro) as neuro  , max(chrnlung) as chrnlung  , max(dm) as dm  , max(dmcx) as dmcx  , max(hypothy) as hypothy
  , max(renlfail) as renlfail  , max(liver) as liver  , max(ulcer) as ulcer  , max(aids) as aids  , max(lymph) as lymph  , max(mets) as mets  
  , max(tumor) as tumor  , max(arth) as arth  , max(coag) as coag  , max(obese) as obese  , max(wghtloss) as wghtloss  , max(lytes) as lytes
  , max(bldloss) as bldloss  , max(anemdef) as anemdef  , max(alcohol) as alcohol  , max(drug) as drug  , max(psych) as psych  , max(depress) as depress
from eliflg
group by hadm_id
)

-- ==============================================================================
-- 第四阶段：整理疾病等级并关联主表 (CTE: elixhauser_quan)
-- 目标：处理并发症的层级关系（如已有复杂糖尿病，则不算作普通糖尿病），并结合 admissions 表
-- ==============================================================================
, elixhauser_quan as (
select adm.subject_id , adm.hadm_id
, chf as CONGESTIVE_HEART_FAILURE, arrhy as CARDIAC_ARRHYTHMIAS, valve as VALVULAR_DISEASE, pulmcirc as PULMONARY_CIRCULATION, perivasc as PERIPHERAL_VASCULAR
-- 合并“普通高血压”与“复杂高血压”为同一标记
, case
    when htn = 1 then 1
    when htncx = 1 then 1
  else 0 end as HYPERTENSION
, para as PARALYSIS, neuro as OTHER_NEUROLOGICAL, chrnlung as CHRONIC_PULMONARY
-- 仅保留最严重的合并症（如果已有复杂糖尿病，则普通糖尿病记为0）
, case
    when dmcx = 1 then 0
    when dm = 1 then 1
  else 0 end as DIABETES_UNCOMPLICATED
, dmcx as DIABETES_COMPLICATED, hypothy as HYPOTHYROIDISM, renlfail as RENAL_FAILURE
, liver as LIVER_DISEASE, ulcer as PEPTIC_ULCER, aids as AIDS, lymph as LYMPHOMA, mets as METASTATIC_CANCER
-- 仅保留最严重的合并症（如果已转移，则实体瘤记为0）
, case
    when mets = 1 then 0
    when tumor = 1 then 1
  else 0 end as SOLID_TUMOR, arth as RHEUMATOID_ARTHRITIS, coag as COAGULOPATHY, obese as OBESITY, wghtloss as WEIGHT_LOSS, lytes as FLUID_ELECTROLYTE
, bldloss as BLOOD_LOSS_ANEMIA, anemdef as DEFICIENCY_ANEMIAS, alcohol as ALCOHOL_ABUSE, drug as DRUG_ABUSE, psych as PSYCHOSES, depress as DEPRESSION

-- ★ 修改完毕：精确指定为你查找到的真实表路径
from mimiciv_hosp.admissions adm
left join eligrp eli
  on adm.hadm_id = eli.hadm_id
)

-- ==============================================================================
-- 第五阶段：加权计算 Elixhauser 综合评分 (最终计算)
-- 目标：按照三种不同的学术标准权重体系计算得分。
-- ==============================================================================
select subject_id , hadm_id

,  -- 1. van Walraven 评分 (常用于 RL 模型的状态特征集)
   0 * AIDS::int + 0 * ALCOHOL_ABUSE::int +-2 * BLOOD_LOSS_ANEMIA::int + 7 * CONGESTIVE_HEART_FAILURE::int +
   3 * CHRONIC_PULMONARY::int + 3 * COAGULOPATHY::int +-2 * DEFICIENCY_ANEMIAS::int +-3 * DEPRESSION::int + 0 * DIABETES_COMPLICATED::int +
   0 * DIABETES_UNCOMPLICATED::int +-7 * DRUG_ABUSE::int + 5 * FLUID_ELECTROLYTE::int + 0 * HYPERTENSION::int + 0 * HYPOTHYROIDISM::int + 11 * LIVER_DISEASE::int +
   9 * LYMPHOMA::int + 12 * METASTATIC_CANCER::int + 6 * OTHER_NEUROLOGICAL::int + -4 * OBESITY::int + 7 * PARALYSIS::int +2 * PERIPHERAL_VASCULAR::int + 0 * PEPTIC_ULCER::int +
   0 * PSYCHOSES::int + 4 * PULMONARY_CIRCULATION::int + 0 * RHEUMATOID_ARTHRITIS::int + 5 * RENAL_FAILURE::int + 4 * SOLID_TUMOR::int +-1 * VALVULAR_DISEASE::int + 6 * WEIGHT_LOSS::int
as elixhauser_vanwalraven

,  -- 2. 29 项 SID 评分
   0 * AIDS::int + -2 * ALCOHOL_ABUSE::int + -2 * BLOOD_LOSS_ANEMIA::int +
   9 * CONGESTIVE_HEART_FAILURE::int + 3 * CHRONIC_PULMONARY::int + 9 * COAGULOPATHY::int + 0 * DEFICIENCY_ANEMIAS::int +-4 * DEPRESSION::int + 0 * DIABETES_COMPLICATED::int +
  -1 * DIABETES_UNCOMPLICATED::int +-8 * DRUG_ABUSE::int + 9 * FLUID_ELECTROLYTE::int + -1 * HYPERTENSION::int + 0 * HYPOTHYROIDISM::int + 5 * LIVER_DISEASE::int +
   6 * LYMPHOMA::int + 13 * METASTATIC_CANCER::int + 4 * OTHER_NEUROLOGICAL::int + -4 * OBESITY::int +3 * PARALYSIS::int +0 * PEPTIC_ULCER::int +4 * PERIPHERAL_VASCULAR::int +
  -4 * PSYCHOSES::int + 5 * PULMONARY_CIRCULATION::int + 6 * RENAL_FAILURE::int + 0 * RHEUMATOID_ARTHRITIS::int + 8 * SOLID_TUMOR::int + 0 * VALVULAR_DISEASE::int + 8 * WEIGHT_LOSS::int
as elixhauser_SID29

,  -- 3. 30 项 SID 评分
   0 * AIDS::int + 0 * ALCOHOL_ABUSE::int + -3 * BLOOD_LOSS_ANEMIA::int + 8 * CARDIAC_ARRHYTHMIAS::int + 9 * CONGESTIVE_HEART_FAILURE::int + 3 * CHRONIC_PULMONARY::int + 
   12 * COAGULOPATHY::int + 0 * DEFICIENCY_ANEMIAS::int + -5 * DEPRESSION::int + 1 * DIABETES_COMPLICATED::int +  0 * DIABETES_UNCOMPLICATED::int +
  -11 * DRUG_ABUSE::int + 11 * FLUID_ELECTROLYTE::int + -2 * HYPERTENSION::int + 0 * HYPOTHYROIDISM::int +7 * LIVER_DISEASE::int + 8 * LYMPHOMA::int +17 * METASTATIC_CANCER::int + 
   5 * OTHER_NEUROLOGICAL::int +-5 * OBESITY::int +4 * PARALYSIS::int +0 * PEPTIC_ULCER::int + 4 * PERIPHERAL_VASCULAR::int + -6 * PSYCHOSES::int + 
   5 * PULMONARY_CIRCULATION::int + 7 * RENAL_FAILURE::int + 0 * RHEUMATOID_ARTHRITIS::int + 10 * SOLID_TUMOR::int + 0 * VALVULAR_DISEASE::int + 10 * WEIGHT_LOSS::int
as elixhauser_SID30

from elixhauser_quan

order by subject_id , hadm_id ;