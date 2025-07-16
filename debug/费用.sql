SELECT * FROM 费用发生额

SELECT DISTINCT 功能范围 FROM 费用发生额

--销售费用
--管理费用
--研发费用
--制造费用

SELECT generate_series(1, 10) AS 公司代码货币价值序列;

WITH months AS (
  SELECT generate_series(1, 12) AS 月份
)
-- 你的其他CTE
SELECT * FROM months;

SELECT CONCAT(CAST(UNNEST(generate_series(1, 12))AS VARCHAR),'月') AS 月份;



--费用
WITH t1 AS 
(
SELECT 总账科目名称,公司代码货币价值,
CASE WHEN CAST(记帐期间 AS int)>12 THEN '13期调整' ELSE  concat(CAST(CAST(记帐期间 AS int) AS VARCHAR),'月') END AS 期间_adj
FROM 费用发生额
WHERE 功能范围='管理费用'
UNION ALL 
SELECT 'temp' AS 总账科目名称,0 AS 公司代码货币价值,CONCAT(CAST(UNNEST(generate_series(1, 12))AS VARCHAR),'月') 期间_adj
UNION ALL 
SELECT 'temp' AS 总账科目名称,0 AS 公司代码货币价值,'13期调整' 期间_adj
),
t2 AS 
(
PIVOT t1
ON 期间_adj
USING sum(公司代码货币价值)
GROUP BY 总账科目名称
)
SELECT 
row_number() over(ORDER BY 总账科目名称 ASC) 序号,
总账科目名称 AS "SAP原始总账科目：短文本",
"1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月","13期调整"
FROM t2
WHERE 总账科目名称!='temp'
ORDER BY 总账科目名称 ASC

--财务费用
WITH t1 AS 
(
SELECT 
科目代码,
科目名称,
sum(本位货币期末) 发生额
FROM 科目余额表
WHERE 科目名称 LIKE '%财务费用%'
GROUP BY 科目代码,科目名称
),
t2 AS
(
SELECT 
CASE 
WHEN 科目代码 IN ('66030030','66030010') THEN '1'
WHEN 科目代码 IN ('66030070') THEN '2'
WHEN 科目代码 IN ('66038900') THEN '3'
WHEN 科目代码 IN ('66030090') THEN '4'
ELSE 科目名称 END AS 序号,
CASE 
WHEN 科目代码 IN ('66030030','66030010') THEN '利息支出'
WHEN 科目代码 IN ('66030070') THEN '减：利息收入'
WHEN 科目代码 IN ('66038900') THEN '汇兑损益'
WHEN 科目代码 IN ('66030090') THEN '其他'
ELSE 科目代码 END AS 一级科目,
CASE 
WHEN 科目代码 IN ('66030030') THEN '票据贴息'
WHEN 科目代码 IN ('66030010') THEN '银行贷款 or 企业借款'
WHEN 科目代码 IN ('66030070') THEN '金融机构存款 or 企业借款'
WHEN 科目代码 IN ('66038900') THEN '金额'
WHEN 科目代码 IN ('66030090') THEN '手续费'
ELSE 科目名称 END AS 二级科目,
sum(发生额) 未审数合计_temp
FROM t1
GROUP BY 序号,一级科目,二级科目
)
SELECT 序号,一级科目,二级科目,CASE WHEN 序号=2 THEN -1*未审数合计_temp ELSE 未审数合计_temp END 未审数合计,
sum(未审数合计_temp) over() 合计
FROM t2
ORDER BY 序号