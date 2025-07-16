import pandas as pd 
import duckdb
import os,sys
sys.path.append(os.getcwd())


'''从数据库获取数据'''
def get_detail_arap(db_path,view_name):

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


def get_ap_adjust(db_path):

    #若传入参数带引号，则去除引号
    my_path = rf'{db_path}' 
    if my_path[0]=='"' or my_path[0]=="'":
        my_path = my_path[1:-1]
    
    sql_file_path = os.path.join(os.path.dirname(__file__), 'sql_adj_ap.sql')
    with open(sql_file_path, "r", encoding="utf-8") as f:
        str_sql = f.read()
    
    with duckdb.connect(my_path) as conn:
        df_fore=conn.sql('select * from 外币评估清单;').df()
        len_fore=len(df_fore)

        #新建视图
        conn.sql(str_sql)
        
        if len_fore==0: #如果外币评估清单为空，则直接返回调整后的应付账款明细表
            df_1=conn.sql('''select * from "应付账款明细表-外币倒轧_调整后"; ''').df()
            df_2=conn.sql('''select * from "预付账款明细表-外币倒轧_调整后"; ''').df()
        else:
            df_1=conn.sql('''select * from "应付账款明细表_调整后";''').df()
            df_2=conn.sql('''select * from "预付账款明细表_调整后";''').df()

    return df_1,df_2


def get_ar_adjust(db_path):

    #若传入参数带引号，则去除引号
    my_path = rf'{db_path}' 
    if my_path[0]=='"' or my_path[0]=="'":
        my_path = my_path[1:-1]
    
    sql_file_path = os.path.join(os.path.dirname(__file__), 'sql_adj_ar.sql')
    with open(sql_file_path, "r", encoding="utf-8") as f:
        str_sql = f.read()
    
    with duckdb.connect(my_path) as conn:
        df_fore=conn.sql('select * from 外币评估清单;').df()
        len_fore=len(df_fore)

        #新建视图
        conn.sql(str_sql)
        
        if len_fore==0: #如果外币评估清单为空，则直接返回调整后的应付账款明细表
            df_1=conn.sql('''select * from "应收账款明细表-外币倒轧_调整后"; ''').df()
            df_2=conn.sql('''select * from "预收账款明细表-外币倒轧_调整后"; ''').df()
        else:
            df_1=conn.sql('''select * from "应收账款明细表_调整后";''').df()
            df_2=conn.sql('''select * from "预收账款明细表_调整后";''').df()

    return df_1,df_2





if __name__ == '__main__':

    # db_path = r'D:\audit_project\DEV\auto_workingpaper\data.duckdb'
    db_path = r'D:\audit_project\DEV\auto_workingpaper\test\test.duckdb'
    df = get_detail_arap(db_path,'应付账款明细表_调整后')
    df.to_excel('test111.xlsx',index=False)
    print('done')