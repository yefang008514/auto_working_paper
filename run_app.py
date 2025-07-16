
import streamlit.web.cli as stcli
import os, sys
# from module.config.config import PROJECT_CONFIG
 
 
def resolve_path(path):
    resolved_path = os.path.abspath(os.path.join(os.getcwd(), path))
    return resolved_path

#获取封装后的文件路径
def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    base_path = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path)


if __name__ == "__main__":
    sys.argv = [
        "streamlit",
        "run",
        resource_path(r"module\Home.py"),#Home.py的路径
        "--global.developmentMode=false",
    ]
    sys.exit(stcli.main())

    # print(PROJECT_CONFIG)


