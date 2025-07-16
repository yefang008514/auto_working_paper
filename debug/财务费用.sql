SELECT 
科目代码,科目名称,sum(本位币货币期初),sum(本位货币期末)
FROM 科目余额表
where 科目名称 like '%财务费用%' 
group by 科目代码,科目名称
--6603 开头