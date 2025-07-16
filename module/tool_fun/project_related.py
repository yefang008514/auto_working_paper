
import pathlib
import streamlit as st
import sqlite3
import pandas as pd
import os,sys
sys.path.append(os.getcwd())
from module.project_creator.data_import import main
from module.config.config import PROJECT_CONFIG


#项目信息保存数据库地址
config_db_folder = PROJECT_CONFIG['CONFIG_DB_FOLDER']
config_db_path = PROJECT_CONFIG['CONFIG_DB_PATH']

# 项目数据库保存地址
db_folder = PROJECT_CONFIG['DB_FOLDER']


def project_selector():
    '''
    项目选择器
    让用户选择项目，返回项目数据库地址
    '''
    col1, col2, col3, col4 = st.columns(4)
    #获取项目数据
    try:
        with sqlite3.connect(config_db_path) as conn:
            temp_df = pd.read_sql_query("SELECT * FROM project_info;", conn)
            df = temp_df[['company_group', 'company_name', 'project_year', 'project_month']]
            df.columns=['集团','公司名称','年份','月份']

            with col1:
                company_group = st.selectbox('集团:', list(df['集团'].unique()))
            with col2:
                company_name = st.selectbox('公司名称:',list(df['公司名称'].unique()))
            with col3:
                project_year = st.selectbox('截止年：', list(df['年份'].unique()))
            with col4:
                project_month = st.selectbox('截止月：', list(df['月份'].unique()))
            
            db_name = f'{company_group}_{company_name}_{project_year}_{project_month}.duckdb'
            db_path = db_folder.joinpath(db_name)
            
            return db_path
    except:
        st.error('项目信息数据库不存在！请先创建项目')    
    



'''获取db文件夹下的信息'''
def get_info_from_folder(folder_path):

    # 获取文件夹下所有文件名
    file_list = os.listdir(folder_path)
    info_list = [i[:-6].split('_') for i in file_list]

    df = pd.DataFrame(info_list, columns=['group', 'name', 'year','month'])

    group_list = df['group'].unique()
    name_list = df['name'].unique()
    year_list = df['year'].unique()
    month_list = df['month'].unique()

    return group_list, name_list, year_list, month_list




if __name__ == '__main__':
    folder_path = r'D:\audit_project\DEV\auto_workingpaper\data\workingpaper'
    group_list, name_list, year_list, month_list = get_info_from_folder(folder_path)
    print(group_list)