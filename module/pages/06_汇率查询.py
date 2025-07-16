import streamlit as st
import pandas as pd
from io import BytesIO
import pathlib
import time

import os,sys
sys.path.append(os.getcwd())

from module.arap.exchange_rate import get_excahnge_rate_by_date



def exchange_rate_query():
    st.markdown('''
    **此功能支持查询某日的外币汇率数据，请联网状态下使用**数据来源于[国家外汇管理局](https://www.safe.gov.cn/safe/rmbhlzjj/index.html)
    ''')
    str_date = st.text_input("请输入外币汇率查询日期（如2024-12-31）：")
        
    if st.button("查询当日汇率数据"):
        if str_date is not None and str_date!='':
            pass
        else:
            st.error("请输入查询日期")
            
        df=get_excahnge_rate_by_date(str_date)

        if len(df)==0:
                st.error("没有查询到该日期的汇率数据")
        else:
            #下载应付账款明细
            output = BytesIO()
            with pd.ExcelWriter(output) as writer:
                df.to_excel(writer, sheet_name='汇率', index=False)

            # 下载按钮
            st.download_button(
                label="📤 导出Excel",
                data=output.getvalue(),
                file_name=f"汇率表_{str_date}.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )

if __name__ == '__main__':
    exchange_rate_query()