import os
import sys
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socket
import traceback
import time

def check_python_version():
    if sys.version_info[0] < 3:
        print("错误：需要Python 3.x版本")
        return False
    return True

def find_web_directory():
    # 检查可能的web目录位置
    possible_paths = [
        'build/web',
        'build\\web',
        'web',
        '.',
    ]
    
    for path in possible_paths:
        if os.path.exists(os.path.join(path, 'index.html')):
            return path
            
    return None

def get_free_port():
    try:
        sock = socket.socket()
        sock.bind(('', 0))
        port = sock.getsockname()[1]
        sock.close()
        return port
    except Exception as e:
        print(f"获取可用端口时出错：{e}")
        return 8000  # 使用默认端口

def main():
    try:
        print("正在启动AI小说生成器...")
        
        # 检查Python版本
        if not check_python_version():
            input("按回车键退出...")
            return

        # 查找web目录
        web_dir = find_web_directory()
        if web_dir is None:
            print("错误：找不到web应用文件")
            print("请确保解压缩后的目录结构完整")
            input("按回车键退出...")
            return

        # 切换到web目录
        try:
            os.chdir(web_dir)
            print(f"已找到web目录：{web_dir}")
        except Exception as e:
            print(f"切换目录失败：{e}")
            print("请确保在正确的目录中运行此脚本")
            input("按回车键退出...")
            return

        # 获取可用端口
        port = get_free_port()
        
        print(f"正在启动本地服务器...")
        server = HTTPServer(('localhost', port), SimpleHTTPRequestHandler)
        
        url = f'http://localhost:{port}'
        print(f"正在打开浏览器...")
        webbrowser.open(url)
        
        print(f"\nAI小说生成器已成功启动！")
        print(f"请访问: {url}")
        print("如果浏览器没有自动打开，请手动复制上面的地址到浏览器中")
        print("\n按Ctrl+C可以停止服务器")
        
        server.serve_forever()
        
    except KeyboardInterrupt:
        print("\n正在关闭服务器...")
        server.server_close()
        print("服务器已停止")
    except Exception as e:
        print("\n发生错误：")
        print(traceback.format_exc())
    finally:
        print("\n程序即将退出")
        time.sleep(1)
        input("按回车键关闭窗口...")

if __name__ == '__main__':
    main() 