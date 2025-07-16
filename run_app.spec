# -*- mode: python ; coding: utf-8 -*-
# -记得更改datas 和pathex的路径 
# -记得改工具名称

from PyInstaller.utils.hooks import collect_data_files
from PyInstaller.utils.hooks import copy_metadata
 
datas = [("C:/Users/yefan/miniforge3/envs/py39_new/Lib/site-packages/streamlit/runtime","./streamlit/runtime"),
        ('module\\*.*', '.\\module'),
        ('module\\arap\\*.*', '.\\module\\arap'),
        ('module\\assets\\*.*', '.\\module\\assets'),
        ('module\\config\\*.*', '.\\module\\config'),
        ('module\\costs\\*.*', '.\\module\\costs'),
        ('module\\datas\\*.*', '.\\module\\datas'),
        ('module\\pages\\*.*', '.\\module\\pages'),
        ('module\\project_creator\\*.*', '.\\module\\project_creator'),
        ('module\\tool_fun\\*.*', '.\\module\\tool_fun'),

        ]
datas += collect_data_files("streamlit")
datas += copy_metadata("streamlit")

block_cipher = None


a = Analysis(
    ['run_app.py'],
    pathex=["D:\audit_project\DEV\auto_workingpaper"],
    binaries=[],
    datas=datas,
    hiddenimports=['xlwings','openpyxl','pandas','duckdb','multiprocessing'],
    hookspath=['./hooks'],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='明细表自动化工具',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
