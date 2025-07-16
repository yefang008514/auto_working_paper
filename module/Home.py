import streamlit as st
import os,sys
sys.path.append(os.getcwd())

import pathlib 
import xlwings as xw
import pandas as pd 

def main():

    st.title("🏠首页-明细表自动化工具箱导航")
    # st.sidebar.markdown("""
    # - 🏦 银行流水合并
    # - 📊 试算自动化
    # - 📅 账龄分析（开发中）
    # """)

    st.markdown('''此工具为[立信会计师事务所浙江分所 21部]开发的审计小工具，功能集成在侧边栏''')
    st.markdown('''
    审计工具箱是一款基于Python的审计辅助工具箱，主要功能有：<br>
    📄1.往来科目底稿明细表自动化<br>
    🪙2.费用科目明细表自动化<br>
    🏠3.长期资产科目明细表自动化<br>
    <br>
    **基础数据导出操作指南详见下面链接**
    ''',unsafe_allow_html=True)

    st.markdown("[华峰化学SAP基础数据导出攻略](https://kdocs.cn/l/cgfpxphh5Y7u)")

    st.markdown("<br><br><br>",unsafe_allow_html=True)

    st.markdown(
    '''
    copyright
    © [20250510] [立信会计师事务所浙江分所 21部]。保留所有权利。

    使用本工具遇到任何问题，请联系：[yefang@bdo.com.cn]
    ''')





if __name__ == '__main__':

    main()
    

    # path_app = pathlib.Path(__file__).parent.resolve()

    # with open(rf'{path_app}\datas\test.txt',encoding='utf-8') as file: 引用文件路径
    #     st.write(file.read())

