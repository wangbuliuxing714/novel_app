import os
import sys
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler
import socket
import traceback
import time
import errno

def check_python_version():
    if sys.version_info[0] < 3:
        print("错误：需要Python 3.x版本")
        return False
    return True

def create_empty_file(filepath):
    """创建空文件，如果文件不存在的话"""
    if not os.path.exists(filepath):
        try:
            with open(filepath, 'w') as f:
                f.write('{}')
            return True
        except Exception as e:
            print(f"创建文件 {filepath} 失败：{e}")
            return False
    return True

def ensure_resource_files():
    """确保必要的资源文件存在"""
    required_files = [
        'build/web/icons/Icon-192.png',
        'build/web/assets/AssetManifest.bin.json',
        'build/web/assets/FontManifest.json'
    ]
    
    for file_path in required_files:
        dir_path = os.path.dirname(file_path)
        if not os.path.exists(dir_path):
            os.makedirs(dir_path, exist_ok=True)
        if not create_empty_file(file_path):
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
        return 8000

class CustomHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # 禁止打印HTTP请求日志
        pass
        
    def handle(self):
        try:
            super().handle()
        except ConnectionAbortedError:
            # 忽略客户端中断连接的错误
            pass
        except Exception as e:
            if isinstance(e, socket.error) and e.errno in (errno.EPIPE, errno.ECONNRESET):
                # 忽略管道破裂和连接重置错误
                pass
            else:
                print(f"处理请求时发生错误: {e}")

    def handle_one_request(self):
        try:
            return super().handle_one_request()
        except ConnectionAbortedError:
            # 忽略客户端中断连接的错误
            pass
        except Exception as e:
            if isinstance(e, socket.error) and e.errno in (errno.EPIPE, errno.ECONNRESET):
                # 忽略管道破裂和连接重置错误
                pass
            else:
                print(f"处理单个请求时发生错误: {e}")

def main():
    try:
        print("正在启动AI小说生成器...")
        
        if not check_python_version():
            input("按回车键退出...")
            return

        web_dir = find_web_directory()
        if web_dir is None:
            print("错误：找不到web应用文件")
            print("请确保解压缩后的目录结构完整")
            input("按回车键退出...")
            return

        try:
            os.chdir(web_dir)
            print(f"已找到web目录：{web_dir}")
        except Exception as e:
            print(f"切换目录失败：{e}")
            input("按回车键退出...")
            return

        if not ensure_resource_files():
            print("创建必要的资源文件失败")
            input("按回车键退出...")
            return

        port = get_free_port()
        
        print(f"正在启动本地服务器...")
        server = HTTPServer(('localhost', port), CustomHandler)
        
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