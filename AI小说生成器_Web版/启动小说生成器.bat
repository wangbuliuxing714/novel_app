chcp 65001
@echo off
title AI小说生成器
echo 正在启动AI小说生成器...
echo.

:: 检查Python是否安装
python --version > nul 2>&1
if errorlevel 1 (
    echo 错误：未安装Python
    echo 请访问 https://www.python.org/downloads/ 下载并安装Python 3.x
    echo.
    pause
    exit
)

:: 检查目录结构
if not exist "build\web" (
    mkdir "build\web"
)

:: 检查文件是否在正确位置
if not exist "build\web\index.html" (
    :: 如果web文件在当前目录，则移动它们
    if exist "index.html" (
        echo 正在修复文件结构...
        move *.* "build\web\"
    )
)

:: 运行Python脚本
python start_novel_app.py 