import streamlit as st
import pandas as pd
from io import BytesIO
import time
import os,sys
sys.path.append(os.getcwd())
from module.costs.data_import import main
from module.costs.query import get_costs_detail,get_fin_costs 
from module.tool_fun.project_related import project_selector



def download_button(db_path):
    if st.button("查询费用科目明细"):
            df_sales=get_costs_detail(db_path=db_path,subject_name='销售费用') 
            df_ma=get_costs_detail(db_path=db_path,subject_name='管理费用') 
            df_de=get_costs_detail(db_path=db_path,subject_name='研发费用') 
            df_mu=get_costs_detail(db_path=db_path,subject_name='制造费用') 
            df_fin=get_fin_costs(db_path=db_path) #财务费用

            #下载费用科目明细
            output = BytesIO()
            with pd.ExcelWriter(output) as writer:
                df_sales.to_excel(writer, sheet_name='销售费用明细', index=False)
                df_ma.to_excel(writer, sheet_name='管理费用明细', index=False)
                df_de.to_excel(writer, sheet_name='研发费用明细', index=False)
                df_mu.to_excel(writer, sheet_name='制造费用明细', index=False)
                df_fin.to_excel(writer, sheet_name='财务费用明细', index=False)

            # 下载按钮
            st.download_button(
                label="📤 导出Excel",
                data=output.getvalue(),
                file_name="费用科目明细表.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )



def main_ui():

    #路径字典    
    PATHS_COSTS={
        'FBL3H_THIS':None,
        'DB':None}
    # 页面配置
    st.set_page_config(page_title="往来科目明细表自动化", page_icon="📋", layout="wide")

    #侧边栏
    with st.sidebar.expander("请选择子功能"):
            mode = st.radio(" ", ["1.导入基础数据", "2.生成明细表"])

    # 应付账款明细表自动化
    st.markdown("**请按照下面提示粘贴【往来科目】原始基础数据路径，前后带不带双引号均支持**")

    #############子模块功能##################
    if mode == "1.导入基础数据":
        #让用户选择是否已有数据库
        PATHS_COSTS['DB']=project_selector()
        #上传文件 
        PATHS_COSTS['FBL3H_THIS'] = st.file_uploader("上传[FBL3H本期]发生额文件:", type=['xlsx','xlsm'])

        # 开始处理按钮
        if st.button("开始处理"):
            #flag:若有任意一个空值校验不通过 若非空赋0 空赋值1 若任意为空则flag>0
            flag=sum([0 if v !='' else 1 for k,v in PATHS_COSTS.items()])
            if flag>0:
                st.error("请先输入文件夹路径并上传配置文件!")
            else:
                st.write("正在读取并导入数据库")
                start_time = time.time()
                main(PATHS_COSTS)
                end_time = time.time()
                st.write(f"数据库导入成功,用时：{round(end_time-start_time,2)}秒")
        # 查询及下载按钮
        download_button(db_path=PATHS_COSTS['DB'])

    elif mode == "2.生成明细表":
        PATHS_COSTS['DB'] = project_selector()
        # 查询及下载按钮
        download_button(db_path=PATHS_COSTS['DB'])

        



if __name__ == '__main__':
    main_ui()
