import os
import time
import subprocess
from dotenv import load_dotenv

def find_terminal_path():
    env_path = os.getenv("MT5_TERMINAL_PATH")
    if env_path and os.path.exists(env_path):
        return env_path
    default_paths = [
        "C:\\Program Files\\MetaTrader 5 EXNESS\\terminal64.exe",
        "C:\\Program Files\\MetaTrader 5\\terminal64.exe",
        "C:\\Program Files (x86)\\MetaTrader 5\\terminal64.exe"
    ]
    for path in default_paths:
        if os.path.exists(path):
            return path
    return None

def run():
    load_dotenv()
    login = "415764545"
    password = "87u3D1$6"
    server = "Exness-MT5Trial14"
    
    current_dir = os.path.dirname(os.path.abspath(__file__))
    config_ini_path = os.path.join(current_dir, "temp_login_config.ini")
    
    ini_content = f"""[Common]
Login={login}
Password={password}
Server={server}
AutoConfiguration=true
ProxyEnable=false
"""
    with open(config_ini_path, "w", encoding="utf-16") as f:
        f.write(ini_content)
        
    terminal_path = find_terminal_path()
    if not terminal_path:
        print("ERROR: terminal64.exe not found!")
        return
        
    print(f"Launching MT5 terminal to authorize and cache account {login} on {server}...")
    cmd = f'"{terminal_path}" /config:"{config_ini_path}"'
    subprocess.Popen(cmd, shell=True)
    
    # Wait for the terminal to authorize and connect
    print("Waiting 15 seconds for connection...")
    time.sleep(15)
    
    # Clean up ini
    if os.path.exists(config_ini_path):
        os.remove(config_ini_path)
        
    # Close MT5 terminal
    print("Closing MT5 terminal...")
    os.system("taskkill /f /im terminal64.exe")
    print("Account authorization and link completed successfully!")

if __name__ == "__main__":
    run()
