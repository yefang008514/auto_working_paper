select * from 科目余额表
--where 科目名称 like '%固定资产%'; --1601
--where 科目名称 like '%在建工程%'; --1604
--where 科目名称 like '%无形资产%'; --1701
--where left(科目代码,4)='1607'; --1607 --固定资产清理
--where left(科目代码,4)='1702'; --1702 --累计摊销
--where left(科目代码,4)='1602'; --1602 --累计折旧
--where left(科目代码,4)='1604'; --1604 --在建工程
WHERE 科目名称='固定资产-重分类调整'; --16010990


1701 无形资产
1602 累计折旧
1604 在建工程
1607 固定资产清理
1702 累计摊销
1601 固定资产


SELECT 借贷标识,sum(公司代码货币价值) FROM 固定资产_发生额
WHERE 总账科目='16010990'
GROUP BY 借贷标识;

SELECT sum(公司代码货币价值) FROM 固定资产_发生额
WHERE 总账科目='16010990'; --46898046.77

SELECT * FROM 固定资产_发生额
WHERE 凭证编号='15002110'

SELECT * FROM 固定资产_发生额 a
WHERE exists(SELECT * FROM 固定资产_发生额 b WHERE 总账科目='16010990' AND a.凭证编号=b.凭证编号)
ORDER BY 凭证编号 asc


select * from 科目余额表
where left(科目代码,4)='1601' ;

--固定资产-重分类调整 期初和期末数和不含重分类发是可以对上的

select sum(本位币货币期初),sum(本位货币期末) from 科目余额表
where left(科目代码,4)='1601' and 科目代码!='16010990';
--6024119203.48	6023718264.38

select sum(本位币货币期初),sum(本位货币期末) from 科目余额表
where left(科目代码,4)='1601'





with t1 as --期末余额
(
select 
主资产号,
map_extract(map(['Z010','Z020','Z030','Z040','Z050','Z059','Z060','Z070','Z080'],
['房屋','构筑物','机器设备','器具及工具','办公设备','办公设备(无价值)','运输设备','电子设备','研发设备']),资产类别)[1] 类别,
(CASE WHEN 类别 IN ('办公设备','电子设备','办公设备(无价值)') THEN '电子设备及其他'
     WHEN 类别 IN ('房屋','构筑物') THEN '房屋及建筑物'
     WHEN 类别 IN ('机器设备','器具及工具') THEN '机器设备'
     WHEN 类别 IN ('运输设备') THEN '运输设备'
     WHEN 类别 IN ('研发设备') THEN '研发设备' else NULL end) 大类,
固定资产名称 资产描述,
规格型号 权证归属,
原值 期末余额,
开始使用日期 资本化时间
from 固定资产清单
where 期间_add='this' and left(资产类别,2)='Z0' and 资产类别!='Z011' and 原值!=0
),
t2 as --期末报废
(
select 
主资产号,
map_extract(map(['Z010','Z020','Z030','Z040','Z050','Z059','Z060','Z070','Z080'],
['房屋','构筑物','机器设备','器具及工具','办公设备','办公设备(无价值)','运输设备','电子设备','研发设备']),资产类别)[1] 类别,
(CASE WHEN 类别 IN ('办公设备','电子设备','办公设备(无价值)') THEN '电子设备及其他'
     WHEN 类别 IN ('房屋','构筑物') THEN '房屋及建筑物'
     WHEN 类别 IN ('机器设备','器具及工具') THEN '机器设备'
     WHEN 类别 IN ('运输设备') THEN '运输设备'
     WHEN 类别 IN ('研发设备') THEN '研发设备' else NULL end) 大类,
固定资产名称 资产描述,
规格型号 权证归属,
原值 期末余额,
开始使用日期 资本化时间
from 固定资产清单_报废
where 期间_add='this' and left(资产类别,2)='Z0' and 资产类别!='Z011' and 原值!=0
),
t3 as --期初余额
(
select 
主资产号,
map_extract(map(['Z010','Z020','Z030','Z040','Z050','Z059','Z060','Z070','Z080'],
['房屋','构筑物','机器设备','器具及工具','办公设备','办公设备(无价值)','运输设备','电子设备','研发设备']),资产类别)[1] 类别,
(CASE WHEN 类别 IN ('办公设备','电子设备','办公设备(无价值)') THEN '电子设备及其他'
     WHEN 类别 IN ('房屋','构筑物') THEN '房屋及建筑物'
     WHEN 类别 IN ('机器设备','器具及工具') THEN '机器设备'
     WHEN 类别 IN ('运输设备') THEN '运输设备'
     WHEN 类别 IN ('研发设备') THEN '研发设备' else NULL end) 大类,
固定资产名称 资产描述,
规格型号 权证归属,
原值 期末余额,
开始使用日期 资本化时间
from 固定资产清单
where 期间_add='last' and left(资产类别,2)='Z0' and 资产类别!='Z011' and 原值!=0
),
t4 as 
(
select 
主资产号,
map_extract(map(['Z010','Z020','Z030','Z040','Z050','Z059','Z060','Z070','Z080'],
['房屋','构筑物','机器设备','器具及工具','办公设备','办公设备(无价值)','运输设备','电子设备','研发设备']),资产类别)[1] 类别,
(CASE WHEN 类别 IN ('办公设备','电子设备','办公设备(无价值)') THEN '电子设备及其他'
     WHEN 类别 IN ('房屋','构筑物') THEN '房屋及建筑物'
     WHEN 类别 IN ('机器设备','器具及工具') THEN '机器设备'
     WHEN 类别 IN ('运输设备') THEN '运输设备'
     WHEN 类别 IN ('研发设备') THEN '研发设备' else NULL end) 大类,
固定资产名称 资产描述,
规格型号 权证归属,
原值 期末余额,
开始使用日期 资本化时间
from 固定资产清单_报废
where 期间_add='last' and left(资产类别,2)='Z0' and 资产类别!='Z011' and 原值!=0
),
t5 as --余额明细
(
select 
COALESCE(a.主资产号,b.主资产号) 主资产号,
COALESCE(a.类别,b.类别) 类别,
COALESCE(a.大类,b.大类) 大类,
COALESCE(a.资产描述,b.资产描述) 资产描述,
COALESCE(a.权证归属,b.权证归属) 权证归属,
COALESCE(a.资本化时间,b.资本化时间) 开始使用日期,
COALESCE(b.期末余额,0) 期初余额,
COALESCE(a.期末余额,0) 期末余额
from 
(
select * from t1 
union all 
select * from t2)a 
full join 
(
select * from t3 
union all 
select * from t4)b on a.主资产号=b.主资产号
),
occur as 
(

)

--select * from 固定资产_发生额 where 公司代码 is null --不影响
--select sum(期初余额),sum(期末余额) from t5;
select * from t5 where 期初余额!=期末余额;
--select sum(期末余额) from t1; --6021908002.26
select sum(期末余额) from t2; --1810262.12  4221134.21



电子设备及其他	办公设备
电子设备及其他	电子设备
房屋及建筑物	房屋
房屋及建筑物	构筑物
机器设备	机器设备
机器设备	器具及工具
运输工具	运输设备
运输设备	运输设备









--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%发生额分析%%%%%%%%%%%%%%%%%%%%%%%%%

--1.固定资产_发生额范围 (全部的固定资产发生额)
create or replace view 固定资产_发生额范围 as 
select *,str_split("总账科目：短文本",'-')[1] 科目名称
from 固定资产_发生额
where LEFT(总账科目,4)='1601';

--2.固定资产_标签_冲销关于 (有冲销关于的) 如果对资产号对应金额有影响 放到需要判断
create or replace view 固定资产_标签_冲销关于 as --统一放在  增加_其他增加
with t1 as 
(
select *,sum(公司代码货币价值) over (partition by 资产) as 影响金额 
from 固定资产_发生额范围
where 冲销关于 IS not null
)
select id,case when 影响金额=0 then '不影响' else '！需要判断' end as 标签,'增加' 增减分类,'其他增加' 增减细分
from t1;

--3.1固定资产_增加_购置 购置
create or replace view 固定资产_增加_购置 as 
with t1 as 
(
select *
from 固定资产_发生额范围
where 冲销关于 IS null and 凭证类型 in ('OA','WE','RE','WA')
)
select *,'购置' 标签,'增加' 增减分类,'购置' 增减细分
from t1;


--3.2固定资产_标签_购置  
create or replace view 固定资产_标签_购置 as 
select id,'购置' 标签,'增加' 增减分类,'购置' 增减细分
from 固定资产_增加_购置;


--4.固定资产_对方科目分析 （除了购置和冲销关于的）
create or replace view 固定资产_对方科目分析 as 
WITH t1 AS --需要做对方科目分析的资产
(
SELECT *,str_split("总账科目：短文本",'-')[1] 科目名称
FROM 固定资产_发生额 a
WHERE 凭证类型 NOT in ('OA','WE','RE','WA') AND 
EXISTS (SELECT * FROM 固定资产_发生额 b WHERE LEFT(b.总账科目,4)='1601' AND b.冲销关于 IS null AND a.凭证编号=b.凭证编号)
),
t2 as --统计这部分凭证包含的科目
(
SELECT DISTINCT 凭证编号,string_agg(科目名称, ',') OVER(PARTITION BY 凭证编号) AS 包含科目  FROM 
(
SELECT DISTINCT 凭证编号,left(总账科目,4) 科目编码,str_split("总账科目：短文本",'-')[1] 科目名称
FROM t1
)t 
),
t3 AS --生成对方科目
(
SELECT t1.*,t2.包含科目,
CASE WHEN ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i !=科目名称],',') IS NOT NULL 
THEN ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i !=科目名称],',') ELSE 科目名称 END as 对方科目,
count(distinct 资产) over(partition by t1.凭证编号) 凭证包含资产数量,
sum(公司代码货币价值) over(partition by t1.凭证编号) 凭证对应资产金额
FROM t1 LEFT JOIN t2 ON t1.凭证编号=t2.凭证编号
),
t4 as --需要打标签的固定资产
(
select *
from t3
where 科目名称='固定资产'
)
select * from t4;


--5.固定资产_减少_处置或报废
create or replace view 固定资产_减少_处置或报废 as 
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i='累计折旧' or i='固定资产清理'],',') IS NOT null 
and 凭证包含资产数量=1;


--6.固定资产_减少_转至投资性房地产
create or replace view 固定资产_减少_转至投资性房地产 as 
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i='投资性房地产'],',') IS NOT null;


--7.固定资产_增加_在建工程转入
create or replace view 固定资产_增加_在建工程转入 as 
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i='在建工程'],',') IS NOT null 
and 凭证包含资产数量>1;


--8.1 固定资产_增加_资产拆分
create or replace view 固定资产_增加_资产拆分 as 
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i in('固定资产','累计折旧')],',') IS NOT null 
and 凭证包含资产数量>1 and 借贷标识='S'
AND 凭证对应资产金额=0 AND 总账科目 NOT in('16010990'); --16010990 非重分类调整


--8.2 固定资产_增加_其他购置
create or replace view 固定资产_增加_其他购置 as 
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i in('固定资产','累计折旧')],',') IS NOT null 
and 凭证包含资产数量>1 and 借贷标识='S'
AND 凭证对应资产金额>0 AND 总账科目 NOT in('16010990');

--8.3 固定资产_增加_重分类调整
create or replace view 固定资产_增加_重分类调整 as
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i in('固定资产','累计折旧')],',') IS NOT null 
and 凭证包含资产数量>1 and 借贷标识='S'
AND 总账科目 IN ('16010990');


--9.1固定资产_减少_资产拆分
create or replace view 固定资产_减少_资产拆分 as 
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i in('固定资产','累计折旧')],',') IS NOT null 
and 凭证包含资产数量>1 and 借贷标识='H' AND 凭证编号 NOT IN (SELECT 凭证编号 FROM 固定资产_增加_重分类调整);


--9.2 固定资产_减少_资产拆分
create or replace view 固定资产_减少_重分类调整 as 
select * from 固定资产_对方科目分析
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i in('固定资产','累计折旧')],',') IS NOT null 
and 凭证包含资产数量>1 and 借贷标识='H' AND 凭证编号 IN (SELECT 凭证编号 FROM 固定资产_增加_重分类调整);



--10.固定资产_发生额标签取舍 (作为实体表)
create or replace table 固定资产_标签_取舍 as 
WITH t9 as --标签
(
	select *,count(1) over(partition by id) 同id出现次数 from 
	(
	select id,'处置或报废' 标签,'减少' 增减分类,'处置或报废' 增减细分 from 固定资产_减少_处置或报废
	union all 
	select id,'转至投资性房地产' 标签,'减少' 增减分类,'转至投资性房地产' 增减细分 from 固定资产_减少_转至投资性房地产
	union all 
	select id,'资产拆分' 标签,'减少' 增减分类,'资产拆分' 增减细分 from 固定资产_减少_资产拆分 
	union all 
	select id,'！需要判断' 标签,'增加' 增减分类,'其他增加' 增减细分 from 固定资产_减少_重分类调整 -- 重分类放在其他增加
	union all 
	select id,'在建工程转入' 标签,'增加' 增减分类,'在建工程转入' 增减细分 from 固定资产_增加_在建工程转入
	union all 
	select id,'资产拆分' 标签,'增加' 增减分类,'资产拆分' 增减细分 from 固定资产_增加_资产拆分
	union all 
	select id,'！需要判断' 标签,'增加' 增减分类,'其他增加' 增减细分 from 固定资产_增加_重分类调整
	union all 
	select id,'购置' 标签,'增加' 增减分类,'购置' 增减细分 from 固定资产_增加_其他购置
	)t
),
t10 as --确定标签
(
select id,标签,增减分类,增减细分 from t9 where 同id出现次数=1
),
t11 as --不确定  ！需要判断 统一放到其他增加 ()
(
select id,'！需要判断' 标签,'增加' 增减分类,'其他增加' 增减细分  
FROM 
(
	SELECT *,row_number() over(partition by id) flag FROM 
	(
	select id from t9 where 同id出现次数>1
	UNION ALL 
	select id from 固定资产_对方科目分析 where id not in (select id from t10)
	)t
)temp
where flag=1
),
t12 as --所有标签
(
select * from t11
union all 
select * from t10
)
SELECT * FROM t12;



--11.固定资产_标签_汇总
create or replace view 固定资产_标签_汇总 as 
SELECT * FROM 固定资产_标签_取舍
union all 
SELECT * FROM 固定资产_标签_购置
union all 
SELECT * FROM 固定资产_标签_冲销关于;




--12.打标后的所有发生额 供项目组做参考 重点关注 ！需要判断
create or replace view 固定资产_发生额范围_标签 as 
SELECT a.*,b.标签,b.增减分类,b.增减细分,c.对方科目,c.包含科目
FROM 固定资产_发生额范围 a 
LEFT JOIN 固定资产_标签_汇总 b ON a.id = b.id
LEFT JOIN 固定资产_对方科目分析 c ON a.id = c.id;


--13 固定资产_发生额_按资产
create or replace table 固定资产_发生额_按资产 as 
WITH t1 AS 
(
SELECT 资产,增减分类,增减细分,公司代码货币价值 FROM 固定资产_发生额范围_标签
UNION ALL 
select NULL 资产,'减少' 增减分类,'处置或报废' 增减细分, NULL 公司代码货币价值
union all 
select NULL 资产,'减少' 增减分类,'转至投资性房地产' 增减细分, NULL 公司代码货币价值
union all 
select NULL 资产,'减少' 增减分类,'资产拆分' 增减细分, NULL 公司代码货币价值
union all 
select NULL 资产,'减少' 增减分类,'其他减少' 增减细分, NULL 公司代码货币价值
union all 
select NULL 资产,'增加' 增减分类,'在建工程转入' 增减细分, NULL 公司代码货币价值
union all 
select NULL 资产,'增加' 增减分类,'资产拆分' 增减细分, NULL 公司代码货币价值
union all 
select NULL 资产,'增加' 增减分类,'其他增加' 增减细分, NULL 公司代码货币价值
union all 
select NULL 资产,'增加' 增减分类,'购置' 增减细分, NULL 公司代码货币价值
)
SELECT 
资产,增加_购置,增加_在建工程转入,增加_资产拆分,增加_其他增加,'' 增加原因,
-1*减少_处置或报废 减少_处置或报废,-1*减少_转至投资性房地产 减少_转至投资性房地产,-1*减少_资产拆分 减少_资产拆分,-1*减少_其他减少 减少_其他减少, '' 减少原因
FROM 
(
pivot t1
ON 增减分类,增减细分
USING sum(公司代码货币价值)
GROUP BY 资产
)t;


SELECT * FROM 固定资产_发生额_按资产


--校验项目
SELECT sum(公司代码货币价值) FROM 固定资产_减少_重分类调整;
SELECT sum(公司代码货币价值) FROM 固定资产_增加_重分类调整;

SELECT sum(公司代码货币价值) FROM 固定资产_减少_资产拆分;
SELECT sum(公司代码货币价值) FROM 固定资产_增加_资产拆分;



pivot 固定资产_发生额范围_标签
ON 增减分类,增减细分
USING sum(公司代码货币价值)
GROUP BY 增减细分


SELECT 资产,sum(公司代码货币价值) 金额
FROM 固定资产_发生额范围_标签
WHERE 增减分类='增加' AND 增减细分='资产拆分'
AND "总账科目：短文本" NOT LIKE '%重分类%'
GROUP BY 资产

SELECT * FROM 固定资产_发生额范围_标签
WHERE 资产 IN ('503907','503905','503906')






 




SELECT * FROM 固定资产_标签_汇总; --1023

SELECT * FROM 固定资产_发生额范围; --1023

SELECT * FROM 固定资产_发生额范围_标签; --1023

SELECT * FROM 固定资产_增加_购置; --712

SELECT * FROM 固定资产_对方科目分析; --261

SELECT * FROM 固定资产_标签_冲销关于; --50


SELECT a.*,b.标签,b.增减细分 FROM 固定资产_发生额范围 a 
LEFT JOIN 固定资产_标签_汇总 b ON a.id=b.id 
WHERE 标签='！需要判断'

SELECT * FROM 固定资产_对方科目分析 a 
LEFT JOIN 固定资产_标签_汇总 b ON a.id=b.id WHERE 标签='！需要判断'

SELECT * FROM 固定资产_标签_汇总 WHERE 标签='！需要判断'












--%%%%%%%%%%%%%%%%%5草稿%%%%%%%%%%%%%%


select *,case when 凭证类型 in ('OA','WE','RE') then '外购' else NULL end as '外购判断'
from 固定资产_发生额
where left(总账科目,4)='1601' 

--1.购置无需区分借贷方 直接汇总借贷就行
SELECT 资产,sum(公司代码货币价值) 购置  
FROM 固定资产_发生额
WHERE left(总账科目,4)='1601' AND 凭证类型 in ('OA','WE','RE') 
GROUP BY 资产

SELECT * FROM 固定资产_发生额 
WHERE left(总账科目,4)='1601' AND 凭证类型 NOT in ('OA','WE','RE') 


--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%发生额草稿

SELECT * FROM 固定资产_发生额
WHERE  凭证类型 NOT in ('OA','WE','RE')
AND 凭证编号 IN (SELECT DISTINCT 凭证编号 FROM 固定资产_发生额 WHERE LEFT(总账科目,4)='1601' AND 冲销关于 IS null);


SELECT * FROM 固定资产_发生额
WHERE  凭证类型 NOT in ('OA','WE','RE')
AND LEFT(总账科目,4)='1601';




SELECT sum(公司代码货币价值) ---3870130.20

SELECT 凭证编号,冲销关于,sum(公司代码货币价值) 凭证金额 ---3870130.20
FROM 固定资产_发生额 a
WHERE 凭证类型 NOT in ('OA','WE','RE','WA') AND 
EXISTS (SELECT * FROM 固定资产_发生额 b WHERE LEFT(b.总账科目,4)='1601' AND b.冲销关于 IS not null AND a.凭证编号=b.凭证编号)
group by 凭证编号,冲销关于
order by abs(凭证金额)



select 资产,sum(公司代码货币价值) from 固定资产_发生额
where LEFT(总账科目,4)='1601' and 冲销关于 IS not null
group by 资产


select * from 固定资产_发生额
where LEFT(总账科目,4)='1601' and 冲销关于 IS not null and 资产 is null






t5 as --减少_处置或报废
(
select *  --一次性计提折旧 或 处置 固定资产清理
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i='累计折旧' or i='固定资产清理'],',') IS NOT null 
and 凭证包含资产数量=1
),
t6 as --减少_转至投资性房地产 
(
select *  
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i='投资性房地产'],',') IS NOT null 
),
t7 as --增加_在建工程转入
(
select *  
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i='在建工程'],',') IS NOT null 
and 凭证包含资产数量>1
),
t8 as --资产拆分
(
select *  
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i in('固定资产','累计折旧')],',') IS NOT null 
and 凭证包含资产数量>1
),
t9 as --标签
(
select *,count(1) over(partition by id) 同id出现次数 from 
(
select id,'减少_处置或报废' 标签 from t5
union all 
select id,'减少_转至投资性房地产' 标签 from t6
union all 
select id,'增加_在建工程转入' 标签 from t7
union all 
select id,'增加_资产拆分' 标签 from t8 where 借贷标识='S'
union all 
select id,'减少_资产拆分' 标签 from t8 where 借贷标识='H'
)t
),
t10 as --确定标签
(
select id,标签 from t9 where 同id出现次数=1
),
t11 as --不确定
(
select id,'其他' 标签
from 
(
select *,row_number() over(partition by id) flag
from t9 where 同id出现次数>1)t where flag=1
union all 
select t4.id,'其他' 标签
from t4 
where id not in (select id from t10)
),
t12 as --所有标签
(
select * from t11
union all 
select * from t10
)
select * from t4;













WITH t1 AS --需要做对方科目分析的资产
(
SELECT *,str_split("总账科目：短文本",'-')[1] 科目名称
FROM 固定资产_发生额 a
WHERE 凭证类型 NOT in ('OA','WE','RE','WA') AND 
EXISTS (SELECT * FROM 固定资产_发生额 b WHERE LEFT(b.总账科目,4)='1601' AND b.冲销关于 IS null AND a.凭证编号=b.凭证编号)
),
t2 as --统计这部分凭证包含的科目
(
SELECT DISTINCT 凭证编号,string_agg(科目名称, ',') OVER(PARTITION BY 凭证编号) AS 包含科目  FROM 
(
SELECT DISTINCT 凭证编号,left(总账科目,4) 科目编码,str_split("总账科目：短文本",'-')[1] 科目名称
FROM t1
)t 
),
t3 AS --生成对方科目
(
SELECT t1.*,t2.包含科目,
CASE WHEN ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i !=科目名称],',') IS NOT NULL 
THEN ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i !=科目名称],',') ELSE 科目名称 END as 对方科目,
count(distinct 资产) over(partition by t1.凭证编号) 凭证包含资产数量
FROM t1 LEFT JOIN t2 ON t1.凭证编号=t2.凭证编号
),
t4 as --需要打标签的固定资产
(
select *
from t3
where 科目名称='固定资产'
),
t5 as --减少_处置或报废
(
select *  --一次性计提折旧 或 处置 固定资产清理
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i='累计折旧' or i='固定资产清理'],',') IS NOT null 
and 凭证包含资产数量=1
),
t6 as --减少_转至投资性房地产 
(
select *  
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(包含科目,',') IF i='投资性房地产'],',') IS NOT null 
),
t7 as --增加_在建工程转入
(
select *  
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i='在建工程'],',') IS NOT null 
and 凭证包含资产数量>1
),
t8 as --资产拆分
(
select *  
from t4 
where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i in('固定资产','累计折旧')],',') IS NOT null 
and 凭证包含资产数量>1
),
t9 as --标签
(
select *,count(1) over(partition by id) 同id出现次数 from 
(
select id,'减少_处置或报废' 标签 from t5
union all 
select id,'减少_转至投资性房地产' 标签 from t6
union all 
select id,'增加_在建工程转入' 标签 from t7
union all 
select id,'增加_资产拆分' 标签 from t8 where 借贷标识='S'
union all 
select id,'减少_资产拆分' 标签 from t8 where 借贷标识='H'
)t
),
t10 as --确定标签
(
select id,标签 from t9 where 同id出现次数=1
),
t11 as --不确定
(
select id,'其他' 标签
from 
(
select *,row_number() over(partition by id) flag
from t9 where 同id出现次数>1)t where flag=1
union all 
select t4.id,'其他' 标签
from t4 
where id not in (select id from t10)
),
t12 as --所有标签
(
select * from t11
union all 
select * from t10
)
select * from t4;






--select t4.id,'其他' from t4 
--left join t10 on t4.id =t10.id
--where t10.id is null



--select * from t4 --261
--select * from t9 where 同id出现次数>1


select *,count(1) over(partition by id),row_number() over(partition by id)
from 
(
select unnest((range(1,10)+range(1,10))+range(1,2)) as id
)t



and 凭证包含资产数量=1

--select * from t4
--where ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i='固定资产清理'],',') IS NOT null 
--and 凭证包含资产数量>1


where 对方科目='累计折旧' and 凭证包含资产数量


在建工程转入 as
(
SELECT 资产,sum(公司代码货币价值) 在建工程转入
FROM t3
WHERE ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i ='在建工程'],',') IS NOT null --对方科目包含在建工程
group by 资产
),
资产拆分转入 as
(
SELECT 资产,sum(公司代码货币价值) 原值调增
FROM t3
WHERE ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i ='固定资产'],',') IS NOT null --对方科目包含固定资产
group by 资产
)
SELECT *
FROM t3
WHERE ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i ='固定资产'],',') IS NOT null --对方科目包含固定资产



--select * from 在建工程转入
--select * from 资产拆分转入




SELECT *
FROM t3
WHERE ARRAY_TO_STRING([i FOR i IN string_split(对方科目,',') IF i ='在建工程'],',') IS NOT null --对方科目包含在建工程
and 借贷标识='H'

sel
11002172





SELECT * FROM 固定资产_发生额
WHERE 凭证编号='15002110'

--SELECT * FROM t2
--SELECT 凭证编号,UNNEST(STRING_SPLIT(包含科目, ',')) FROM t2


WHERE len(包含科目)-len(replace(包含科目,',',''))>1
ORDER BY 凭证编号 asc

WHERE 对方科目 LIKE '%,%'


--CASE WHEN replace(replace(包含科目,科目名称,''),',','')='' 
--THEN 科目名称 ELSE replace(replace(包含科目,科目名称,''),',','') END AS 对方科目






SELECT *,string_agg(科目名称, ',' ) OVER(PARTITION BY 凭证编号 ) AS 包含科目 
FROM t2

SELECT * FROM t1
LEFT JOIN t2 



CREATE TABLE tbl AS
    SELECT s FROM range(1, 4) r(s);

SELECT string_agg(s, ', ' ORDER BY s DESC) AS countdown
FROM tbl;

SELECT * FROM tbl



SELECT DISTINCT* FROM t2;

ORDER BY 凭证编号 asc;
--,STRING_AGG(科目名称,',')

SELECT 资产,sum(公司代码货币价值) FROM 固定资产_发生额
WHERE 冲销关于 IS NOT NULL 
AND exists(SELECT * FROM 固定资产_发生额 WHERE LEFT(总账科目,4)='1601')
GROUP BY 资产


SELECT * FROM 固定资产_发生额
WHERE 冲销关于 IS NOT NULL 
AND exists(SELECT * FROM 固定资产_发生额 WHERE LEFT(总账科目,4)='1601')
AND 资产 IS null



SELECT 资产,sum(公司代码货币价值) FROM 固定资产_发生额
WHERE 冲销关于 IS NOT NULL 
AND exists(SELECT * FROM 固定资产_发生额 WHERE LEFT(总账科目,4)='1601')
GROUP BY 资产;


SELECT * FROM 固定资产_发生额
--WHERE 凭证编号='11003175'
WHERE 凭证编号='15002110'


SELECT * FROM 固定资产_发生额
--WHERE 凭证编号='11003176'
WHERE 凭证编号='15011551'


11003175 11003176

15002110 15011551





select map(['Z010','Z011','Z020','Z030','Z040','Z050','Z059','Z060','Z070','Z080'],
['房屋','投资性房地产','构筑物','机器设备','器具及工具','办公设备','办公设备(无价值)','运输设备','电子设备','研发设备'])



select map_extract(map(['Z010','Z011','Z020','Z030','Z040','Z050','Z059','Z060','Z070','Z080'],
['房屋','投资性房地产','构筑物','机器设备','器具及工具','办公设备','办公设备(无价值)','运输设备','电子设备','研发设备']),'Z010')[1]


