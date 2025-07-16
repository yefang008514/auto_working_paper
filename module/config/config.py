import os,sys
import pathlib
sys.path.append(os.getcwd())

def get_exe_directory():
    """
    获取当前可执行文件所在的目录（兼容开发和打包环境）
    
    返回:
        str: exe 所在目录（开发环境下返回项目根目录）
    """
    # 检测是否在 PyInstaller 打包环境中运行
    is_frozen = getattr(sys, 'frozen', False)
    
    if is_frozen:
        # 打包环境：直接返回 exe 所在目录
        return os.path.dirname(sys.executable)
    else:
        # 开发环境：返回项目根目录（app.py 所在目录）
        # 获取当前文件（config.py）的绝对路径 module\config\config.py
        current_file_path = pathlib.Path(__file__)
        project_root = current_file_path.parent.parent.parent
        
        return project_root

# 获取 exe 所在目录
EXE_DIR = get_exe_directory()


# 项目数据库保存地址
db_folder = pathlib.Path(EXE_DIR).joinpath('db')
config_db_folder = db_folder.joinpath('config')
config_db_path = config_db_folder.joinpath('project_config.db')


# 项目配置信息
PROJECT_CONFIG={
    'DB_FOLDER':db_folder, #存不同项目数据库的地址
    'CONFIG_DB_FOLDER':config_db_folder, #存项目信息的数据库的文件夹
    'CONFIG_DB_PATH':config_db_path, #存项目信息的数据库的地址
}


if __name__ == '__main__':
    print(PROJECT_CONFIG)
