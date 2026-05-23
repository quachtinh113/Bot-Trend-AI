import os
import time
import subprocess

# === CHƯƠNG TRÌNH DỪNG BOT AN TOÀN SỬ DỤNG CONTROL FILE (STOP BOT SCRIPT) ===

def main():
    print("---------------------------------------------------------")
    print("          GIA CAT SECURE STOP ENGINE")
    print("---------------------------------------------------------")
    
    # 1. Thử import thư viện MetaTrader5, nếu chưa có sẽ tự động cài đặt
    try:
        import MetaTrader5 as mt5
    except ImportError:
        print("Đang cài đặt thư viện MetaTrader5...")
        try:
            subprocess.check_call(["pip", "install", "MetaTrader5"])
            import MetaTrader5 as mt5
        except Exception as e:
            print(f"Không thể cài đặt thư viện MetaTrader5: {str(e)}")
            print("Thực hiện tắt ứng dụng cưỡng chế...")
            os.system("taskkill /f /im terminal64.exe")
            print("Đã đóng terminal MT5.")
            return

    print("Đang kết nối tới terminal MetaTrader 5 đang chạy...")
    if not mt5.initialize():
        print("[WARNING] Không thể kết nối tới API MT5.")
        print("Thực hiện tắt ứng dụng cưỡng chế...")
        os.system("taskkill /f /im terminal64.exe")
        print("Đã đóng terminal MT5.")
        return

    # Lấy đường dẫn dữ liệu MQL5 để ghi control file
    info = mt5.terminal_info()
    if info is not None:
        data_path = info.data_path
        control_file_path = os.path.join(data_path, "MQL5", "Files", "GiaCat_Control.txt")
        
        print(f"Ghi tín hiệu dừng khẩn cấp (HARD_KILL) vào tệp điều khiển...")
        try:
            # Tạo thư mục nếu chưa tồn tại
            os.makedirs(os.path.dirname(control_file_path), exist_ok=True)
            with open(control_file_path, "w", encoding="utf-8") as f:
                f.write("HARD_KILL")
            print(f"-> Đã kích hoạt chế độ HARD_KILL thành công.")
        except Exception as e:
            print(f"-> [WARNING] Không thể ghi file điều khiển: {str(e)}")
    else:
        print("-> [WARNING] Không thể lấy thông tin Data Path của Terminal.")

    print("Đợi 5 giây để Robot chốt đóng toàn bộ các vị thế đang chạy...")
    time.sleep(5)

    # Đóng kết nối API
    mt5.shutdown()

    # 2. Thực hiện đóng phần mềm terminal
    print("Đang đóng phần mềm MetaTrader 5...")
    os.system("taskkill /f /im terminal64.exe")
    
    # Dọn dẹp tệp điều khiển sau khi dừng để lần khởi động sau bot hoạt động bình thường
    if info is not None:
        try:
            if os.path.exists(control_file_path):
                os.remove(control_file_path)
        except:
            pass

    print("Hệ thống dừng hoàn tất! Mọi lệnh đã được chốt và đóng MT5 an toàn.")
    print("---------------------------------------------------------")

if __name__ == "__main__":
    main()
