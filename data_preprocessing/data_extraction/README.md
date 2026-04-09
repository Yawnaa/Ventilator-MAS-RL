# Data Extraction

Software: MySQL

Database: MIMIC-IV (https://mimic.mit.edu/docs/iv/)

Our data extraction process involves 3 parts in order:

(1) Preliminaries - Extraction of demographic, fluids and SIRS/SOFA scores for later use

(2) GetSubTables - Combines data into the following subtables: Fluids, LabValues, VentilationParams, VitalSigns

(3) GetFinalTable - Combines the SubTables as well as additional data into one big table and performs required processing


When running the sql scripts, if a subfolder of scripts is present, run the scripts within the subfolder first.

For the getFinalTable, the procedure is done in 4 steps (run the getOverallTable files from 1 to 4 in order).


🗺️ MIMIC-IV 数据提取通关路线图（修正版）
👉 第一步：执行人口统计学基础 (Demographics)
进入 Preliminaries/demographics/ 文件夹。
把你刚才已经改好 PG 语法的 getElixhauserScore.sql、getWeight.sql、getMainDemographics.sql 等脚本全部按顺序执行完。

👉 第二步：执行最深层的血管活性药物 (Vasopressors)
根据“子文件夹优先”规则，进入 Preliminaries/fluids/vasopressors/。
依次执行里面的 6 个脚本：

dopamine_dose.sql

epinephrine_dose.sql

norepinephrine_dose.sql

phenylephrine_dose.sql

vasopressin_dose.sql

weight_durations.sql

👉 第三步：执行上层的输液总表 (Fluids)
退回上一级，进入 Preliminaries/fluids/。
依次执行这 4 个脚本（它们会汇总上一步生成的药物数据）：

getCumFluid.sql

getIntravenous.sql

getUrineOutput.sql

getVasopressors.sql

👉 第四步：生成四大特征子表 (SubTables)
现在所有的前置积木都备齐了。进入 getSubTables/ 文件夹。
依次执行：

getAllFluids.sql

getAllLabvalues.sql

getAllVentilationParams.sql

getAllVitalSigns.sql

👉 第五步：回头补算评分 (SIRS & SOFA)
现在 OverallTable2 终于诞生了！
回到 Preliminaries/ 根目录，执行那两个带有原作者逻辑 Bug 的脚本：

getSIRS.sql（用我刚才发你的修改版）

getSOFA.sql

👉 第六步：开始拼接最终表（只拼一半！）
进入 getFinalTable/ 文件夹。
只执行前两个：

getOverallTable.sql

getOverallTable2.sql


👉 第七步：完成最终大业
回到 getFinalTable/ 文件夹，完成最后的拼接：

getOverallTable3.sql

getOverallTable4.sql

第 1 步：生成所有基础“零件” (SubTables)
进入 getSubTables/ 文件夹，必须先跑完这四个，否则后面的大表（OverallTable）永远建不起来：

执行 getAllVitalSigns.sql

执行 getAllLabvalues.sql

执行 getAllVentilationParams.sql （🌟 就是它！跑完它，你刚才报的第233行错误就会消失）

执行 getAllFluids.sql

第 2 步：组装第一阶段“大表” (OverallTable 1 & 2)
现在零件有了，进入 getFinalTable/ 文件夹：
5.  执行 getOverallTable.sql
6.  执行 getOverallTable2.sql （🌟 跑完它，OverallTable2 就诞生了，SIRS 的报错也就解决了）

第 3 步：回头计算“临床评分” (SIRS & SOFA)
现在 OverallTable2 已经存在了，回到 Preliminaries/ 根目录：
7.  执行 getSIRS.sql
8.  执行 getSOFA.sql

第 4 步：完成最后拼接
最后回到 getFinalTable/ 文件夹：
9.  执行 getOverallTable3.sql
10. 执行 getOverallTable4.sql