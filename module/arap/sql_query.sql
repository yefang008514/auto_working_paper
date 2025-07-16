--%%%%%%%%%%%%%%应付辅助数据%%%%%%%%%%%%%%%%%%


-- 应付账款明细表_空白行
CREATE OR REPLACE VIEW "应付账款明细表_空白行" AS
select NULL 编码,	NULL 供应商名称, NULL 试算分类,NULL 款项性质,
NULL 期初余额,NULL 本期增加,NULL 本期减少,NULL 期末余额,
NULL 暂估金额,NULL 总账调整暂估,NULL 负数调整,NULL 汇率调整,NULL 其他调整,
NULL 未审期末余额,NULL 币种,NULL 原币金额;

--杂费暂估
CREATE OR REPLACE VIEW "杂费暂估" AS
SELECT 
'14010070' 编码,
'材料采购（GR/IR）-杂费' 供应商名称,
'其他' 试算分类,
'' 款项性质,
0 期初余额,
0 本期增加,
0 本期减少,
0 期末余额,
sum(暂估金额) 暂估金额,
0 总账调整暂估,
0 负数调整,
0 汇率调整,
0 其他调整,
sum(暂估金额) 未审期末余额, --新增修改取暂估金额
币种,
sum(原币暂估金额) 原币金额
FROM 应付暂估_ZFI072N
where 杂费描述 is not null
group by 币种;

--预提费用
CREATE OR REPLACE VIEW "预提费用" AS
select 
科目代码 编码,
科目名称 供应商名称,
'' 试算分类,
'' 款项性质,
-1*本位币货币期初 期初余额,
本位货币贷方 本期增加,
本位货币借方 本期减少,
-1*本位货币期末 期末余额,
0 暂估金额,
0 总账调整暂估,
0 负数调整,
0 汇率调整,
0 其他调整,
-1*本位货币期末 未审期末余额, --修改为-1*本位货币期末
货币代码 as 币种,
-1*外币期末 as 原币金额  --新增修改为-1*外币期末
from 科目余额表
where left(科目代码,4)='2251';



--0.AP 应付账款明细表_temp
CREATE OR REPLACE VIEW "应付账款明细表_temp" AS
with t1 as --2024 期末余额
(
select 客商代码 编码,客商名称 供应商名称,原币符号 币种,
-sum(本位币余额) 期末余额,
-sum(原币余额) 期末余额_原币
from 往来余额
where 科目名称 like '%应付账款%' and 类型_add='FBL1H'
and 期间_add='this' 
group by 客商代码,客商名称,原币符号
),
t2 as --2024 期初余额
(
select 客商代码 编码,客商名称 供应商名称,原币符号 币种,
-sum(本位币余额) 期初余额
from 往来余额
where 科目名称 like '%应付账款%' and 类型_add='FBL1H'
and 期间_add='last'
group by 客商代码,客商名称,原币符号
),
t3 as --期末暂估 
(
select * from 
(
select 供应商编码 编码,供应商名称,币种,sum(暂估金额) 暂估金额_本位币,sum(原币暂估金额) 暂估金额_原币
from 应付暂估_ZFI072N
where 杂费描述 is null
group by 供应商编码,供应商名称,币种
)tt3 where 暂估金额_本位币!=0
),
t4 as --外币评估清单 
(
select 账户 编码,货币 币种,-sum(记帐金额) 汇率调整 
from 外币评估清单
where left(总帐帐目,4) in ('2202') --应付账款
group by 账户,货币
),
t5 as --发生额 筛选2202开头的(应付账款)科目暂时汇总 OA RE的H方向 算出贷方发生额 最后倒轧 
(
select 客商代码 编码,客商名称 供应商名称,原币符号 币种,-sum(本位币金额) 本期增加 from 往来发生额
where 类型_add='FBL1H' and left(科目代码,4)='2202'
and 凭证类型 in ('OA','RE') 
group by 客商代码,客商名称,原币符号
),
t6 as 
(
    select 
    编码,供应商名称,期初余额,本期增加,
    期初余额+本期增加-期末余额 as 本期减少,
    期末余额,
    币种,
    期末余额_原币
    from 
    (
    select --往来余额
    coalesce(a.编码,t5.编码) 编码,
    coalesce(a.供应商名称,t5.供应商名称) 供应商名称,
    coalesce(a.期初余额,0)期初余额,
    coalesce(t5.本期增加,0) 本期增加,
    coalesce(a.期末余额,0) 期末余额,
    coalesce(a.币种,t5.币种) 币种,
    coalesce(a.期末余额_原币,0) 期末余额_原币,
    from 
        (
        select --往来余额
        coalesce(t1.编码,t2.编码) 编码,
        coalesce(t1.供应商名称,t2.供应商名称) 供应商名称,
        coalesce(t2.期初余额,0) 期初余额,
        coalesce(t1.期末余额,0) 期末余额,
        coalesce(t1.币种,t2.币种) 币种,
        coalesce(t1.期末余额_原币,0) 期末余额_原币
        from t1 full join t2 on t1.编码=t2.编码 and t1.币种=t2.币种
        )a full join t5 on a.编码=t5.编码 and a.币种=t5.币种
    )temp
),
temp_result as 
(
select 
编码,
供应商名称,
试算分类,
款项性质,
期初余额,
本期增加,
本期减少,
期末余额,
暂估金额,
总账调整暂估,
负数调整,
汇率调整,
其他调整,
期末余额+暂估金额+总账调整暂估+负数调整+汇率调整+其他调整 as 未审期末余额,
币种,
原币金额 原币金额_调整前,
case when (期末余额+暂估金额+总账调整暂估+负数调整+汇率调整+其他调整)=0 then 0 else 原币金额 end as 原币金额_调整后
from
(
select *,
case when (期末余额+暂估金额+汇率调整+总账调整暂估+其他调整)<0 then -1*(期末余额+暂估金额+汇率调整+总账调整暂估+其他调整) else 0 end as 负数调整, --负数调整需要考虑暂估
from
(
select 
coalesce(t6.编码,t3.编码) 编码,
coalesce(t6.供应商名称,t3.供应商名称) 供应商名称,
'' 试算分类,
'' 款项性质,
coalesce(t6.期初余额,0) 期初余额,
coalesce(t6.本期增加,0) 本期增加,
coalesce(t6.本期减少,0) 本期减少,
coalesce(t6.期末余额,0) 期末余额,
coalesce(t3.暂估金额_本位币,0) 暂估金额,--暂估
0 总账调整暂估,
coalesce(t4.汇率调整,0) 汇率调整,--汇率调整
0 其他调整,
coalesce(t6.币种,t3.币种) 币种,--币种
coalesce(t6.期末余额_原币,0) + coalesce(t3.暂估金额_原币,0) 原币金额
from t6 
full join t3 on t6.编码=t3.编码 and t6.币种=t3.币种 --期末暂估
left join t4 on t6.编码=t4.编码 and t6.币种=t4.币种 --外币评估清单;
)tt)tt2
)
select * from temp_result;

-- %%%%%%%%%%%%%%%%%%%%%%%%%%往来明细表%%%%%%%%%%%%%%%%%%%%%%


--1.AP 应付账款明细表
CREATE OR REPLACE VIEW "应付账款明细表" AS
with ap_add as --科目余额表数据(应收相关调整) 
(
SELECT *,期末余额+暂估金额+总账调整暂估+负数调整+汇率调整 未审期末余额
FROM 
(
select 
科目代码 编码,
科目名称 供应商名称,
'' 试算分类,
'' 款项性质,
-1*本位币货币期初 期初余额,
0 本期增加,
-1*(本位币货币期初-本位货币期末) 本期减少,
-1*本位货币期末 期末余额,
case when 科目代码='22026000' then 本位货币期末 else 0 end 暂估金额,
case when 科目代码 in ('22029000') then 本位货币期末 else 0 end 总账调整暂估,
case when 科目代码 in ('22029900') then (select -sum(负数调整) from "应付账款明细表_temp") else 0 end 负数调整,
case when 科目代码='22028900' then 本位货币期末 else 0 end 汇率调整,
0 其他调整,
货币代码 币种,
0 原币金额
from 科目余额表
where left(科目代码,4)='2202' and substr(科目代码,5,1)>'0')t
),
final_result as 
(
select 
编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
暂估金额,总账调整暂估,负数调整,汇率调整,其他调整,未审期末余额,币种,原币金额_调整后 as 原币金额
from "应付账款明细表_temp"
union all 
select * from "应付账款明细表_空白行" --插入空行
union all 
select * from "杂费暂估" --杂费暂估
union all 
select * from "应付账款明细表_空白行" --插入空行
union all 
select * from ap_add --科目余额表数据(应收相关调整) 
union all 
select * from "预提费用" --科目余额表数据(预提费用) 
)
select * from final_result;



--2.PA预付账款  Prepaid Accounts
CREATE OR REPLACE VIEW "预付账款明细表" AS
with pre_ap as --预付账款暂时只能全放预付 其他非流动分不出来
(
select 
编码,供应商名称,试算分类,款项性质,
-1*期末余额 as 期末余额,
0 as 负数调整,
-1*暂估金额 as 暂估金额,
-1*汇率调整 as 汇率调整,
-1*其他调整 as 其他调整,
负数调整 as 预付账款,
0 as 其他非流动资产, --暂时无法区分
币种,
case when 币种='CNY' then 负数调整 else -1*原币金额_调整前 end 原币金额
from "应付账款明细表_temp" where 负数调整>0
)
select * from pre_ap;


--select * from 预付账款明细表;




--3.AR应收账款明细表
CREATE OR REPLACE VIEW "应收账款明细表" AS
with t1 as (--期初余额
select 
    科目代码,
    科目名称,
    客商代码,
    客商名称 对方单位,
    原币符号 币种,
    sum(cast(本位币余额 as decimal(19,2))) 期初余额 --负数代表本科目增加
from 往来余额
where 期间_add='last' AND  科目名称 LIKE '%应收账款%'
group by 科目代码,科目名称,客商代码,客商名称,原币符号
),
t2 as (--期末余额
select 
    科目代码,
    科目名称,
    客商代码,
    客商名称 对方单位,
    原币符号 币种,
    sum(cast(原币余额 as decimal(19,2))) 原币金额,
    sum(cast(本位币余额 as decimal(19,2))) 期末余额
from 往来余额 
where 期间_add='this' AND  科目名称 LIKE '%应收账款%'
group by 科目代码,科目名称,客商代码,客商名称,原币符号
),
t3 as (--发生额
select 
    cast(cast(科目代码 as int) as varchar) as 科目代码,
    科目名称,
    客商代码,
    客商名称 对方单位,
    原币符号 币种,
    sum(cast(本位币金额 as decimal(19,2))) RV_期末余额 --负数代表本科目增加
from 往来发生额  a 
where  科目名称 LIKE '%应收账款%' and 凭证类型 = 'RV'
group by 科目代码,科目名称,客商代码,客商名称,原币符号
),
t4 as (--汇兑调整
select 
cast(总帐帐目 as varchar) as 科目代码,
账户 as 客商代码,货币 as 币种,
sum(cast(记帐金额 as decimal(19,2))) as 汇率调整
from 外币评估清单
where 总帐帐目 in ('11220050','11220030','11220010')
and 账户 is not null
group by 总帐帐目,账户,货币
)
select 
coalesce(t1.科目代码,t2.科目代码,t3.科目代码) as 科目代码,
coalesce(t1.科目名称,t2.科目名称,t3.科目名称) as 科目名称,
coalesce(t1.客商代码,t2.客商代码,t3.客商代码) as 客商代码,
coalesce(t1.对方单位,t2.对方单位,t3.对方单位) as 对方单位,
t1.期初余额,
ifnull(t3.RV_期末余额,0) as 本期增加,
本期增加+ifnull(t1.期初余额,0)-ifnull(t2.期末余额,0) as 本期减少,
ifnull(t2.期末余额,0) as 期末余额,
ifnull(t4.汇率调整,0) as 汇率调整,
if(ifnull(t2.期末余额,0)+ifnull(t4.汇率调整,0)<0,-ifnull(t2.期末余额,0)-ifnull(t4.汇率调整,0),0) as 重分类调整,
ifnull(ifnull(t2.期末余额,0)+ifnull(t4.汇率调整,0)+if(ifnull(t2.期末余额,0)<0,-ifnull(t2.期末余额,0),0),0) as 报表金额,
coalesce(t1.币种,t2.币种,t3.币种) as 币种,
coalesce((case when 报表金额=0 then 0 else t2.原币金额 end),0) as 原币金额
from t1
full join t2
ON  t1.科目代码 = t2.科目代码
and t1.科目名称 = t2.科目名称
and t1.客商代码 = t2.客商代码
and t1.对方单位 = t2.对方单位
and t1.币种 = t2.币种
full join t3
ON  coalesce(t1.科目代码,t2.科目代码) = t3.科目代码
and coalesce(t1.科目名称,t2.科目名称) = t3.科目名称
and coalesce(t1.客商代码,t2.客商代码) = t3.客商代码
and coalesce(t1.对方单位,t2.对方单位) = t3.对方单位
and coalesce(t1.币种,t2.币种) = t3.币种
left join t4
on t1.科目代码 = t4.科目代码
and t1.客商代码 = t4.客商代码
and t1.币种 = t4.币种;

--SELECT * FROM 应收账款明细表;


--4.DR预收账款 deposits received
CREATE OR REPLACE VIEW "预收账款明细表" AS
with pre_ar as
(
select *,
round(case when 币种!='CNY' then 期末未审 else 期末未审/1.13 end,2) as 合同负债,
期末未审-合同负债 as 其他流动负债,
from
( 
select 
客商代码 客户编码,
对方单位 客户名称,
'' 关联关系,
'' "内/外销",
-1*期初余额 期初余额,
本期减少 本期增加, 
本期增加 本期减少,
-1*期末余额 期末余额,
-1*汇率调整 汇率调整,
-1*期末余额 +-1*汇率调整 期末未审,
币种 币种,
-1*原币金额 "期末余额（原币）"
from 应收账款明细表
where 重分类调整 > 0
)t 
)
select * from pre_ar;

--select * from "预收账款明细表";



--5.OAR其他应收款
CREATE OR REPLACE VIEW "其他应收款明细表" AS
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
SELECT * FROM oar_f;

--select * from "其他应收款明细表";


--6.OAP其他应付款
CREATE OR REPLACE VIEW "其他应付款明细表" AS
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
SELECT * FROM oap_f;

--select * from "其他应付款明细表";


-- ##################外币倒轧#############################

--1."应付账款明细表-外币倒轧_temp"
CREATE OR REPLACE VIEW "应付账款明细表-外币倒轧_temp" AS
WITH t1 AS 
(
SELECT 
编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
暂估金额,总账调整暂估,负数调整,
CASE WHEN 币种 !='CNY' THEN round(原币金额_调整前*b.汇率,2)-未审期末余额  ELSE 汇率调整 END AS 汇率调整,
其他调整,
CASE WHEN 币种 !='CNY' THEN round(原币金额_调整前*b.汇率,2) ELSE 未审期末余额 END as 未审期末余额,币种,原币金额_调整前
FROM "应付账款明细表_temp" a
LEFT JOIN 汇率表 b 
ON a.币种=b.货币缩写
)
SELECT 
编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
暂估金额,总账调整暂估,负数调整,汇率调整,其他调整,未审期末余额,币种,
case when 未审期末余额=0 then 0 else 原币金额_调整前 end as 原币金额,
原币金额_调整前
FROM t1;

--1."应付账款明细表-外币倒轧"
CREATE OR REPLACE VIEW "应付账款明细表-外币倒轧" AS
WITH ap_add as --科目余额表数据(应收相关调整) 
(
SELECT *,期末余额+暂估金额+总账调整暂估+负数调整+汇率调整 未审期末余额
FROM 
(
select 
科目代码 编码,
科目名称 供应商名称,
'' 试算分类,
'' 款项性质,
-1*本位币货币期初 期初余额,
0 本期增加,
-1*(本位币货币期初-本位货币期末) 本期减少,
-1*本位货币期末 期末余额,
case when 科目代码='22026000' then 本位货币期末 else 0 end 暂估金额,
case when 科目代码 in ('22029000') then 本位货币期末 else 0 end 总账调整暂估,
case when 科目代码 in ('22029900') then (select -sum(负数调整) from "应付账款明细表_temp") else 0 end 负数调整,
case when 科目代码='22028900' then 本位货币期末 else 0 end 汇率调整,
0 其他调整,
货币代码 币种,
0 原币金额
from 科目余额表
where left(科目代码,4)='2202' and substr(科目代码,5,1)>'0'
)t
),
final_result as 
(
SELECT 编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
暂估金额,总账调整暂估,负数调整,汇率调整,其他调整,未审期末余额,币种,原币金额 from "应付账款明细表-外币倒轧_temp"
union all 
select * from "应付账款明细表_空白行" --插入空行
union all 
select * from "杂费暂估" --杂费暂估
union all 
select * from "应付账款明细表_空白行" --插入空行
union all 
select * from ap_add --科目余额表数据(应收相关调整) 
union all 
select * from "预提费用" --科目余额表数据(预提费用) 
)
select * from final_result;








--2."应收账款明细表-外币倒轧"
CREATE OR REPLACE VIEW "应收账款明细表-外币倒轧" AS
with t1 as 
(
select t.科目代码,t.科目名称,t.客商代码,t.对方单位,t.期初余额,t.本期增加,t.本期减少,t.期末余额,
	t1.汇率 as 汇率,
	case when 币种!='CNY' then cast(原币金额*汇率-t.期末余额 as decimal(19,2)) else 0 end as 汇率调整,
	case when 币种!='CNY' then if(cast(原币金额*汇率 as decimal(19,2))<0,-1*cast(原币金额*汇率 as decimal(19,2)),0)
    else if(t.期末余额<0,-1*t.期末余额,0) end as 重分类调整,
	case when 币种!='CNY' then cast(原币金额*汇率 as decimal(19,2)) else 
    if(t.期末余额<0,0,t.期末余额) end as 报表金额,
    t.币种,
    case when 报表金额<0 then 0 else t.原币金额 end as 原币金额,
    t.原币金额 as 原币金额_调整前
from 应收账款明细表 t
left join 汇率表 t1
on t.币种 = t1.货币缩写
)
select 科目代码,科目名称,客商代码,对方单位,期初余额,本期增加,本期减少,期末余额,
汇率,汇率调整,重分类调整,报表金额,币种,原币金额 from t1;


-- "应收账款明细表-外币倒轧_temp"
CREATE OR REPLACE VIEW "应收账款明细表-外币倒轧_temp" AS
with t1 as 
(
select t.科目代码,t.科目名称,t.客商代码,t.对方单位,t.期初余额,t.本期增加,t.本期减少,t.期末余额,
	t1.汇率 as 汇率,
	case when 币种!='CNY' then cast(原币金额*汇率-t.期末余额 as decimal(19,2)) else 0 end as 汇率调整,
	case when 币种!='CNY' then if(cast(原币金额*汇率 as decimal(19,2))<0,-1*cast(原币金额*汇率 as decimal(19,2)),0)
    else if(t.期末余额<0,-1*t.期末余额,0) end as 重分类调整,
	case when 币种!='CNY' then cast(原币金额*汇率 as decimal(19,2)) else 
    if(t.期末余额<0,0,t.期末余额) end as 报表金额,
    t.币种,
    case when 报表金额<0 then 0 else t.原币金额 end as 原币金额,
    t.原币金额 as 原币金额_调整前
from 应收账款明细表 t
left join 汇率表 t1
on t.币种 = t1.货币缩写
)
select * from t1;



--3."预付账款明细表-外币倒轧"
CREATE OR REPLACE VIEW "预付账款明细表-外币倒轧" AS
with pre_ap as --预付账款暂时只能全放预付 其他非流动分不出来
(
select 
编码,供应商名称,试算分类,款项性质,
-1*期初余额 as 期初余额,
-1*本期减少 as 本期增加,
-1*本期增加 as 本期减少,
-1*期末余额 as 期末余额,
负数调整 as 预付账款,
0 as 其他非流动资产, --暂时无法区分
币种,
case when 币种='CNY' then 负数调整 else -1*原币金额_调整前 end 原币金额
from "应付账款明细表-外币倒轧_temp" where 负数调整>0
)
select * from pre_ap;



--4."预收账款明细表-外币倒轧"
CREATE OR REPLACE VIEW "预收账款明细表-外币倒轧" AS
with pre_ar as
(
select *,
round(case when 币种!='CNY' then 期末未审 else 期末未审/1.13 end,2) as 合同负债,
期末未审-合同负债 as 其他流动负债,
from 
(
select 
客商代码 客户编码,
对方单位 客户名称,
'' 关联关系,
'' "内/外销",
-1*期初余额 期初余额,
本期减少 本期增加, 
本期增加 本期减少,
-1*期末余额 期末余额,
-1*汇率调整 汇率调整,
-1*期末余额 +-1*汇率调整 期末未审,
币种 币种,
-1*原币金额_调整前 "期末余额（原币）"
from "应收账款明细表-外币倒轧_temp"
where 重分类调整 > 0)t
)
select * from pre_ar;

