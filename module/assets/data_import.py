import pandas as pd
import duckdb
from multiprocessing.dummy import Pool as ThreadPool
import os,sys
sys.path.append(os.getcwd())
from typing import Dict, Tuple
import pathlib

#往来科目明细表所需数据
# (后期代码会整合到一起一次性出 应收应付 预收预付 其他应收应付的所有底稿)

# 应付账款 
# 1.ZFI022 本期余额 
# 2.ZFI022 上期余额 
# 3.ZFI022 本期报废余额 
# 4.ZFI022 上期报废余额
# 5.FBL3H 本期发生额 
# 6.科目余额表 
# 7.数据库 



# 常量定义（使用大写命名）案例来自3020-重庆氨纶 FY24 
PATHS_AP = {
    'ZFI022_THIS': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\长期资产基础数据\3020-重庆氨纶\ZFI022-3020_截止到2412.XLSX",
    'ZFI022_LAST': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\长期资产基础数据\3020-重庆氨纶\ZFI022-3020_截止到2312.XLSX",
    'ZFI022_THIS_SCRAP': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\长期资产基础数据\3020-重庆氨纶\ZFI022-报废-3020_截止到2412.XLSX",
    'ZFI022_LAST_SCRAP': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\长期资产基础数据\3020-重庆氨纶\ZFI022-报废-3020_截止到2312.XLSX",
    'FBL3H_OCCUR':r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\长期资产基础数据\3020-重庆氨纶\FBL3H_全部项(1521-1801).XLSX",
    'TB': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\财务报表基础数据\3020-重庆氨纶\科目余额表.XLSX",
    'DB': r"D:\audit_project\DEV\auto_workingpaper\test\test_assets.duckdb"
}


# 列类型预定义（根据实际业务调整）
ZFI022_NOT_SCRAP = { #非报废资产清单
        '公司代码':object,
        '主资产号':object,
        '资产使用部门':object,
        '固定资产实物编号':object
    }

ZFI022_SCRAP = { #报废资产清单
        '公司代码':object,
        '主资产号':object,
        '资产使用部门':object,
        '固定资产实物编号':object,
        '开始使用日期':object,
        '注销日期':object
    }

DTYPE_MAPPING = {
    'ZFI022_THIS': ZFI022_NOT_SCRAP,
    'ZFI022_LAST': ZFI022_NOT_SCRAP,
    'ZFI022_THIS_SCRAP': ZFI022_SCRAP,
    'ZFI022_LAST_SCRAP': ZFI022_SCRAP,
    'FBL3H_OCCUR': {
        '公司代码':object,
        '凭证编号':object,
        '资产':object,
        '总账科目':object,
        '冲销关于':object
    },
    'TB':{
        '科目代码':object
    }
}

# 必要列和标准列定义
ZFI022_THIS_MUST_COLS = [ #ZFI022本年余额
    '公司代码',
    '主资产号',
    '资产类别',
    '固定资产名称',
    '规格型号',
    '开始使用日期',
    '原值',
    '累计折旧',
    '折旧年限(月份)',
    '已折旧年限(月份)'
    ]

ZFI022_THIS_STANDARD_COLS = ZFI022_THIS_MUST_COLS

ZFI022_LAST_MUST_COLS = ZFI022_THIS_MUST_COLS #ZFI022上年余额

ZFI022_LAST_STANDARD_COLS = ZFI022_THIS_MUST_COLS

ZFI022_THIS_SCRAP_MUST_COLS = [ #ZFI022本年报废余额
    '公司代码',
    '主资产号',
    '资产类别',
    '固定资产名称',
    '规格型号',
    '开始使用日期',
    '原值',
    '累计折旧',
    '折旧年限(月份)',
    '已折旧年限(月份)',
    '注销日期'
]
ZFI022_THIS_SCRAP_STANDARD_COLS = ZFI022_THIS_SCRAP_MUST_COLS

ZFI022_LAST_SCRAP_MUST_COLS = ZFI022_THIS_SCRAP_MUST_COLS #ZFI022上年报废余额
ZFI022_LAST_SCRAP_STANDARD_COLS = ZFI022_THIS_SCRAP_MUST_COLS

FBL3H_OCCUR_MUST_COLS = [  #FBL3H发生额
    '公司代码',
    '财年',
    '记帐期间',
    '过帐日期',
    '凭证编号',
    '凭证类型',
    '总账科目',
    '总账科目：短文本',
    '借/贷标识',
    '公司代码货币代码',
    '公司代码货币价值',
    '文本',
    '冲销关于',
    '资产',
    '事务代码',
    '参考过程',
    '事务类型'
]
FBL3H_OCCUR_STANDARD_COLS = [
    '公司代码',
    '财年',
    '记帐期间',
    '过帐日期',
    '凭证编号',
    '凭证类型',
    '总账科目',
    '总账科目：短文本',
    '借贷标识',
    '公司代码货币代码',
    '公司代码货币价值',
    '文本',
    '冲销关于',
    '资产',
    '事务代码',
    '参考过程',
    '事务类型'
]

TB_MUST_COLS = None #科目余额表
TB_STANDARD_COLS = TB_MUST_COLS



# 列映射定义
COL_MAPPING = {
    'ZFI022_THIS': { 
    'must_col':ZFI022_THIS_MUST_COLS,
    'standard_col':ZFI022_THIS_STANDARD_COLS
    },
    'ZFI022_LAST': {
    'must_col':ZFI022_LAST_MUST_COLS,
    'standard_col':ZFI022_LAST_MUST_COLS
    },
    'ZFI022_THIS_SCRAP':{
    'must_col':ZFI022_THIS_SCRAP_MUST_COLS,
    'standard_col':ZFI022_THIS_SCRAP_STANDARD_COLS
    },
    'ZFI022_LAST_SCRAP': { 
    'must_col':ZFI022_LAST_SCRAP_MUST_COLS,
    'standard_col':ZFI022_LAST_SCRAP_STANDARD_COLS
    },
    'FBL3H_OCCUR': {
    'must_col':FBL3H_OCCUR_MUST_COLS,
    'standard_col':FBL3H_OCCUR_STANDARD_COLS
    },
    'TB':{
    'must_col':TB_MUST_COLS,
    'standard_col':TB_STANDARD_COLS
    }
}

#表头起始行
HEADER_MAPPING = {
    'ZFI022_THIS': 0,
    'ZFI022_LAST': 0,
    'ZFI022_THIS_SCRAP': 0,
    'ZFI022_LAST_SCRAP': 0,
    'FBL3H_OCCUR': 0,
    'TB': 0
}


#参数表
# 直接构建符合函数要求的字典结构
AP_dict = {
    task_name: {
        'path': PATHS_AP[task_name],
        'must_col': COL_MAPPING[task_name]['must_col'],
        'standard_col': COL_MAPPING[task_name]['standard_col'], 
        'dtype_dict': DTYPE_MAPPING[task_name],
        'header':HEADER_MAPPING[task_name]
    }
    for task_name in PATHS_AP.keys() if task_name != 'DB'
}

# 这样可以直接传入read_data_parallel函数




#######################模块一、读数据####################
def read_data(path,must_col=None,standard_col=None,dtype_dict=None,header=None):
    '''
    读取excel数据，并转换为标准格式
    path:excel文件路径
    must_col:需要保留的列
    standard_col:标准列名
    dtype_dict:数据类型字典 主要是需要存成字符串的列
    '''
    #读取excel文件
    if header is None:
        header=0
    else:
        pass
    df=pd.read_excel(path,sheet_name=0,dtype=dtype_dict,engine='calamine',header=header)#sheet_name=0 默认读第1个sheeet

    #去除df表头字段前后的空值
    temp_col=df.columns.tolist()
    df.columns=[str(col).strip() for col in temp_col]

    #若无must_col和standard_col，则默认取所有列
    if must_col is None or standard_col is None:
        result=df.copy()
    else:
        mapping_dict=dict(zip(must_col,standard_col))
        result=df[must_col].copy()
        result.rename(columns=mapping_dict,inplace=True)

    return result


#并行读取数据
def read_data_parallel(file_info: Dict[str, Dict]) -> Dict[str, pd.DataFrame]:
    """
    并行读取Excel文件并执行标准化处理
    :param file_info: 文件信息字典 {
        '任务名': {
            'path': 文件路径,
            'must_col': 必须列列表,
            'standard_col': 标准列名列表,
            'dtype_dict': 数据类型字典
        }
    }
    :return: 包含所有标准化DataFrame的字典 {任务名: DataFrame}
    """
    def _read_and_process(args):
        """内部函数，用于单个文件的读取和处理"""
        task_name, info = args
        try:
            # 调用read_data函数处理单个文件
            df = read_data(
                path=info['path'],
                must_col=info.get('must_col'),
                standard_col=info.get('standard_col'),
                dtype_dict=info.get('dtype_dict'),
                header=info.get('header')
            )
            return task_name, df
        except Exception as e:
            print(f"处理文件 {info['path']} 时出错: {str(e)}")
            return task_name, None

    # 设置线程池大小 不大于文件列表长度
    max_workers = min(os.cpu_count() - 2, len(file_info))
    results = {}
    
    # 准备参数列表 [(任务名, 文件信息字典), ...]
    args_list = [(k, v) for k, v in file_info.items()]
    
    # 使用线程池并行处理
    with ThreadPool(max_workers) as pool:
        for task_name, df in pool.imap(_read_and_process, args_list):
            if df is not None:
                results[task_name] = df
    
    return results


#########################模块二、清洗#########################
def clean_data(file_info: Dict[str, Dict])-> Dict[str, pd.DataFrame]:
    '''
    清洗各类数据
    # 1.ZFI022 本期余额 
    # 2.ZFI022 上期余额 
    # 3.ZFI022 本期报废余额 
    # 4.ZFI022 上期报废余额
    # 5.FBL3H 本期发生额 
    # 6.科目余额表 
    # 7.数据库
    '''
    result = {}

    df_zfi022_this = file_info['ZFI022_THIS']
    df_zfi022_last = file_info['ZFI022_LAST']

    df_zfi022_this_scrap = file_info['ZFI022_THIS_SCRAP']
    df_zfi022_last_scrap = file_info['ZFI022_LAST_SCRAP']

    df_occur = file_info['FBL3H_OCCUR']
    

    #1.合并df_zfi022_this和df_zfi022_last  到df_balance 固定资产清单
    df_zfi022_this['期间_add']='this'
    df_zfi022_last['期间_add']='last'

    df_balance=pd.concat([df_zfi022_this,df_zfi022_last],ignore_index=True)
    result['固定资产清单']=df_balance

    # 2.合并df_zfi022_this_scrap、df_fbl5h_occur 到df_balance_scrap 固定资产清单_报废
    df_zfi022_this_scrap['期间_add']='this'
    df_zfi022_last_scrap['期间_add']='last'

    df_balance_scrap=pd.concat([df_zfi022_this_scrap,df_zfi022_last_scrap],ignore_index=True).copy()
    result['固定资产清单_报废']=df_balance_scrap

    #3.处理FBL3H
    df_occur['id']=df_occur.index #添加id列
    result['固定资产_发生额']=df_occur

    #4.处理科目余额表
    try:
        df_tb = file_info['TB']
        df_tb['科目代码']=df_tb['科目代码'].astype(str).apply(lambda x:x[2:])
        result['科目余额表']=df_tb
    except:
        pass

    return result



################################模块三、主函数##########################################
def main(PATHS=None):

    if PATHS is None:
        config_dict = AP_dict
        PATHS=PATHS_AP
    else:
        #对字符串元素清洗前后引号
        PATHS = {k:v[1:-1] if type(v)==str and (v[0]=="'" or v[0]=='"') else v for k,v in PATHS.items()} #清洗前后引号
        config_dict = {
            task_name: {
                'path': PATHS[task_name],
                'must_col': COL_MAPPING[task_name]['must_col'],
                'standard_col': COL_MAPPING[task_name]['standard_col'], 
                'dtype_dict': DTYPE_MAPPING[task_name],
                'header':HEADER_MAPPING[task_name]
            }
            for task_name in PATHS.keys() if task_name != 'DB'
        }

    #1. 读取原始数据
    raw_data_dict = read_data_parallel(file_info=config_dict)

    # 2. 清洗数据
    result=clean_data(file_info=raw_data_dict)

    #写入数据
    def write_2_duckdb(con,data,table_name):
        df=data.copy()
        con.sql(f'''drop table if exists {table_name}''')
        con.sql(f'''create table {table_name} as select * from df''')

    # 3. 写入数据库
    with duckdb.connect(PATHS['DB']) as con:

        df_balance = result['固定资产清单']
        df_balance_scrap = result['固定资产清单_报废']
        df_occur = result['固定资产_发生额']

        write_2_duckdb(con,df_balance,'固定资产清单')
        write_2_duckdb(con,df_balance_scrap,'固定资产清单_报废')
        write_2_duckdb(con,df_occur,'固定资产_发生额')

        try:
            df_tb = result['科目余额表']
            write_2_duckdb(con,df_tb,'科目余额表')
        except:
            pass

        #数值转换
        con.sql('''
                
        alter table 固定资产清单 alter column 主资产号 type varchar;
        alter table 固定资产清单 alter column 开始使用日期 type varchar;
        alter table 固定资产清单 alter column 原值 type decimal(19,2);
        alter table 固定资产清单 alter column 累计折旧 type decimal(19,2);   
        
        alter table 固定资产清单_报废 alter column 主资产号 type varchar;
        alter table 固定资产清单_报废 alter column 开始使用日期 type varchar;
        alter table 固定资产清单_报废 alter column 原值 type decimal(19,2); 
        alter table 固定资产清单_报废 alter column 累计折旧 type varchar;
                
        alter table 固定资产_发生额 alter column 公司代码货币价值 type decimal(19,2);
        alter table 固定资产_发生额 alter column 凭证编号 type varchar;
        alter table 固定资产_发生额 alter column 冲销关于 type varchar;
        alter table 固定资产_发生额 alter column 资产 type varchar;
                
        ''')

        try:
            con.sql('''        
            alter table 科目余额表 alter column 科目代码 type varchar;        
            alter table 科目余额表 alter column 外币期初 type decimal(19,2);
            alter table 科目余额表 alter column 外币借方 type decimal(19,2);
            alter table 科目余额表 alter column 外币贷方 type decimal(19,2);
            alter table 科目余额表 alter column 外币期末 type decimal(19,2);
                    
            alter table 科目余额表 alter column 本位币货币期初 type decimal(19,2);
            alter table 科目余额表 alter column 本位货币借方 type decimal(19,2);
            alter table 科目余额表 alter column 本位货币贷方 type decimal(19,2);
            alter table 科目余额表 alter column 本位货币期末 type decimal(19,2);  
            ''')
        except:
            pass

        sql_file_path = os.path.join(os.path.dirname(__file__), 'sql_query.sql')

        #添加视图
        with open(sql_file_path, "r", encoding="utf-8") as f:
            str_sql = f.read()
        con.sql(str_sql)

        

if __name__ == '__main__':

    # 添加简单耗时统计
    import time
    start = time.time()
    main()
    print(f"执行完成，耗时: {time.time()-start:.2f}秒")


    # 调试单个文件
    # read_data_parallel({'FOREIGN_CURRENCY':AP_dict['FOREIGN_CURRENCY']})
