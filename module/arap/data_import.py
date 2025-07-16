from jinja2 import pass_environment
import pandas as pd
import duckdb
from multiprocessing.dummy import Pool as ThreadPool
import os,sys
sys.path.append(os.getcwd())
from module.arap.exchange_rate import get_excahnge_rate_by_date
from typing import Dict, Tuple
import pathlib

#往来科目明细表所需数据
# (后期代码会整合到一起一次性出 应收应付 预收预付 其他应收应付的所有底稿)

# 应付账款
# 1.FBL1H 本期余额 
# 2.FBL1H 上期余额 
# 3.FBL1H 本期发生额 
# 4.FBL5H 本期余额
# 5.FBL5H 上期余额
# 6.FBL5H 本期发生额
# 7.ZFI072N 本期暂估
# 8.外币评估清单
# 9.科目余额表
# 10. 数据库



# 常量定义（使用大写命名）案例来自1100-华峰化学 FY24 
PATHS_AP = {
    'FBL1H_THIS': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_未清项_1100_2024.XLSX",
    'FBL1H_LAST': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_未清项_1100_2023.XLSX",
    'FBL1H_OCCUR': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_全部项_1100_2024.XLSX",
    'FBL5H_THIS':r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-未清项-2024-YAM1.XLSX",
    'FBL5H_LAST':r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-未清项-2023-YAM1.XLSX",
    'FBL5H_OCCUR':r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-全部项-2024-YAM.XLSX",
    'ZFI072N_THIS': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\ZFI072N_应付暂估_1100_含月返_2024.XLSX",
    'FOREIGN_CURRENCY': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\外币评估清单.xlsx",
    'TB': r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\财务报表基础数据\1100-华峰化学\科目余额表-华峰化学-14期.xlsx",
    # 'DB': r"D:\audit_project\DEV\auto_workingpaper\data.duckdb"
    'DB': r"D:\audit_project\DEV\auto_workingpaper\test\test.duckdb"
}


# 列类型预定义（根据实际业务调整）
DTYPE_MAPPING = {
    'FBL1H_THIS': {
        '公司代码':object,
        '供应商':object,
        '总账科目':object
    },
    'FBL1H_LAST': {
        '公司代码':object,
        '供应商':object,
        '总账科目':object
    },
    'FBL1H_OCCUR': {
        '公司代码':object,
        '供应商':object,
        '总账科目':object,
        '冲销关于':object,
        '凭证编号':object
    },
    'FBL5H_THIS': {
        '公司代码':object,
        '客户':object,
        '总账科目':object
    },
    'FBL5H_LAST': {
        '公司代码':object,
        '客户':object,
        '总账科目':object
    },
    'FBL5H_OCCUR': {
        '公司代码':object,
        '客户':object,
        '总账科目':object,
        '冲销关于':object,
        '凭证编号':object
    },
    'ZFI072N_THIS': {
        '供应商编码':object,
        '账户':object,
        '供应商名称':object
    },
    'FOREIGN_CURRENCY': {
        '账户':object,
        '总帐帐目':object,
        '供应商名称':object,
        '供应商编码':object
    },
    'TB':{
        '科目代码':object
    }
}

# 必要列和标准列定义
FBL1H_REMAIN_MUST_COLS = [ #FBL1H余额
    '公司代码',
    '总账科目',
    '总账科目：长文本',
    '供应商',
    '供应商科目：名称 1',
    '凭证货币代码',
    '凭证货币价值',
    '公司代码货币代码',
    '公司代码货币价值'
    ]

FBL1H_REMAIN_STANDARD_COLS = [
        '公司代码',
        '科目代码',
        '科目名称',
        '客商代码',
        '客商名称',
        '原币符号',
        '原币余额',
        '本位币符号',
        '本位币余额'
        ]

FBL1H_OCCUR_MUST_COLS = [ #FBL1H发生额
    '公司代码',
    '总账科目',
    '总账科目：长文本',
    '供应商',
    '供应商科目：名称 1',
    '凭证货币代码',
    '凭证货币价值',
    '公司代码货币代码',
    '公司代码货币价值',
    '借/贷标识',
    '凭证类型',
    '凭证编号',
    '冲销关于'
    ]

FBL1H_OCCUR_STANDARD_COLS = [
    '公司代码',
    '科目代码',
    '科目名称',
    '客商代码',
    '客商名称',
    '原币符号',
    '原币金额',
    '本位币符号',
    '本位币金额',
    '借贷标识',
    '凭证类型',
    '凭证编号',
    '冲销关于'
    ]

FBL5H_REMAIN_MUST_COLS = [ #FBL5H余额
    '公司代码',
    '总账科目',
    '总账科目：短文本',
    '客户',
    '客户科目：姓名 1',
    '凭证货币代码',
    '凭证货币价值',
    '公司代码货币代码',
    '公司代码货币价值'
    ]

FBL5H_REMAIN_STANDARD_COLS = [
        '公司代码',
        '科目代码',
        '科目名称',
        '客商代码',
        '客商名称',
        '原币符号',
        '原币余额',
        '本位币符号',
        '本位币余额'
    ]

FBL5H_OCCUR_MUST_COLS = [ #FBL5H发生额
    '公司代码',
    '总账科目',
    '总账科目：短文本',
    '客户',
    '客户科目：姓名 1',
    '凭证货币代码',
    '凭证货币价值',
    '公司代码货币代码',
    '公司代码货币价值',
    '借/贷标识',
    '凭证类型',
    '凭证编号',
    '冲销关于'
    ]

FBL5H_OCCUR_STANDARD_COLS = [
    '公司代码',
    '科目代码',
    '科目名称',
    '客商代码',
    '客商名称',
    '原币符号',
    '原币金额',
    '本位币符号',
    '本位币金额',
    '借贷标识',
    '凭证类型',
    '凭证编号',
    '冲销关于'
    ]

ZFI072N_THIS_MUST_COLS = [ #应付暂估
    '供应商编码',
    '供应商名称',
    '币种',
    '公司代码',
    '杂费描述', #拆开杂费
    '结算金额', #从暂估金额改成结算金额
    '原币暂估金额'
    ]
ZFI072N_THIS_STANDARD_COLS = ZFI072N_THIS_MUST_COLS

FOREIGN_CURRENCY_MUST_COLS = [ #外币评估清单
    '账户',
    '总帐帐目',
    '货币',
    '记帐金额'
    ]
FOREIGN_CURRENCY_STANDARD_COLS = FOREIGN_CURRENCY_MUST_COLS

TB_MUST_COLS = None #科目余额表
TB_STANDARD_COLS = TB_MUST_COLS



# 列映射定义
COL_MAPPING = {
    'FBL1H_THIS': { 
    'must_col':FBL1H_REMAIN_MUST_COLS,
    'standard_col':FBL1H_REMAIN_STANDARD_COLS
    },
    'FBL1H_LAST': {
    'must_col':FBL1H_REMAIN_MUST_COLS,
    'standard_col':FBL1H_REMAIN_STANDARD_COLS
    },
    'FBL1H_OCCUR':{
    'must_col':FBL1H_OCCUR_MUST_COLS,
    'standard_col':FBL1H_OCCUR_STANDARD_COLS
    },
    'FBL5H_THIS': { 
    'must_col':FBL5H_REMAIN_MUST_COLS,
    'standard_col':FBL5H_REMAIN_STANDARD_COLS
    },
    'FBL5H_LAST': {
    'must_col':FBL5H_REMAIN_MUST_COLS,
    'standard_col':FBL5H_REMAIN_STANDARD_COLS
    },
    'FBL5H_OCCUR':{
    'must_col':FBL5H_OCCUR_MUST_COLS,
    'standard_col':FBL5H_OCCUR_STANDARD_COLS
    },
    'ZFI072N_THIS':{
    'must_col':ZFI072N_THIS_MUST_COLS,
    'standard_col':ZFI072N_THIS_STANDARD_COLS
    },
    'FOREIGN_CURRENCY':{
    'must_col':FOREIGN_CURRENCY_MUST_COLS,
    'standard_col':FOREIGN_CURRENCY_STANDARD_COLS
    },
    'TB':{
    'must_col':TB_MUST_COLS,
    'standard_col':TB_STANDARD_COLS
    }
}

#表头起始行
HEADER_MAPPING = {
    'FBL1H_THIS': 0,
    'FBL1H_LAST': 0,
    'FBL1H_OCCUR': 0,
    'FBL5H_THIS': 0,
    'FBL5H_LAST': 0,
    'FBL5H_OCCUR': 0,
    'ZFI072N_THIS': 0,
    'FOREIGN_CURRENCY': 8,
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

    #若path为'empty',针对“外币评估清单做特殊处理”返回空数据
    if path=='empty':
        df=pd.DataFrame(columns=['账户','总帐帐目','货币','记帐金额'])
        return df
    else:
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
def clean_data(file_info: Dict[str, Dict],rate_date)-> Dict[str, pd.DataFrame]:
    '''
    清洗各类数据
    # 1.FBL1H 本期余额 
    # 2.FBL1H 上期余额 
    # 3.FBL1H 本期发生额
    # 4.FBL1H 本期余额 
    # 5.FBL1H 上期余额 
    # 6.FBL1H 本期发生额 
    # 7.ZFI072N 本期暂估
    # 8.外币评估清单
    # 9.科目余额表
    '''
    result = {}

    df_fbl1h_this = file_info['FBL1H_THIS']
    df_fbl1h_last = file_info['FBL1H_LAST']
    df_fbl1h_occur = file_info['FBL1H_OCCUR']

    df_fbl5h_this = file_info['FBL5H_THIS']
    df_fbl5h_last = file_info['FBL5H_LAST']
    df_fbl5h_occur = file_info['FBL5H_OCCUR']

    df_zfi072n_this = file_info['ZFI072N_THIS']
    df_foreign_currency = file_info['FOREIGN_CURRENCY']    

    #1.合并df_fbl1h_this和df_fbl1h_last df_fbl5h_this和df_fbl5h_last 到df_balance往来余额表
    df_fbl1h_this['期间_add']='this'
    df_fbl1h_last['期间_add']='last'
    df_fbl1h_this['类型_add']='FBL1H'
    df_fbl1h_last['类型_add']='FBL1H'

    df_fbl5h_this['期间_add']='this'
    df_fbl5h_last['期间_add']='last'
    df_fbl5h_this['类型_add']='FBL5H'
    df_fbl5h_last['类型_add']='FBL5H'

    df_balance=pd.concat([df_fbl1h_this,df_fbl1h_last,df_fbl5h_this,df_fbl5h_last],ignore_index=True)
    df_balance=df_balance[df_balance['科目代码'].notnull()] #剔除科目代码为空的行
    result['往来余额表']=df_balance

    # 2.合并df_fbl1h_occur、df_fbl5h_occur 到df_occur往来发生额表
    df_fbl1h_occur['类型_add']='FBL1H'
    df_fbl5h_occur['类型_add']='FBL5H'

    df_occur=pd.concat([df_fbl1h_occur,df_fbl5h_occur],ignore_index=True).copy()
    result['往来发生额表']=df_occur

    #3.处理ZFI072N本期暂估
    df_zfi072n_this['供应商编码']=df_zfi072n_this['供应商编码'].fillna('00')
    df_zfi072n_this['供应商编码']=df_zfi072n_this['供应商编码'].apply(lambda x:x[2:])
    df_zfi072n_this['供应商编码']=df_zfi072n_this['供应商编码'].str.replace(r'^0+','', regex=True) #处理供应商编码前面的0统一删除
    df_zfi072n_this.rename(columns={'结算金额':'暂估金额'},inplace=True) #暂估金额列取数改成结算金额
    df_zfi072n_this['币种']=df_zfi072n_this['币种'].fillna('CNY')#用CNY填充空制
    result['应付暂估_ZFI072N']=df_zfi072n_this
    
    #4.处理外币评估清单
    result['外币评估清单']=df_foreign_currency

    #4.处理科目余额表
    try:
        df_tb = file_info['TB']
        df_tb['科目代码']=df_tb['科目代码'].astype(str).apply(lambda x:x[2:])
        result['科目余额表']=df_tb
    except:
        pass

    #6.查询汇率
    if rate_date is None or rate_date == '':
        df_rate=pd.DataFrame(columns=['货币','汇率','货币缩写'])
    else:
        df_rate=get_excahnge_rate_by_date(date=rate_date)
    #加一行人民币汇率
    # df_rate.loc[-1]=['人民币',1.0000,'CNY']
    result['汇率表']=df_rate



    return result


################################模块三、主函数##########################################
def main(PATHS=None):

    end_date = PATHS['END_DATE'] #期末日期

    if PATHS is None:
        config_dict = AP_dict
        PATHS=PATHS_AP
    else:
        #对字符串元素清洗前后引号
        PATHS = {k:v[1:-1] if type(v)==str and (v[0]=="'" or v[0]=='"') else v for k,v in PATHS.items() if k!='END_DATE'} 

        #构建配置字典
        config_dict = {
            task_name: {
                'path': PATHS[task_name],
                'must_col': COL_MAPPING[task_name]['must_col'],
                'standard_col': COL_MAPPING[task_name]['standard_col'], 
                'dtype_dict': DTYPE_MAPPING[task_name],
                'header':HEADER_MAPPING[task_name]
            }
            for task_name in PATHS.keys() if task_name not in ['DB','END_DATE']
        }

    #1. 读取原始数据
    raw_data_dict = read_data_parallel(file_info=config_dict)

    # 2. 清洗数据
    result=clean_data(file_info=raw_data_dict,rate_date=end_date) #rate_date 截止日期

    #写入数据
    def write_2_duckdb(con,data,table_name):
        df=data.copy()
        con.sql(f'''drop table if exists {table_name}''')
        con.sql(f'''create table {table_name} as select * from df''')

    # 3. 写入数据库
    with duckdb.connect(PATHS['DB']) as con:

        df_balance = result['往来余额表']
        df_occur = result['往来发生额表']
        df_zfi072n_this = result['应付暂估_ZFI072N']
        df_foreign_currency = result['外币评估清单']
        df_rate = result['汇率表']

        try:
            df_tb = result['科目余额表']
        except:
            pass

        write_2_duckdb(con,df_balance,'往来余额')
        write_2_duckdb(con,df_occur,'往来发生额')
        write_2_duckdb(con,df_zfi072n_this,'应付暂估_ZFI072N')
        write_2_duckdb(con,df_foreign_currency,'外币评估清单')
        write_2_duckdb(con,df_rate,'汇率表')

        try:
            write_2_duckdb(con,df_tb,'科目余额表')
        except:
            pass

        #数值转换
        con.sql('''
        alter table 往来余额 alter column 本位币余额 type decimal(19,2);
        alter table 往来余额 alter column 原币余额 type decimal(19,2);   
        alter table 往来余额 alter column 客商代码 type varchar;
        alter table 往来余额 alter column 原币符号 type varchar; 
        
        alter table 往来发生额 alter column 本位币金额 type decimal(19,2); 
        alter table 往来发生额 alter column 原币金额 type decimal(19,2); 
        alter table 往来发生额 alter column 客商代码 type varchar;
        alter table 往来发生额 alter column 原币符号 type varchar;
                
        
        alter table 应付暂估_ZFI072N alter column 供应商编码 type varchar;
        alter table 应付暂估_ZFI072N alter column 币种 type varchar;
        alter table 应付暂估_ZFI072N alter column 供应商名称 type varchar;
        alter table 应付暂估_ZFI072N alter column 暂估金额 type decimal(19,2);
        alter table 应付暂估_ZFI072N alter column 原币暂估金额 type decimal(19,2);
                
        
        alter table 外币评估清单 alter column 总帐帐目 type varchar;
        alter table 外币评估清单 alter column 账户 type varchar;
        alter table 外币评估清单 alter column 货币 type varchar;
        alter table 外币评估清单 alter column 记帐金额 type decimal(19,2);
                
        alter table 汇率表 alter column 货币 type varchar;
        alter table 汇率表 alter column 汇率 type decimal(19,4);
        alter table 汇率表 alter column 货币缩写 type varchar;
                
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
    # import time
    # start = time.time()
    # main()
    # print(f"执行完成，耗时: {time.time()-start:.2f}秒")


    import time
    paths={}
    # paths['END_DATE']=''
    # paths['FBL1H_THIS'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_未清项_1100_2024.XLSX"
    # paths['FBL1H_LAST'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_未清项_1100_2023.XLSX"
    # paths['FBL1H_OCCUR'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_全部项_1100_2024.XLSX"

    # paths['FBL5H_THIS'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-未清项-2024-YAM1.XLSX"
    # paths['FBL5H_LAST'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-未清项-2023-YAM1.XLSX"
    # paths['FBL5H_OCCUR'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-全部项-2024-YAM.XLSX"

    # paths['ZFI072N_THIS'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\ZFI072N_应付暂估_1100_含月返_2024.XLSX"
    # paths['FOREIGN_CURRENCY'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\外币评估清单.xlsx"
    # paths['TB'] =  r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\财务报表基础数据\1100-华峰化学\科目余额表-华峰化学-14期.xlsx"
    # paths['DB'] = r"D:\audit_project\DEV\auto_workingpaper\test\test.duckdb"

    paths['END_DATE']='2024-12-31'
    paths['FBL1H_THIS'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_未清项_1100_2024.XLSX"
    paths['FBL1H_LAST'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_未清项_1100_2023.XLSX"
    paths['FBL1H_OCCUR'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\FBL1H_全部项_1100_2024.XLSX"

    paths['FBL5H_THIS'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-未清项-2024-YAM1.XLSX"
    paths['FBL5H_LAST'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-未清项-2023-YAM1.XLSX"
    paths['FBL5H_OCCUR'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\应收和其他应收\FBL5H-1100-全部项-2024-YAM.XLSX"

    paths['ZFI072N_THIS'] = r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\往来基础数据\1100-华峰化学\ZFI072N_应付暂估_1100_含月返_2024.XLSX"
    paths['FOREIGN_CURRENCY'] = 'empty'
    paths['TB'] =  r"D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\原始数据\财务报表基础数据\1100-华峰化学\科目余额表-华峰化学-14期.xlsx"
    paths['DB'] = r"D:\audit_project\DEV\auto_workingpaper\test\test.duckdb"

    start = time.time()
    main(PATHS=paths)
    print(f"执行完成，耗时: {time.time()-start:.2f}秒")

    # 调试单个文件
    # read_data_parallel({'FOREIGN_CURRENCY':AP_dict['FOREIGN_CURRENCY']})
