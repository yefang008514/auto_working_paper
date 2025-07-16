from multiprocessing import parent_process
import streamlit as st
import pandas as pd
from io import BytesIO
import pathlib
import time
import duckdb
import sqlite3 
import streamlit.components.v1 as components
from datetime import datetime

import os,sys
sys.path.append(os.getcwd())
from module.project_creator.data_import import main
from module.config.config import PROJECT_CONFIG

#项目数据库保存地址
db_folder = PROJECT_CONFIG['DB_FOLDER']
config_db_folder = PROJECT_CONFIG['CONFIG_DB_FOLDER']
config_db_path = PROJECT_CONFIG['CONFIG_DB_PATH']



def get_year():
    '''根据系统时间生成年份'''
    current_year = int(datetime.now().strftime("%Y"))
    # 生成当前年份前后3年的年份列表 
    year_range = list(range(current_year - 3, current_year + 1))
    # 将年份列表中的整数转换为字符串  当前年度置顶
    year_range = [str(current_year-1)]+[str(year) for year in year_range if year!= current_year-1]
    return year_range


def insert_project_info_to_db(config_db_folder,config_db_path,company_group, company_name, project_year, project_month):
    '''插入项目信息到数据库'''

    # 连接或创建 project_config 的 SQLite 数据库
    os.makedirs(config_db_folder, exist_ok=True)

    conn = sqlite3.connect(config_db_path)
    cursor = conn.cursor()
    # 修改项目基础信息表的创建语句，使用集团+公司名称+年+月组合作为主键
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS project_info (
        id TEXT PRIMARY KEY,
        company_group TEXT NOT NULL,
        company_name TEXT NOT NULL,
        project_year TEXT NOT NULL,
        project_month TEXT NOT NULL,
        create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
        CHECK (id = company_group || company_name || project_year || project_month)
    )
    ''')

    try:
        # 修改插入项目信息到数据库的语句，添加主键生成逻辑
        insert_query = '''
        INSERT INTO project_info (id, company_group, company_name, project_year, project_month)
        VALUES (?, ?, ?, ?, ?)
        '''
        # 生成主键
        project_id = company_group + company_name + project_year + project_month
        cursor.execute(insert_query, (project_id, company_group, company_name, project_year, project_month))
        st.success(f'{company_group}项目{company_name}_{project_year}年{project_month}月创建成功！')
    except sqlite3.IntegrityError:
        st.error('项目信息已存在，请勿重复创建！')

    conn.commit()
    conn.close()



def main_create_project():
    '''1.新建项目'''

    st.markdown('''请按照下面提示新建项目:''')

    # 创建一行多列布局
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        company_group = st.selectbox('集团:', ['华峰化学','华峰铝业'])
    with col2:
        company_name = st.text_input('公司名称:')
    with col3:
        project_year = st.selectbox('截止年：', get_year())
    with col4:
        project_month = st.selectbox('截止月：', ['12','06','01','02','03','04','05','07','08','09','10','11'])

    #上传科目余额表数据
    MY_PATHS={'TB':None,'DB':None}

    MY_PATHS['TB'] = st.file_uploader('1.请上传科目余额表数据', type=['xlsx'])

    #确认新建
    if st.button('新建项目'):
        #公司名称校验
        if company_name is None or company_name == '' '_' in company_name:
            st.error('请填写公司名称！')
        elif '_' in company_name:
            st.error('公司名称不能包含下划线！')
            return
        elif MY_PATHS['TB'] is None:
            st.error('请上传科目余额表数据！')
        else:
            pass
        #新建一个项目数据库地址
        os.makedirs(db_folder, exist_ok=True)
        #按 集团_公司名称_年_月.duckdb  命名
        db_name = f'{company_group}_{company_name}_{project_year}_{project_month}.duckdb'
        db_path = db_folder.joinpath(db_name)
        MY_PATHS['DB']=db_path

        #读取科目余额表数据并导入数据库
        main(PATHS=MY_PATHS)

        #插入项目信息到数据库
        try:
            insert_project_info_to_db(config_db_folder,config_db_path,company_group, company_name, project_year, project_month)
        except:
            st.error(f'{company_group}项目{company_name}_{project_year}年{project_month}月创建失败！')
        

def main_view_project(show_data=True):

    '''2.项目查看'''
    try:
        with sqlite3.connect(config_db_path) as conn:
            temp_df = pd.read_sql_query("SELECT * FROM project_info;", conn)
            df = temp_df[['company_group', 'company_name', 'project_year', 'project_month']]
            df.columns=['集团','公司名称','年份','月份']
            if show_data==True:
                st.markdown('**项目列表**') 
                st.dataframe(df,hide_index=True)
            else:
                pass
    except:
        st.error('项目信息数据库不存在！请先创建项目')
        df=pd.DataFrame()
    
    return df



# def main_delete_project():
#     '''3.项目删除'''

#     col1, col2, col3, col4 = st.columns(4)

#     #获取项目数据
#     df = main_view_project(show_data=False)
    
#     with col1:
#         company_group = st.selectbox('集团:', list(df['集团'].unique()))
#     with col2:
#         company_name = st.selectbox('公司名称:',list(df['公司名称'].unique()))
#     with col3:
#         project_year = st.selectbox('截止年：', list(df['年份'].unique()))
#     with col4:
#         project_month = st.selectbox('截止月：', list(df['月份'].unique()))

#     if st.button('确认删除'):
#         #删除项目数据库
#         db_name = f'{company_group}_{company_name}_{project_year}_{project_month}.duckdb'
#         db_path = db_folder.joinpath(db_name)

#         if db_path.exists():
#             #删除duckdb数据库
#             os.remove(db_path)
#             #删除项目信息数据库
#             with sqlite3.connect(config_db_path) as conn:
#                 cursor = conn.cursor()
#                 delete_query = f"DELETE FROM project_info WHERE company_group='{company_group}' AND company_name='{company_name}' AND project_year='{project_year}' AND project_month='{project_month}'"
#                 cursor.execute(delete_query)
#                 conn.commit()

#             st.success(f'{company_group}项目{company_name}({project_year}年{project_month}月)删除成功！')
            
#         else:
#             st.error(f'项目数据库不存在！')


def main_ui():

    st.write(f'当前数据保存路径：{db_folder}')
    #空出两行
    st.write('')
    st.write('')

    #侧边栏
    fun_list = ['1.新建项目','2.项目查看']
    mode = st.sidebar.radio('请选择子功能:', fun_list)

    if mode == '1.新建项目':
        main_create_project()

    elif mode == '2.项目查看':
        main_view_project()

    

if __name__ == '__main__':

    main_ui()
