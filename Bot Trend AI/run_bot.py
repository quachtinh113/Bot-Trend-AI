import os
import time
import subprocess
from dotenv import load_dotenv

# === CHƯƠNG TRÌNH KHỞI CHẠY BOT TỰ ĐỘNG & BẢO MẬT (RUN BOT SCRIPT) ===

def find_terminal_path():
    """Tìm đường dẫn tệp terminal64.exe cài đặt trên máy"""
    # 1. Kiểm tra cấu hình trong .env trước
    env_path = os.getenv("MT5_TERMINAL_PATH")
    if env_path and os.path.exists(env_path):
        return env_path
        
    # 2. Các đường dẫn mặc định thông dụng
    default_paths = [
        "C:\\Program Files\\MetaTrader 5 EXNESS\\terminal64.exe",
        "C:\\Program Files\\MetaTrader 5\\terminal64.exe",
        "C:\\Program Files (x86)\\MetaTrader 5\\terminal64.exe"
    ]
    
    for path in default_paths:
        if os.path.exists(path):
            return path
            
    return None

def launch_bot():
    # Tải cấu hình .env
    load_dotenv()
    
    login = os.getenv("MT5_LOGIN")
    password = os.getenv("MT5_PASSWORD")
    server = os.getenv("MT5_SERVER")
    
    if not login or not password or not server:
        print("CRITICAL ERROR: Vui lòng điền đầy đủ MT5_LOGIN, MT5_PASSWORD, MT5_SERVER trong file .env!")
        return
        
    terminal_path = find_terminal_path()
    if not terminal_path:
        print("CRITICAL ERROR: Không tìm thấy tệp terminal64.exe trên máy tính!")
        print("Vui lòng khai báo đường dẫn thủ công trong file .env dưới biến MT5_TERMINAL_PATH.")
        return

    # Lấy đường dẫn tuyệt đối của preset cấu hình
    current_dir = os.path.dirname(os.path.abspath(__file__))
    preset_path = os.path.join(current_dir, "release_v1_demo_config.set")
    
    # 3. Tạo tệp cấu hình tạm thời chứa thông tin đăng nhập
    config_ini_path = os.path.join(current_dir, "temp_run_config.ini")
    
    ini_content = f"""[Common]
Login={login}
Password={password}
Server={server}
AutoConfiguration=true
ProxyEnable=false

[Charts]
Symbol=XAUUSD
Period=M5
Expert=GiaCat_Ultimate_Session
ExpertParameters={preset_path}
"""

    try:
        # Ghi file cấu hình tạm
        with open(config_ini_path, "w", encoding="utf-8") as f:
            f.write(ini_content)
        
        print("---------------------------------------------------------")
        print("          GIA CAT AUTORUN ENGINE STARTING...")
        print("---------------------------------------------------------")
        print(f"Khởi động MT5: {terminal_path}")
        print("Đang nạp tham số cấu hình bảo mật tạm thời...")
        
        # 4. Gọi terminal64.exe chạy với file cấu hình ini
        cmd = f'"{terminal_path}" /config:"{config_ini_path}"'
        subprocess.Popen(cmd, shell=True)
        
        # Đợi 5 giây để terminal khởi chạy và đọc xong cấu hình ini
        print("Đang đồng bộ thông tin đăng nhập...")
        time.sleep(5)
        
    except Exception as e:
        print(f"Lỗi trong quá trình khởi chạy: {str(e)}")
        
    finally:
        # 5. XÓA BỎ NGAY tệp cấu hình chứa mật khẩu thô để đảm bảo an toàn
        if os.path.exists(config_ini_path):
            os.remove(config_ini_path)
            print("Đã xóa tệp cấu hình tạm thời chứa mật khẩu để bảo mật.")
            print("Khởi chạy BOT thành công và an toàn!")
            print("---------------------------------------------------------")

if __name__ == "__main__":
    launch_bot()
