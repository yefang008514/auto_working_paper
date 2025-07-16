import duckdb
import pandas as pd 
from multiprocessing.dummy import Pool as ThreadPool
import os,sys
sys.path.append(os.getcwd())
from typing import Dict, Tuple



# 常量定义（使用大写命名）
PATHS_AP = {
    'FBL3H_THIS': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\费用基础数据\1100-华峰化学\华峰化学1100费用明细-FBL3H-2024.XLSX",
    'TB': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\费用基础数据\1100-华峰化学\华峰化学1100科目余额.XLSX",
    'DB': r"D:\audit_project\DEV\auto_workingpaper\test\test_costs.duckdb"
}



# 列类型预定义（根据实际业务调整）
DTYPE_MAPPING = {
# 数值格式的用字符串新式读取，金额不要
    'FBL3H_THIS': {
        '输入日期':object,
        '记账期间':object,
        '凭证编号':object,
        '总账科目':object
    },
    'TB':{
        '科目代码':object
    }
}

# 必要列和标准列定义
FBL3H_REMAIN_MUST_COLS = [ #FBL3H费用明细
    '输入日期',
    '记帐期间',
    '凭证编号',
    '总账科目',
    '总账科目：短文本',
    '公司代码货币价值',
    '文本',
    '功能范围：文本'
    ]
FBL3H_REMAIN_STANDARD_COLS = [
        '输入日期',
        '记帐期间',
        '凭证编号',
        '总账科目编码',
        '总账科目名称',
        '公司代码货币价值',
        '文本',
        '功能范围',
        ]

TB_MUST_COLS = None #科目余额表
TB_STANDARD_COLS = TB_MUST_COLS

# 列映射定义
COL_MAPPING = {
    'FBL3H_THIS': { 
    'must_col':FBL3H_REMAIN_MUST_COLS,
    'standard_col':FBL3H_REMAIN_STANDARD_COLS
    },
    'TB':{
    'must_col':TB_MUST_COLS,
    'standard_col':TB_STANDARD_COLS
    },

}

HEADER_MAPPING = {
    'FBL3H_THIS': 0,
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

    # 设置线程池大小
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
def clean_data(file_info: Dict[str, pd.DataFrame]) -> Dict[str, pd.DataFrame]:

    result={}
    #取数据
    df_occur = file_info['FBL3H_THIS']
    
    #1.处理费用发生额
    df_occur = df_occur[df_occur['总账科目编码'].notnull()]
    result['费用发生额']=df_occur
    
    #2.处理科目余额表
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

        df_occur = result['费用发生额']
        try:
            df_tb = result['科目余额表']
        except:
            pass

        write_2_duckdb(con,df_occur,'费用发生额')
        try:
            write_2_duckdb(con,df_tb,'科目余额表')
        except:
            pass

        con.sql('''
        alter table 费用发生额 alter column 公司代码货币价值 type decimal(19,2);
        alter table 费用发生额 alter column 记帐期间 type varchar;
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



if __name__ == '__main__':

    import time
    start = time.time()
    main()
    print(f"执行完成，耗时: {time.time()-start:.2f}秒")