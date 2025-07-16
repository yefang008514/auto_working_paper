-- %%%%%%%%%%%AP adj%%%%%%%%%%%%%%

-- "应付账款明细表_调整后_temp"
CREATE OR REPLACE VIEW "应付账款明细表_调整后_temp" AS
with t1 as
(
    select 
    编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
    暂估金额,
    总账调整暂估,
    负数调整,--详见temp3
    汇率调整,
    其他调整,
    未审期末余额,--详见temp3
    币种,
    case when 未审期末余额=0 then 0 else 原币金额 end as 原币金额,
    原币金额 as 原币金额_调整前
    from 
    (
        select *,
        case when (期末余额+暂估金额+汇率调整+总账调整暂估+其他调整)<0 then -1*(期末余额+暂估金额+汇率调整+总账调整暂估+其他调整) else 0 end as 负数调整,
        期末余额+暂估金额+总账调整暂估+负数调整+汇率调整+其他调整 as 未审期末余额
        from 
        (
            select
            a.编码,a.供应商名称,a.试算分类,a.款项性质,a.期初余额,
            a.本期增加,
            case when c.调整金额 is not null then a.本期减少+c.调整金额 else a.本期减少 end 本期减少,
            case when c.调整金额 is not null then a.期末余额-c.调整金额 else a.期末余额 end 期末余额,
            case when c.调整金额 is not null then c.调整金额 else a.暂估金额 end 暂估金额,
            case when b.调整金额 is not null then b.调整金额 else a.总账调整暂估 end 总账调整暂估,
            a.汇率调整,
            case when d.调整金额 is not null then d.调整金额 else a.其他调整 end 其他调整,
            a.币种,
            a.原币金额_调整前 原币金额
            from "应付账款明细表_temp" a 
            left join 总账调整_应付账款 b on a.编码=b.编码 and a.币种=b.币种 
            left join 工程类暂估调整_应付账款 c on a.编码=c.编码 and a.币种=c.币种 
            left join 返利调整_应付账款 d on a.编码=d.编码 and a.币种=d.币种
    	)temp2
    )temp3
)
select * from t1;



--非倒轧逻辑 调整后
CREATE OR REPLACE VIEW "应付账款明细表_调整后" AS
with ap_add as --科目余额表数据(应付相关调整) 
(
select 
科目代码 编码,
科目名称 供应商名称,
'' 试算分类,
'' 款项性质,
-1*本位币货币期初 期初余额,
0 本期增加,
-1*(本位币货币期初-本位货币期末) 本期减少, -- 本期减少倒轧
-1*本位货币期末 期末余额,
case when 科目代码='22026000' then 本位货币期末 else 0 end 暂估金额,
case when 科目代码 in ('22029000') then 本位货币期末 else 0 end 总账调整暂估,
case when 科目代码 in ('22029900') then (select -sum(负数调整) from 应付账款明细表_调整后_temp) else 0 end 负数调整,
case when 科目代码='22028900' then 本位货币期末 else 0 end 汇率调整,
0 其他调整,
0 未审期末余额,
货币代码 币种,
0 原币金额
from 科目余额表
where left(科目代码,4)='2202' and substr(科目代码,5,1)>'0'
),
final_result as 
(
SELECT 编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
暂估金额,总账调整暂估,负数调整,汇率调整,其他调整,未审期末余额,币种,原币金额 FROM 应付账款明细表_调整后_temp
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


CREATE OR REPLACE VIEW "应付账款明细表-外币倒轧_调整后_temp" AS
with t1 as
(
    select 
    编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
    暂估金额,
    总账调整暂估,
    负数调整,--详见temp3
    汇率调整,
    其他调整,
    未审期末余额,--详见temp3
    币种,
    case when 未审期末余额=0 then 0 else 原币金额 end as 原币金额,
    原币金额 as 原币金额_调整前
    from 
    (
        select *,
        case when (期末余额+暂估金额+汇率调整+总账调整暂估+其他调整)<0 then -1*(期末余额+暂估金额+汇率调整+总账调整暂估+其他调整) else 0 end as 负数调整,
        期末余额+暂估金额+总账调整暂估+负数调整+汇率调整+其他调整 as 未审期末余额
        from 
        (
            select
            a.编码,a.供应商名称,a.试算分类,a.款项性质,a.期初余额,
            a.本期增加,
            case when c.调整金额 is not null then a.本期减少+c.调整金额 else a.本期减少 end 本期减少,
            case when c.调整金额 is not null then a.期末余额-c.调整金额 else a.期末余额 end 期末余额,
            case when c.调整金额 is not null then c.调整金额 else a.暂估金额 end 暂估金额,
            case when b.调整金额 is not null then b.调整金额 else a.总账调整暂估 end 总账调整暂估,
            a.汇率调整,
            case when d.调整金额 is not null then d.调整金额 else a.其他调整 end 其他调整,
            a.币种,
            a.原币金额_调整前 原币金额
            from "应付账款明细表-外币倒轧_temp" a 
            left join 总账调整_应付账款 b on a.编码=b.编码 and a.币种=b.币种 
            left join 工程类暂估调整_应付账款 c on a.编码=c.编码 and a.币种=c.币种 
            left join 返利调整_应付账款 d on a.编码=d.编码 and a.币种=d.币种
    	)temp2
    )temp3
)
select * from t1;


--"应付账款明细表-外币倒轧_调整后"
CREATE OR REPLACE VIEW "应付账款明细表-外币倒轧_调整后" AS
with ap_add as --科目余额表数据(应付相关调整) 
(
select 
科目代码 编码,
科目名称 供应商名称,
'' 试算分类,
'' 款项性质,
-1*本位币货币期初 期初余额,
0 本期增加,
-1*(本位币货币期初-本位货币期末) 本期减少, -- 本期减少倒轧
-1*本位货币期末 期末余额,
case when 科目代码='22026000' then 本位货币期末 else 0 end 暂估金额,
case when 科目代码 in ('22029000') then 本位货币期末 else 0 end 总账调整暂估,
case when 科目代码 in ('22029900') then (select -sum(负数调整) from "应付账款明细表-外币倒轧_调整后_temp") else 0 end 负数调整,
case when 科目代码='22028900' then 本位货币期末 else 0 end 汇率调整,
0 其他调整,
0 未审期末余额,
货币代码 币种,
0 原币金额
from 科目余额表
where left(科目代码,4)='2202' and substr(科目代码,5,1)>'0'
),
final_result as 
(
SELECT 编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,
暂估金额,总账调整暂估,负数调整,汇率调整,其他调整,未审期末余额,币种,原币金额 FROM "应付账款明细表-外币倒轧_调整后_temp"
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


--"预付账款明细表_调整后"
CREATE OR REPLACE VIEW "预付账款明细表_调整后" AS
with pre_ap as --预付账款暂时只能全放预付 其他非流动分不出来
(
select 
编码,供应商名称,试算分类,款项性质,
-1*期初余额 as 期初余额,
-1*本期减少 as 本期增加,
-1*本期增加 as 本期减少,
-1*期末余额 as 期末余额,
0 as 负数调整,
-1*暂估金额 as 暂估金额,
-1*汇率调整 as 汇率调整,
-1*其他调整 as 其他调整,
负数调整 as 预付账款,
0 as 其他非流动资产, --暂时无法区分
币种,
case when 币种='CNY' then 负数调整 else -1*原币金额_调整前 end 原币金额
from "应付账款明细表_调整后_temp" where 负数调整>0
)
select * from pre_ap;



--"预付账款明细表-外币倒轧_调整后"
CREATE OR REPLACE VIEW "预付账款明细表-外币倒轧_调整后" AS
with pre_ap as --预付账款暂时只能全放预付 其他非流动分不出来
(
select 
编码,供应商名称,试算分类,款项性质,
-1*期初余额 as 期初余额,
-1*本期减少 as 本期增加,
-1*本期增加 as 本期减少,
-1*期末余额 as 期末余额,
0 as 负数调整,
-1*暂估金额 as 暂估金额,
-1*汇率调整 as 汇率调整,
-1*其他调整 as 其他调整,
负数调整 as 预付账款,
0 as 其他非流动资产, --暂时无法区分
币种,
case when 币种='CNY' then 负数调整 else -1*原币金额_调整前 end 原币金额
from "应付账款明细表-外币倒轧_调整后_temp" where 负数调整>0
)
select * from pre_ap;




