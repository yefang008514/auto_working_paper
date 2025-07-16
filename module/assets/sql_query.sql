

-- "无形资产明细表"
CREATE OR REPLACE VIEW "无形资产明细表" AS
WITH 
无形资产 AS (
      SELECT
        主资产号 as 现资产号
        ,(case when 资产类别 = 'Z800' then '土地' 
              when 资产类别 = 'Z810' then '海域使用权' 
              when 资产类别 = 'Z820' then '商标' 
              when 资产类别 = 'Z830' then '软件' 
              when 资产类别 = 'Z840' then '专利技术' 
              when 资产类别 = 'Z850' then '非专利技术' 
              when 资产类别 = 'Z860' then '特许权' 
              end) as 类别  
        ,固定资产名称 as 资产描述
        ,MAX(CASE WHEN 期间_add = 'this' THEN 开始使用日期 END) AS 资本化日期
        ,MAX(CASE WHEN 期间_add = 'last' THEN 原值 END) AS 期初余额_原值
        ,MAX(CASE WHEN 期间_add = 'last' THEN ABS(累计折旧) END) AS 期初余额_累计
        ,MAX(CASE WHEN 期间_add = 'this' THEN ABS(累计折旧) END)-MAX(CASE WHEN 期间_add = 'last' THEN ABS(累计折旧) END) AS 计提折旧
        ,"折旧年限(月份)"  as 摊销期限（月）                           
    from 
    固定资产清单
    WHERE SUBSTRING(资产类别, 1, 2) = 'Z8'
    group by 主资产号,固定资产名称,资产类别,"折旧年限(月份)"
),
购置数据 AS (
  SELECT 
  	资产,
    SUM(公司代码货币价值) AS 购置
  FROM 固定资产_发生额
  WHERE 
    总账科目 LIKE '%1701%' 
    AND 冲销关于 IS NULL
    group by 资产
)
SELECT 
  a.现资产号
  ,a.类别
  ,a.资产描述
  ,a.资本化日期
  ,a.期初余额_原值
  ,a.期初余额_累计
  ,a.计提折旧
  ,a.摊销期限（月）
  ,b.购置
FROM 无形资产 as a 
left join 购置数据 as b 
on a.现资产号 = b.资产;