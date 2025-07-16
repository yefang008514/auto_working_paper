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
原币金额
from
(
select *,
case when (期末余额+暂估金额)<0 then -1*(期末余额+暂估金额) else 0 end as 负数调整, --负数调整需要考虑暂估
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
),
final_result as 
(
select 编码,供应商名称,试算分类,款项性质,期初余额,本期增加,本期减少,期末余额,暂估金额,
总账调整暂估,负数调整,汇率调整,其他调整,未审期末余额,币种,
case when 原币金额
from temp_result
union all 
select 
科目代码 编码,
科目名称 供应商名称,
'' 试算分类,
'' 款项性质,
-1*本位币货币期初 期初余额,
本位货币贷方 本期增加,
本位货币借方 本期减少,
-1*本位货币期末 期末余额,
case when 科目代码='22026000' then 本位货币期末 else 0 end 暂估金额,
case when 科目代码 in ('22029000') then 本位货币期末 else 0 end 总账调整暂估,
case when 科目代码 in ('22029900') then (select -sum(负数调整) from temp_result) else 0 end 负数调整,
case when 科目代码='22028900' then 本位货币期末 else 0 end 汇率调整,
0 其他调整,
0 未审期末余额,
货币代码 币种,
0 原币金额
from 科目余额表
where left(科目代码,4)='2202' and substr(科目代码,5,1)>'0'
)
select * from final_result
where 未审期末余额=0

--    select * from temp_result where 编码='20000185'; debug用
--    select * from t3 where 编码='20000185'; debug用