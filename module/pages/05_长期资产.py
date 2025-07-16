import streamlit as st
import pandas as pd
from io import BytesIO
import os,sys
sys.path.append(os.getcwd())
from module.assets.data_import import main
from module.tool_fun.extract_data import get_detail_from_db_table #后面考虑一个函数之前一次性生成
from module.tool_fun.project_related import project_selector
import time


#查询往来账款明细按钮
def download_button(db_path):
    if st.button("查询长期资产明细"):
            
            df_1=get_detail_from_db_table(db_path=db_path,view_name='固定资产明细表')
            df_2=get_detail_from_db_table(db_path=db_path,view_name='在建工程明细表')

            df_3=get_detail_from_db_table(db_path=db_path,view_name='无形资产明细表')
            df_4=get_detail_from_db_table(db_path=db_path,view_name='长期待摊费用明细表')

            #下载应付账款明细
            output = BytesIO()
            with pd.ExcelWriter(output) as writer:
                df_1.to_excel(writer, sheet_name='固定资产', index=False)
                df_2.to_excel(writer, sheet_name='在建工程', index=False)

                df_3.to_excel(writer, sheet_name='无形资产', index=False)
                df_4.to_excel(writer, sheet_name='长期待摊费用', index=False)

            # 下载按钮
            st.download_button(
                label="📤 导出Excel",
                data=output.getvalue(),
                file_name="长期资产明细表.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )


def main_ui():

    #路径字典    
    MY_PATHS={
        'ZFI022_THIS':None,
        'ZFI022_LAST':None,
        'ZFI022_THIS_SCRAP':None,
        'ZFI022_LAST_SCRAP':None,
        'FBL3H_OCCUR':None,
        'DB':None}
    # 页面配置
    st.set_page_config(page_title="长期资产明细表自动化", page_icon="📋", layout="wide")

    #侧边栏
    with st.sidebar.expander("请选择子功能"):
            mode = st.radio(" ", ["1.导入基础数据", "2.生成明细表"])

    # 应付账款明细表自动化
    st.markdown("**请按照下面提示粘贴【长期资产科目】原始基础数据路径，前后带不带双引号均支持**")

    #############子模块功能##################
    if mode == "1.导入基础数据":
        #让用户选择是否已有数据库
        st.markdown("请选择关联项目")
        MY_PATHS['DB'] = project_selector()
        MY_PATHS['ZFI022_THIS'] = st.file_uploader("1.请上传[ZFI022本期]余额文件：",type=['xlsx'])
        MY_PATHS['ZFI022_LAST'] = st.file_uploader("2.请上传[ZFI022上期]余额文件：",type=['xlsx']) 
        MY_PATHS['ZFI022_THIS_SCRAP'] = st.file_uploader("3.请上传[ZFI022_本期报废]余额文件：",type=['xlsx']) 
        MY_PATHS['ZFI022_LAST_SCRAP'] = st.file_uploader("4.请上传[ZFI022_上期报废]余额文件：",type=['xlsx'])
        MY_PATHS['FBL3H_OCCUR'] = st.file_uploader("5.请上传[FBL3H本期]发生额文件：",type=['xlsx'])

        # 开始处理按钮
        if st.button("开始处理"):
            #flag:若有任意一个空值校验不通过 若非空赋0 空赋值1 若任意为空则flag>0
            flag=sum([0 if v !='' else 1 for k,v in MY_PATHS.items()])
            if flag>0:
                st.error("请先输入文件夹路径并上传配置文件!")
            else:
                st.write("正在读取并导入数据库")
                start_time = time.time()
                main(MY_PATHS)
                end_time = time.time()
                st.write(f"数据库导入成功,用时：{round(end_time-start_time,2)}秒")
        # 查询及下载按钮
        download_button(db_path=MY_PATHS['DB'])

    elif mode == "2.生成明细表":
        st.markdown("请选择管理项目")
        MY_PATHS['DB'] = project_selector()
        # 查询及下载按钮
        download_button(db_path=MY_PATHS['DB'])

        


if __name__ == '__main__':
    main_ui()




