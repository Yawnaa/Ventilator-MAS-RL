# Data Extraction

Software: MySQL

Database: MIMIC-IV (https://mimic.mit.edu/docs/iv/)

Our data extraction process involves 3 parts in order:

(1) Preliminaries - Extraction of demographic, fluids and SIRS/SOFA scores for later use

(2) GetSubTables - Combines data into the following subtables: Fluids, LabValues, VentilationParams, VitalSigns

(3) GetFinalTable - Combines the SubTables as well as additional data into one big table and performs required processing


When running the sql scripts, if a subfolder of scripts is present, run the scripts within the subfolder first.

For the getFinalTable, the procedure is done in 4 steps (run the getOverallTable files from 1 to 4 in order).


根据你提供的说明文档和图片中的目录结构，你需要提取 MIMIC-IV 数据库中的数据。这是一个分步进行的数据提取流程，你需要严格按照特定的先后顺序执行这些 SQL 脚本。

以下是具体的执行路线图，以及每个阶段执行后你将得到的结果：

第一阶段：Preliminaries（准备阶段）
根据文档规则：“如果存在子文件夹，请先运行子文件夹中的脚本”。

应该执行哪个 SQL：

首先，进入 Preliminaries/demographics/ 文件夹，执行里面的所有 SQL 脚本。

其次，进入 Preliminaries/fluids/ 文件夹，执行里面的所有 SQL 脚本。

最后，执行 Preliminaries 根目录下的 getSIRS.sql 和 getSOFA.sql。

执行后能得到什么：
你将得到基础的前置数据表。这包括患者的人口统计学信息（年龄、性别等基础特征）、基础的液体出入量记录，以及计算好的 SIRS（全身炎症反应综合征） 和 SOFA（序贯器官衰竭评估） 临床评分。这些基础数据是后续构建完整特征集的基石。

第二阶段：getSubTables（获取子表阶段）
根据文档，这一步需要组合生成各个具体的数据子表。

应该执行哪个 SQL：
执行 getSubTables/ 文件夹下的这四个脚本（通常这四个互不依赖，顺序不限）：

getAllFluids.sql

getAllLabvalues.sql

getAllVentilationParams.sql

getAllVitalSigns.sql

执行后能得到什么：
数据库中将生成四个独立且清洗过的特征子表：

Fluids 表：详细的液体相关特征。

LabValues 表：各项实验室化验指标结果。

VentilationParams 表：详细的呼吸机设置参数（这对后续用于呼吸机参数推荐等强化学习模型的训练至关重要）。

VitalSigns 表：患者的连续生命体征数据（心率、血压等）。

第三阶段：getFinalTable（生成最终总表阶段）
文档中明确指出，对于 getFinalTable，该过程分为 4 个步骤，必须按数字顺序运行。

应该执行哪个 SQL：
严格按照以下顺序执行 getFinalTable/ 文件夹下的脚本：

getOverallTable.sql

getOverallTable2.sql

getOverallTable3.sql

getOverallTable4.sql

执行后能得到什么：
这四个脚本会执行复杂的表连接（JOIN）和最终的数据处理逻辑。执行完毕后，前两个阶段生成的所有前置数据和四大子表将被完美融合，生成一张最终的“大宽表” (Overall Table)。

最终总结： 走完全部流程后，你将获得一个高度结构化、特征对齐的最终多维时间序列数据集。这个最终数据集已经整理好了患者的状态特征（生命体征、化验、评分）和干预动作特征（呼吸机参数、液体），可以直接导出用于后续强化学习模型的数据预处理和算法训练。