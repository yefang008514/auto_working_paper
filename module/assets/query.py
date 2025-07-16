import pandas as pd 
import duckdb
import os,sys
sys.path.append(os.getcwd())


'''从数据库获取数据'''
def get_detail_from_view(db_path,view_name):

    #若传入参数带引号，则去除引号
    my_path = rf'{db_path}' 
    if my_path[0]=='"' or my_path[0]=="'":
        my_path = my_path[1:-1]

    sql=f'''
    select * from "{view_name}";
    '''
    try:
        with duckdb.connect(my_path,read_only=True) as conn:
            df = conn.sql(sql).df()
    except:
        df = pd.DataFrame()

    return df