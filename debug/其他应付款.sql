

--CREATE OR REPLACE VIEW "其他应付明细表" AS
WITH t1 AS --其他应付oap期末余额 
(
SELECT * FROM 
(
select 客商代码 编码,客商名称 供应商名称,原币符号 币种,科目名称,科目代码,
-sum(本位币余额) 期末余额,
-sum(原币余额) 期末余额_原币 
from 往来余额
where left(科目代码,4)='2241' and 期间_add='this' 
group by 客商代码,客商名称,原币符号,科目名称,科目代码
)t WHERE 期末余额!=0
),
t2 as --其他应付oap期初余额
(
SELECT * FROM 
(
select 客商代码 编码,客商名称 供应商名称,原币符号 币种,科目名称,科目代码,
-sum(本位币余额) 期末余额,
-sum(原币余额) 期末余额_原币
from 往来余额
where left(科目代码,4)='2241' and 期间_add='last' 
group by 客商代码,客商名称,原币符号,科目名称,科目代码
)t WHERE 期末余额!=0
),
t3 as --其他应收oar 期末余额 期末负数需要重分类到其他应付
(
	SELECT * FROM 
	(
	select 客商代码 编码,客商名称 供应商名称,原币符号 币种,科目名称,科目代码,
	sum(本位币余额) 期末余额,
	sum(原币余额) 期末余额_原币
	from 往来余额
	where left(科目代码,4)='1231' and 期间_add='this' 
	group by 客商代码,客商名称,原币符号,科目名称,科目代码
	)t WHERE 期末余额!=0
),
t4 as --其他应收oar 期初余额
(
	SELECT * FROM 
	(
	select 客商代码 编码,客商名称 供应商名称,原币符号 币种,科目名称,科目代码,
	sum(本位币余额) 期末余额,
	sum(原币余额) 期末余额_原币
	from 往来余额
	where left(科目代码,4)='1231' and 期间_add='last' 
	group by 客商代码,客商名称,原币符号,科目名称,科目代码
	)t WHERE 期末余额!=0
),
t5 as --外币评估清单 其他应付 其他应收
(
select 账户 编码,货币 币种,-sum(记帐金额) 汇率调整 
from 外币评估清单
where left(总帐帐目,4) in ('1231','2241') --其他应付、其他应收
group by 账户,货币
),
oap_balance as --其他应付 期初+期末 + 其他应收重分类
(
	select 
	coalesce(a.编码,b.编码) 编码,
	coalesce(a.供应商名称,b.供应商名称) 供应商名称,
	coalesce(a.币种,b.币种) 币种,
	coalesce(a.期末余额,0) 期初余额,
	coalesce(b.期末余额,0) 期末余额,
	coalesce(b.期末余额_原币,0) 期末余额_原币,
	coalesce(a.科目名称,b.科目名称) 科目名称,
	coalesce(a.科目代码,b.科目代码) 科目代码,
	from t2 as a --期初余额
	full join t1 as b --期末余额
	on a.编码=b.编码 and a.币种=b.币种 and a.科目代码=b.科目代码
),
oar_balance AS --其他应收 期初+期末 + 其他应收重分类
(
	select 
	coalesce(a.编码,b.编码) 编码,
	coalesce(a.供应商名称,b.供应商名称) 供应商名称,
	coalesce(a.币种,b.币种) 币种,
	coalesce(a.期末余额,0) 期初余额,
	coalesce(b.期末余额,0) 期末余额,
	coalesce(b.期末余额_原币,0) 期末余额_原币,
	coalesce(a.科目名称,b.科目名称) 科目名称,
	coalesce(a.科目代码,b.科目代码) 科目代码,
	from t4 AS a --期初余额
	full join t3 AS b--期末余额
	on a.编码=b.编码 and a.币种=b.币种 and a.科目代码=b.科目代码
),
occur AS --发生额 对于其他应付 负数表示本期增加-贷方 
(
SELECT * FROM 
	(
	SELECT 
	客商代码 编码,客商名称,原币符号 币种,借贷标识,科目代码,科目名称,
	case when left(科目代码,4) IN ('1231') then '其他应收' else '其他应付' end 科目,
	sum(本位币金额) 发生额
	FROM 往来发生额 a
	LEFT JOIN 
	(
	SELECT * FROM 
	(
	SELECT 凭证编号,sum(本位币金额)  凭证金额
	FROM 往来发生额
	WHERE LEFT(科目代码,4) IN ('1231','2241') AND 凭证类型='SA'
	GROUP BY 凭证编号
	)temp
	WHERE 凭证金额=0)b --筛选SA凭证号汇总金额为0的
	ON a.凭证编号=b.凭证编号 
	WHERE b.凭证编号 IS NULL  --剔除SA 清账凭证
	AND LEFT(科目代码,4) IN ('1231','2241')
	GROUP BY 客商代码,客商名称,原币符号,借贷标识,科目代码,科目名称,
	case when left(科目代码,4) IN ('1231') then '其他应收' else '其他应付' END
	)temp2
WHERE (科目='其他应收' AND 借贷标识='S') OR (科目='其他应付' AND 借贷标识='H')  
),
oap_detail AS 
(
	SELECT 编码,供应商名称,币种,期初余额,
	期初余额+本期增加-期末余额 as 本期借方,
	本期增加 AS 本期贷方,
	期末余额,期末余额_原币,科目名称,科目代码
	FROM 
	(
	SELECT 
	COALESCE(a.编码,b.编码) 编码,
	COALESCE(a.供应商名称,b.客商名称) 供应商名称,
	COALESCE(a.币种,b.币种) 币种,
	COALESCE(期初余额,0) 期初余额,
	COALESCE(期末余额,0) 期末余额,
	COALESCE(期末余额_原币,0) 期末余额_原币,
	COALESCE(a.科目名称,b.科目名称) 科目名称,
	COALESCE(a.科目代码,b.科目代码) 科目代码,
	COALESCE(-b.发生额,0) 本期增加,--增加
	FROM oap_balance a 
	FULL JOIN (SELECT * FROM occur WHERE 科目='其他应付') b 
	ON a.编码=b.编码 AND a.币种=b.币种 AND a.科目代码=b.科目代码
	)t
),
oar_detail as
(
	SELECT 编码,供应商名称,币种,期初余额,
	本期增加 本期借方,
	期初余额+本期增加-期末余额 as 本期贷方,
	期末余额,期末余额_原币,科目名称,科目代码
	FROM 
	(
	SELECT 
	COALESCE(a.编码,b.编码) 编码,
	COALESCE(a.供应商名称,b.客商名称) 供应商名称,
	COALESCE(a.币种,b.币种) 币种,
	COALESCE(期初余额,0) 期初余额,
	COALESCE(期末余额,0) 期末余额,
	COALESCE(期末余额_原币,0) 期末余额_原币,
	COALESCE(a.科目名称,b.科目名称) 科目名称,
	COALESCE(a.科目代码,b.科目代码) 科目代码,
	COALESCE(b.发生额,0) 本期增加,--增加
	FROM oar_balance a 
	FULL JOIN (SELECT * FROM occur WHERE 科目='其他应收') b 
	ON a.编码=b.编码 AND a.币种=b.币种 AND a.科目代码=b.科目代码
	)t
),
oap_f AS 
(
	SELECT *,
	期初余额+期初调整 期初审定余额,
	期末余额+"企业重分类调整（负数）"+企业其他调整 AS 企业未审报表数,
	CASE WHEN 期末余额_原币<0 THEN 0 ELSE 期末余额_原币 END 期末余额_原币_未审
	FROM 
	(
	SELECT *,
	CASE WHEN 期初余额<0 THEN -期初余额 ELSE 0 END AS 期初调整,
	CASE WHEN 期末余额<0 THEN -期末余额 ELSE 0 END AS "企业重分类调整（负数）",
	0 AS 企业其他调整,
	FROM oap_detail
	)oap
	UNION ALL 
	SELECT 
	NULL 编码,NULL 供应商名称,NULL 币种,NULL 期初余额,NULL 本期借方,NULL 本期贷方,NULL  期末余额,NULL 期末余额_原币,
	NULL 科目名称,NULL 科目代码,NULL 期初调整,NULL "企业重分类调整（负数）",
	NULL 企业其他调整,
	NULL 期初审定余额,
	NULL 企业未审报表数,
	NULL  期末余额_原币_未审
	UNION all --分割线
	SELECT 
	编码,供应商名称,币种,0 AS 期初余额,本期借方,本期贷方,0 期末余额,期末余额_原币,科目名称,科目代码,期初调整,"企业重分类调整（负数）",
	企业其他调整,
	期初调整 AS 期初审定余额,
	"企业重分类调整（负数）"+企业其他调整 AS 企业未审报表数,
	CASE WHEN 期末余额_原币<0 THEN -期末余额_原币 ELSE 0 END 期末余额_原币_未审
	FROM 
	(
	SELECT *,
	CASE WHEN 期初余额<0 THEN -期初余额 ELSE 0 END AS 期初调整,
	CASE WHEN 期末余额<0 THEN -期末余额 ELSE 0 END AS "企业重分类调整（负数）",
	0 AS 企业其他调整,
	FROM oar_detail
	WHERE 期末余额<0 OR 期初余额<0
	)oar
),
oar_f AS
(
	SELECT *,
	期初余额+期初调整 期初审定余额,
	期末余额+"企业重分类调整（负数）"+企业其他调整 AS 企业未审报表数,
	CASE WHEN 期末余额_原币<0 THEN 0 ELSE 期末余额_原币 END 期末余额_原币_未审
	FROM 
	(
	SELECT *,
	CASE WHEN 期初余额<0 THEN -期初余额 ELSE 0 END AS 期初调整,
	CASE WHEN 期末余额<0 THEN -期末余额 ELSE 0 END AS "企业重分类调整（负数）",
	0 AS 企业其他调整,
	FROM oar_detail
	)oar
	UNION ALL 
	SELECT 
	NULL 编码,NULL 供应商名称,NULL 币种,NULL 期初余额,NULL 本期借方,NULL 本期贷方,NULL  期末余额,NULL 期末余额_原币,
	NULL 科目名称,NULL 科目代码,NULL 期初调整,NULL "企业重分类调整（负数）",
	NULL 企业其他调整,
	NULL 期初审定余额,
	NULL 企业未审报表数,
	NULL  期末余额_原币_未审
	UNION all --分割线
	SELECT 
	编码,供应商名称,币种,0 AS 期初余额,本期借方,本期贷方,0 期末余额,期末余额_原币,科目名称,科目代码,期初调整,"企业重分类调整（负数）",
	企业其他调整,
	期初调整 AS 期初审定余额,
	"企业重分类调整（负数）"+企业其他调整 AS 企业未审报表数,
	CASE WHEN 期末余额_原币<0 THEN -期末余额_原币 ELSE 0 END 期末余额_原币_未审
	FROM 
	(
	SELECT *,
	CASE WHEN 期初余额<0 THEN -期初余额 ELSE 0 END AS 期初调整,
	CASE WHEN 期末余额<0 THEN -期末余额 ELSE 0 END AS "企业重分类调整（负数）",
	0 AS 企业其他调整,
	FROM oap_detail
	WHERE 期末余额<0 OR 期初余额<0
	)oap
)
SELECT *
FROM oap_f;




SELECT sum(期初审定余额),sum(企业未审报表数) FROM oap_f;-- 3367082.24	478471.78
--SELECT sum(期初审定余额),sum(企业未审报表数) FROM oar_f; -- 2062174490.05	1793109575.43
--SELECT * FROM oap_f;
--SELECT sum(期末余额) FROM t2 WHERE 期末余额>0
--SELECT sum(期末余额) FROM t4 WHERE 期末余额<0
--SELECT sum(期初余额) FROM oar_detail WHERE 期初余额<0;

--SELECT 478471.78-478421.619999886
--SELECT 3367082.24-3367082.24000001
SELECT 2062574392.69-2062174490.05; --茅台原因

SELECT 1793509575.43-1793109575.43;

SELECT 1793509575.43-1793509575.43


--3020	华峰重庆氨纶有限公司	-1078874105.76
--2160	上海华峰科技发展有限公司	-511458919.60
--3020	华峰重庆氨纶有限公司	-200000000.00
--10010085	国网辽宁省电力有限公司	-329190.15
--3020	华峰重庆氨纶有限公司	-125888.89


华峰重庆氨纶有限公司	-1078874105.76
华峰重庆氨纶有限公司	-200000000.00
华峰重庆氨纶有限公司	-125888.89


SELECT 
编码,供应商名称,币种,0 AS 期初余额,本期借方,本期贷方,0 期末余额,期末余额_原币,科目名称,科目代码,期初调整,"企业重分类调整（负数）",
企业其他调整,
期初调整 AS 期初审定余额,
"企业重分类调整（负数）"+企业其他调整 AS 企业未审报表数 FROM 
(
SELECT *,
CASE WHEN 期初余额<0 THEN -期初余额 ELSE 0 END AS 期初调整,
CASE WHEN 期末余额<0 THEN -期末余额 ELSE 0 END AS "企业重分类调整（负数）",
0 AS 企业其他调整,
FROM oap_detail
WHERE 期末余额<0
)oap;







--SELECT sum(期初余额),sum(期末余额),
--sum("企业重分类调整（负数）"),
--sum(期初调整),
--sum(期初余额)+sum(期初调整),
--sum(企业未审报表数) 
----FROM oap_f;
--FROM oar_f;


SELECT *,期末余额+"企业重分类调整（负数）"+企业其他调整 AS 企业未审报表数 FROM 
(
SELECT *,
CASE WHEN 期初余额<0 THEN -期初余额 ELSE 0 END AS 期初调整,
CASE WHEN 期末余额<0 THEN -期末余额 ELSE 0 END AS "企业重分类调整（负数）",
0 AS 企业其他调整,
FROM oar_detail
WHERE 期末余额<0
)oar;


SELECT sum(期初余额)
FROM oar_detail WHERE 期初余额<0;

SELECT sum(期初余额),sum(期末余额),
sum("企业重分类调整（负数）"),
sum(期初调整),
sum(期初余额)+sum(期初调整),
sum(企业未审报表数) 
FROM "其他应付明细表";

SELECT sql FROM duckdb_views() WHERE view_name = '其他应付明细表';


-3367082.24	-478421.62

--SELECT * FROM oar_balance;
SELECT * FROM oar_detail;
--SELECT * FROM oap_balance;
--SELECT * FROM oap_detail;
--SELECT * FROM occur;

SELECT sum(期末余额) FROM oap_balance;
--SELECT sum(期末余额) FROM oap_balance;
--SELECT * FROM occur WHERE 客商名称='李娟';
--SELECT * FROM occur WHERE 客商名称='陈余辉';
--select * from t4 where 期末余额<0
--select sum(期末余额) from t1; 
--select sum(期末余额) from t3 WHERE 期末余额<0;  -478471.78
--select sum(期末余额) from t2;
select sum(期末余额) from t1 where 期末余额<0 --   -1790788104.40
--select sum(期末余额) from t3 where 期末余额<0 --  -478471.78
--select sum(期末余额) from t4 where 期末余额<0 --  -3367082.24
--select sum(期末余额) from t4 where 期末余额<0 --  -478471.78

--11004636
--11005780
--11003920






--%%%%%%%%%%%%%%%%%%%%draft%%%%%%%%%%%%%%

SELECT 
科目代码,科目名称,sum(本位币货币期初),sum(本位货币期末)
FROM 科目余额表
where left(科目代码,4)='2241' --where 科目名称 like '%其他应付款%' 
group by 科目代码,科目名称


SELECT 
科目代码,科目名称,sum(本位币货币期初),sum(本位货币期末)
FROM 科目余额表
where left(科目代码,4)='1231' 
group by 科目代码,科目名称


SELECT 
*
FROM 科目余额表
where left(科目代码,4)='2241' --where 科目名称 like '%其他应付款%' 

-1791266526.02

--SELECT * FROM 往来发生额 WHERE 客商代码 like '%.%'
--SELECT * FROM 往来余额 WHERE 客商代码 like '%.%'


SELECT 
sum(本位币货币期初),sum(本位货币期末)
FROM 科目余额表
--where left(科目代码,4)='2241';
where left(科目代码,4)='1231';

where left(科目代码,4)='2241' and 科目代码!='22419900'; --22419900	其他应付款-重分类调整


select -1791266526.02+1791266576.18  --50.16 汇兑损益导致

--select 1790788104.40-1790788104.40 
--select 2059835309.97-2059835309.97

--12310110	其他应收款-单位-非关联	159271.04	123127.31
--12310190	其他应收款-押金	-41150.00	-41150.00
--12410030	坏账准备-其他应收款	-366968.23	-413587.64
--12310010	其他应收款-个人	-1146023.20	1761021.94
--12318900	其他应收款-汇兑调整	-97.36	50.16
--67020110	信用减值损失-其他应收款减值损失	0.00	46619.41
--12311090	其他应收款-出口退税	0.00	0.00
--12319900	其他应收款-重分类调整	2063602392.21	1791666526.02

--不含坏账准备 

--其他应付明细表 应付负数代表增加，期末负数需要重分类, 2241应付 1231应收




--草稿




--oap_balance as --其他应付 期初+期末 + 其他应收重分类
--(
--	select 
--	coalesce(a.编码,b.编码) 编码,
--	coalesce(a.供应商名称,b.供应商名称) 供应商名称,
--	coalesce(a.币种,b.币种) 币种,
--	coalesce(a.期末余额,0) 期初余额,
--	coalesce(b.期末余额,0) 期末余额,
--	coalesce(b.期末余额_原币,0) 期末余额_原币,
--	coalesce(a.科目名称,b.科目名称) 科目名称
--	from 
--	(
--	select * from t2 
--	union all 
--	select * from t4 where 期末余额<0
--	)a --期初余额
--	full join 
--	(
--	select * from t1
--	union all 
--	select * from t3 where 期末余额<0
--	)b --期末余额
--	on a.编码=b.编码 and a.币种=b.币种
--),
--oar_balance AS --其他应收 期初+期末 + 其他应收重分类
--(
--	select 
--	coalesce(a.编码,b.编码) 编码,
--	coalesce(a.供应商名称,b.供应商名称) 供应商名称,
--	coalesce(a.币种,b.币种) 币种,
--	coalesce(a.期末余额,0) 期初余额,
--	coalesce(b.期末余额,0) 期末余额,
--	coalesce(b.期末余额_原币,0) 期末余额_原币
--	,coalesce(a.科目名称,b.科目名称) 科目名称
--	from 
--	(
--	select * from t2 where 期末余额<0
--	union all 
--	select * from t4 
--	)a --期初余额
--	full join 
--	(
--	select * from t1 where 期末余额<0
--	union all 
--	select * from t3 
--	)b --期末余额
--	on a.编码=b.编码 and a.币种=b.币种
--),