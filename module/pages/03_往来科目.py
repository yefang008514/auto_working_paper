import streamlit as st
import pandas as pd
from io import BytesIO
import pathlib
import time

import os,sys
sys.path.append(os.getcwd())
from module.arap.data_import import main
from module.tool_fun.extract_data import get_detail_from_db_table 
from module.tool_fun.excel_import import read_full_excel,dfs_to_duckdb
from module.tool_fun.project_related import project_selector

from module.arap.exchange_rate import get_excahnge_rate_by_date
from module.arap.query import get_ap_adjust,get_ar_adjust



#查询往来账款明细按钮
def download_button(db_path,show_selector=True,button_id=None):

    if show_selector:
        super_flag=st.selectbox("请选择查询方式",["1.按调整后导出","2.按调整前导出"])
        st.markdown('若不导入应收或的应付调整清单，无论选择"1.按调整后导出"还是"2.按调整前导出"结果均相同')
    else:
        super_flag='2.按调整前导出'

    if st.button("查询往来账款明细",key=button_id):
            # 判断外币评估清单是否存在
            df_foreign_list = get_detail_from_db_table(db_path=db_path,view_name='外币评估清单')
            flag_fore=len(df_foreign_list)

            ap_flag_1=len(get_detail_from_db_table(db_path=db_path,view_name='总账调整_应付账款'))
            ap_flag_2=len(get_detail_from_db_table(db_path=db_path,view_name='工程类暂估调整_应付账款'))
            ap_flag_3=len(get_detail_from_db_table(db_path=db_path,view_name='返利调整_应付账款'))

            ar_flag_1=len(get_detail_from_db_table(db_path=db_path,view_name='总账调整_应收账款'))
            ar_flag_2=len(get_detail_from_db_table(db_path=db_path,view_name='返利调整_应收账款'))

            ap_adj_flag=ap_flag_1+ap_flag_2+ap_flag_3
            ar_adj_flag=ar_flag_1+ar_flag_2

            if super_flag=="1.按调整后导出":
                pass
            elif super_flag=="2.按调整前导出":
                ap_adj_flag=0
                ar_adj_flag=0
            else:
                pass

            if flag_fore>0: #有外币评估清单，直接使用原有逻辑
                st.write("按有外币评估清单的逻辑生成明细表")
                if ap_adj_flag>0:#有调整按调整的来
                    st.write("按调整后导出应付预付")
                    df_ap=get_detail_from_db_table(db_path=db_path,view_name='应付账款明细表_调整后')
                    df_pre_ap=get_detail_from_db_table(db_path=db_path,view_name='预付账款明细表_调整后')
                else:
                    st.write("按调整前导出应付预付")
                    df_ap=get_detail_from_db_table(db_path=db_path,view_name='应付账款明细表')
                    df_pre_ap=get_detail_from_db_table(db_path=db_path,view_name='预付账款明细表')
                if ar_adj_flag>0:#有调整按调整的来
                    st.write("按调整后导出应收预收")
                    get_detail_from_db_table(db_path=db_path,view_name='返利调整_应收账款')
                    df_ar=get_detail_from_db_table(db_path=db_path,view_name='应收账款明细表_调整后')
                    df_pre_ar=get_detail_from_db_table(db_path=db_path,view_name='预收账款明细表_调整后')
                else:
                    st.write("按调整前导出应收预收")
                    df_ar=get_detail_from_db_table(db_path=db_path,view_name='应收账款明细表')
                    df_pre_ar=get_detail_from_db_table(db_path=db_path,view_name='预收账款明细表')

                df_oar=get_detail_from_db_table(db_path=db_path,view_name='其他应收款明细表')
                df_oap=get_detail_from_db_table(db_path=db_path,view_name='其他应付款明细表')
            else:
                st.write("按有外币倒轧逻辑生成明细表")
                if ap_adj_flag>0:#有调整按调整的来
                    st.write("按调整后导出应付预付")
                    df_ap=get_detail_from_db_table(db_path=db_path,view_name='应付账款明细表-外币倒轧_调整后')
                    df_pre_ap=get_detail_from_db_table(db_path=db_path,view_name='预付账款明细表-外币倒轧_调整后')
                else:
                    st.write("按调整前导出应付预付")
                    df_ap=get_detail_from_db_table(db_path=db_path,view_name='应付账款明细表-外币倒轧')
                    df_pre_ap=get_detail_from_db_table(db_path=db_path,view_name='预付账款明细表-外币倒轧')

                if ar_adj_flag>0:#有调整按调整的来
                    st.write("按调整后导出应收预收")
                    get_detail_from_db_table(db_path=db_path,view_name='返利调整_应收账款')
                    df_ar=get_detail_from_db_table(db_path=db_path,view_name='应收账款明细表-外币倒轧_调整后')
                    df_pre_ar=get_detail_from_db_table(db_path=db_path,view_name='预收账款明细表-外币倒轧_调整后')
                else:
                    st.write("按调整前导出应收预收")
                    df_ar=get_detail_from_db_table(db_path=db_path,view_name='应收账款明细表-外币倒轧')
                    df_pre_ar=get_detail_from_db_table(db_path=db_path,view_name='预收账款明细表-外币倒轧')

                df_oar=get_detail_from_db_table(db_path=db_path,view_name='其他应收款明细表')
                df_oap=get_detail_from_db_table(db_path=db_path,view_name='其他应付款明细表')

            #下载应付账款明细
            output = BytesIO()
            with pd.ExcelWriter(output) as writer:
                df_ap.to_excel(writer, sheet_name='应付账款', index=False)
                df_pre_ap.to_excel(writer, sheet_name='预付账款', index=False)

                df_ar.to_excel(writer, sheet_name='应收账款', index=False)
                df_pre_ar.to_excel(writer, sheet_name='预收账款', index=False)

                df_oar.to_excel(writer, sheet_name='其他应收', index=False)
                df_oap.to_excel(writer, sheet_name='其他应付', index=False)

            # 下载按钮
            st.download_button(
                label="📤 导出Excel",
                data=output.getvalue(),
                file_name="往来明细表.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )
#查询汇率



def ap_adjustment():

    #下载模板
    template_path = template_path = (
        pathlib.Path(__file__)  # 当前文件路径
        .parent.parent  # 向上两级 (module/pages -> module)
        / "datas"  # 进入datas目录
        / "应付调整模板.xlsx"  # 模板文件
    )
    
    with open(template_path, "rb") as file:
        template_data = file.read()

    st.download_button(
        label="📥 下载应付调整模板",
        data=template_data,
        file_name="应付调整模板.xlsx",
        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        help="下载后请勿修改文件名和格式"
    )

    #提示步骤
    template_path = st.file_uploader("1.请填写完[应付调整模板]后导入：", type=['xlsx'])
    st.markdown('''2.请选择关联项目''')
    db_path = project_selector()
    
    if st.button("3.点击此按钮开始调整"):
        if db_path is not None and template_path is not None:
            #导入调整模板数据
            dfs=read_full_excel(template_path,header=0)
            dfs_to_duckdb(dfs,db_path,suffix='应付账款')
            
            #导出调整后结果
            df_ap,df_pre_ap=get_ap_adjust(db_path)

            #下载应付账款明细
            output = BytesIO()
            with pd.ExcelWriter(output) as writer:
                df_ap.to_excel(writer, sheet_name='应付账款_调整后', index=False)
                df_pre_ap.to_excel(writer, sheet_name='预付账款_调整后', index=False)
            # 下载按钮
            st.download_button(
                label="📤 导出Excel",
                data=output.getvalue(),
                file_name="应付账款_调整后.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )
        else:
            st.error("!!!请填写相关项目信息!!!")

def ar_adjustment():

    #下载模板
    template_path = template_path = (
        pathlib.Path(__file__)  # 当前文件路径
        .parent.parent  # 向上两级 (module/pages -> module)
        / "datas"  # 进入datas目录
        / "应收调整模板.xlsx"  # 模板文件
    )
    
    with open(template_path, "rb") as file:
        template_data = file.read()

    st.download_button(
        label="📥 下载应收调整模板",
        data=template_data,
        file_name="应收调整模板.xlsx",
        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        help="下载后请勿修改文件名和格式"
    )

    #提示步骤
    template_path = st.file_uploader("1.请填写完[应收调整模板]后导入：", type=['xlsx'])
    st.markdown('''2.请选择关联项目''')
    db_path = project_selector()
    
    if st.button("3.点击此按钮开始调整"):
        if db_path is not None and template_path is not None:
            #导入调整模板数据
            dfs=read_full_excel(template_path,header=0)
            dfs_to_duckdb(dfs,db_path,suffix='应收账款')
            
            #导出调整后结果
            df_ar,df_pre_ar=get_ar_adjust(db_path)

            #下载应付账款明细
            output = BytesIO()
            with pd.ExcelWriter(output) as writer:
                df_ar.to_excel(writer, sheet_name='应收账款_调整后', index=False)
                df_pre_ar.to_excel(writer, sheet_name='预收账款_调整后', index=False)
            # 下载按钮
            st.download_button(
                label="📤 导出Excel",
                data=output.getvalue(),
                file_name="应收账款_调整后.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )
        else:
            st.error("!!!请填写相关项目信息!!!")






def main_ui():

    #路径字典    
    PATHS_ARAP={
        'END_DATE':None, #审计期间期末日期
        'FBL1H_THIS':None,
        'FBL1H_LAST':None,
        'FBL1H_OCCUR':None,
        'ZFI072N_THIS':None,
        'FOREIGN_CURRENCY':'empty', #默认为'empty'
        'DB':None}
    # 页面配置
    st.set_page_config(page_title="往来科目明细表自动化", page_icon="📋", layout="wide")

    #侧边栏
    with st.sidebar.expander("请选择子功能"):
            mode = st.radio(" ", ["1.导入基础数据","2.应付调整","3.应收调整", "4.生成明细表"])

    #############子模块功能##################
    if mode == "1.导入基础数据":
        st.markdown("**请按照下面提示粘贴【往来科目】原始基础数据路径，前后带不带双引号均支持**")

        #让用户选择是否已有"外币评估清单"
        state_exist_foreign_currency = st.sidebar.selectbox("是否已有【外币评估清单】？",["否","是"])

        st.markdown('''请选择关联项目''')
        # 选择关联项目
        PATHS_ARAP['DB']=project_selector()
        if state_exist_foreign_currency=='否':
            PATHS_ARAP['END_DATE'] = st.text_input("审计期间期末日期：(用于查询计算汇率)如:2024-12-31",value='2024-12-31')
        else:
            pass
        PATHS_ARAP['FBL1H_THIS'] = st.file_uploader("1.上传[FBL1H本期]余额文件:", type=['xlsx','xlsm'])
        PATHS_ARAP['FBL1H_LAST'] = st.file_uploader("2.上传[FBL1H上期]余额文件:", type=['xlsx','xlsm'])
        PATHS_ARAP['FBL1H_OCCUR'] = st.file_uploader("3.上传[FBL1H本期]发生额文件:", type=['xlsx','xlsm'])


        PATHS_ARAP['FBL5H_THIS'] = st.file_uploader("4.上传[FBL5H本期]余额文件:", type=['xlsx','xlsm'])
        PATHS_ARAP['FBL5H_LAST'] = st.file_uploader("5.上传[FBL5H上期]余额文件:", type=['xlsx','xlsm'])
        PATHS_ARAP['FBL5H_OCCUR'] = st.file_uploader("6.上传[FBL5H本期]发生额文件:", type=['xlsx','xlsm'])

        PATHS_ARAP['ZFI072N_THIS'] = st.file_uploader("7.上传[ZFI072N本期]文件:", type=['xlsx','xlsm'])

        if state_exist_foreign_currency=='否':
            pass
        else:
            PATHS_ARAP['FOREIGN_CURRENCY'] = st.file_uploader("7.上传[外币评估清单本期]文件:", type=['xlsx','xlsm'])
        
        # 开始处理按钮
        if st.button("开始处理"):

            #flag:若有任意一个空值校验不通过 若非空赋0 空赋值1 若任意为空则flag>0
            flag=sum([0 if v !='' else 1 for k,v in PATHS_ARAP.items()])
            if flag>0:
                st.error("请先输入文件夹路径并上传配置文件!")
            else:
                st.write("正在读取并导入数据库")
                start_time = time.time()
                main(PATHS_ARAP)
                end_time = time.time()
                st.write(f"数据库导入成功,用时：{round(end_time-start_time,2)}秒")

        # 查询及下载按钮 统一按调整前导出
        download_button(db_path=PATHS_ARAP['DB'],show_selector=False,button_id='temp')

    elif mode == "2.应付调整":
        ap_adjustment()
    elif mode == "3.应收调整":
        ar_adjustment()

    elif mode == "4.生成明细表":
        st.markdown("**请按照下面提示粘贴路径，前后带不带双引号均支持**")
        PATHS_ARAP['DB']=project_selector()
        # 查询及下载按钮
        download_button(db_path=PATHS_ARAP['DB'])
        

        


if __name__ == '__main__':
    main_ui()
