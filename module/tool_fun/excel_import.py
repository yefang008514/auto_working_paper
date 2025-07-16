import pandas as pd
import duckdb

import os,sys
sys.path.append(os.getcwd())


#读完整excel数据
def read_full_excel(file_path,header):

    dfs=pd.read_excel(file_path,sheet_name=None,engine='calamine',header=header)
    
    return dfs

#将dfs数据导入duckdb

def dfs_to_duckdb(dfs,db_path,suffix):

    #若传入参数带引号，则去除引号
    my_path = rf'{db_path}' 
    if my_path[0]=='"' or my_path[0]=="'":
        my_path = my_path[1:-1]

    with duckdb.connect(my_path) as conn:
        for sheet_name,df in dfs.items():

            if suffix in ['应付账款','应收账款']:
                df['调整金额']=df['调整金额'].round(2)
                col_names=df.columns.tolist()[:3] #根据前3个字段透视
                df=df.groupby(col_names)['调整金额'].sum().reset_index() #透视计算总和
            else:
                pass

            final_sheet_name=sheet_name+'_'+suffix
            conn.sql(f"CREATE OR REPLACE TABLE {final_sheet_name} as select * from df;")
            #编码，名称设置成varchar
            for col in df.columns:
                if '编码' in col or '名称' in col or '币种' in col:
                    conn.sql(f"ALTER TABLE {final_sheet_name} ALTER COLUMN {col} TYPE VARCHAR;")
                elif '金额' in col:
                    conn.sql(f"ALTER TABLE {final_sheet_name} ALTER COLUMN {col} TYPE DECIMAL(19,2);")



if __name__ == '__main__':
    dfs = read_full_excel(file_path=r'D:\audit_project\DEV\auto_workingpaper\module\datas\应付调整模板.xlsx',header=0)
    dfs_to_duckdb(dfs=dfs,db_path=r'D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\TEST_DATA\浙江新材\浙江新材_往来明细表',suffix='应付账款')


    dfs = read_full_excel(file_path=r'D:\audit_project\DEV\auto_workingpaper\module\datas\应收调整模板.xlsx',header=0)
    dfs_to_duckdb(dfs=dfs,db_path=r'D:\wps_cloud_sync\339514258\WPS云盘\数字化审计开发小组\明细表自动化\TEST_DATA\浙江新材\浙江新材_往来明细表',suffix='应收账款')
