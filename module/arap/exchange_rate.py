import pandas as pd
# import xlwings as xw


#外币缩写字典
abbre={
'美元':'USD',
'欧元':'EUR',    
'日元':'JPY',
'港元':'HKD',
'英镑':'GBP',
'澳元':'AUD',
'新西兰元':'NZD',
'新加坡元':'SGD',
'瑞士法郎':'CHF',
'加元':'CAD',
'澳门元':'MOP',
'林吉特':'MYR',
'卢布':'RUB',
'兰特':'ZAR',
'韩元':'KRW',
'迪拉姆':'AED',
'里亚尔':'SAR',
'福林':'HUF',
'兹罗提':'PLN',
'丹麦克朗':'DKK',
'瑞典克朗':'SEK',
'挪威克朗':'NOK',
'里拉':'TRY',
'比索':'MXN',
'泰铢':'THB'
}

#得到外币汇率数据
def get_exchange_rate(start_date, end_date):
    # 网站提示最大可查询90天记录，实测可查三个自然月（例如7-9月共计92天也可），为减少查询次数本例按季度查询
    url = f'http://www.safe.gov.cn/AppStructured/hlw/RMBQuery.do?startDate={start_date}&endDate={end_date}&queryYN=true'
    
    try:
        q = pd.read_html(url)         # 获取查询页面的汇率数据表 
        df = pd.concat([q[4]])
        #转置日期和汇率
        date_column = '日期'
        currency_columns = df.columns[1:]
        melted_df = pd.melt(df, id_vars=[date_column], value_vars=currency_columns, var_name='货币', value_name='汇率')
        #添加缩写
        melted_df['货币缩写'] = melted_df['货币'].map(abbre)
        melted_df['汇率']=(melted_df['汇率']/100).round(4)  # 将汇率除以100并保留四位小数
    except Exception as e:
        print(f'获取外币汇率数据失败，错误信息：{e}')
        melted_df=pd.DataFrame()
    
    return melted_df

#获取某天的汇率数据
def get_excahnge_rate_by_date(date):
    """
    根据日期获取外币汇率
    :param date: 日期字符串，格式为 'YYYY-MM-DD'
    :return: 返回包含外币汇率的DataFrame [货币,汇率,货币缩写]
    """
    start_date = date
    end_date = date

    df = get_exchange_rate(start_date, end_date)

    # 删除日期列
    if '日期' in df.columns:
        df = df.drop(columns='日期')  
    else:
        pass

    return df

if __name__ == '__main__':

    df = get_excahnge_rate_by_date('2024-12-31')

    # start_date = '2024-01-01'  # 起始日期
    # end_date = '2024-01-15'    # 结束日期
    # url = f'http://www.safe.gov.cn/AppStructured/hlw/RMBQuery.do?startDate={start_date}&endDate={end_date}&queryYN=true'
    # q = pd.read_html(url)         # 获取查询页面的汇率数据表 
    # df = pd.concat([q[4]])
    # date_column = '日期'
    # currency_columns = df.columns[1:]
    # melted_df = pd.melt(df, id_vars=[date_column], value_vars=currency_columns, var_name='货币', value_name='汇率')

    # # print(df.head())
    # xw.view(melted_df)


# http://www.safe.gov.cn/AppStructured/hlw/RMBQuery.do?startDate=2024-01-01&endDate=2024-01-15&queryYN=true

