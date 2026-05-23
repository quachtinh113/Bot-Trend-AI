import os
import re
from dotenv import load_dotenv

# === BỘ TẢI VÀ KIỂM TRA CẤU HÌNH AN TOÀN (CONFIG LOADER) ===

def mask_login(login_str):
    """Mã hóa một phần số tài khoản MT5 (Hiển thị 4 số đầu và 4 số cuối)"""
    if not login_str:
        return "[EMPTY]"
    s = str(login_str).strip()
    if len(s) <= 8:
        return s[:2] + "*" * (len(s) - 4) + s[-2:] if len(s) > 4 else "****"
    return s[:4] + "*" * (len(s) - 8) + s[-4:]

def mask_telegram_token(token_str):
    """Mã hóa token Telegram (Hiển thị 6 ký tự đầu và 4 ký tự cuối)"""
    if not token_str:
        return "[EMPTY]"
    s = str(token_str).strip()
    if len(s) <= 10:
        return s[:3] + "******" + s[-2:] if len(s) > 5 else "******"
    return s[:6] + "******" + s[-4:]

def load_and_validate_config():
    """Tải cấu hình từ file .env và thực hiện xác thực an toàn"""
    # Tải file .env từ thư mục hiện tại
    load_dotenv()
    
    config = {
        "MT5_LOGIN": os.getenv("MT5_LOGIN"),
        "MT5_PASSWORD": os.getenv("MT5_PASSWORD"),
        "MT5_SERVER": os.getenv("MT5_SERVER"),
        "TELEGRAM_BOT_TOKEN": os.getenv("TELEGRAM_BOT_TOKEN"),
        "TELEGRAM_CHAT_ID": os.getenv("TELEGRAM_CHAT_ID"),
        "ENV_MODE": os.getenv("ENV_MODE", "DEMO").upper(),
        "ALLOW_REAL_TRADING": os.getenv("ALLOW_REAL_TRADING", "false").lower() == "true",
        "MAX_DAILY_DD_PERCENT": float(os.getenv("MAX_DAILY_DD_PERCENT", "2.0")),
        "MAX_WEEKLY_DD_PERCENT": float(os.getenv("MAX_WEEKLY_DD_PERCENT", "5.0")),
        "HARD_KILL_DD_PERCENT": float(os.getenv("HARD_KILL_DD_PERCENT", "8.0"))
    }
    
    # 1. Kiểm tra các tham số bắt buộc
    required_fields = ["MT5_LOGIN", "MT5_PASSWORD", "MT5_SERVER"]
    missing_fields = [field for field in required_fields if not config[field]]
    if missing_fields:
        raise ValueError(f"CRITICAL ERROR: Thiếu các tham số cấu hình bắt buộc trong .env: {', '.join(missing_fields)}")
        
    return config

def print_safe_config(config):
    """In cấu hình đã được ẩn thông tin nhạy cảm ra màn hình/nhật ký"""
    print("=========================================================")
    print("      GIA CAT SECURE CONFIGURATION SYSTEM LOADED")
    print("=========================================================")
    print(f"MT5 Account Login : {mask_login(config['MT5_LOGIN'])}")
    print(f"MT5 Account Server: {config['MT5_SERVER']}")
    print(f"MT5 Password      : [MASKED]")
    print(f"Telegram Bot Token: {mask_telegram_token(config['TELEGRAM_BOT_TOKEN'])}")
    print(f"Telegram Chat ID  : {config['TELEGRAM_CHAT_ID']}")
    print(f"Runtime Mode      : {config['ENV_MODE']}")
    print(f"Real Trade Allowed: {config['ALLOW_REAL_TRADING']}")
    print(f"Daily DD Budget   : {config['MAX_DAILY_DD_PERCENT']}%")
    print(f"Weekly DD Budget  : {config['MAX_WEEKLY_DD_PERCENT']}%")
    print(f"Hard Kill Threshold: {config['HARD_KILL_DD_PERCENT']}%")
    print("=========================================================")

if __name__ == "__main__":
    # Test thử bộ nạp cấu hình (nếu chưa có file .env sẽ báo lỗi missing)
    try:
        cfg = load_and_validate_config()
        print_safe_config(cfg)
    except Exception as e:
        print(f"Config Validation Status: {str(e)}")
