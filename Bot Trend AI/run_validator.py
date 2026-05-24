import os
import shutil
import time
import subprocess
from dotenv import load_dotenv
import MetaTrader5 as mt5

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
    
    terminal_path = find_terminal_path()
    initialized = False
    if terminal_path:
        print(f"Initializing MT5 with terminal path: {terminal_path}")
        initialized = mt5.initialize(path=terminal_path)
    else:
        print("Initializing MT5 with default path...")
        initialized = mt5.initialize()
        
    if not initialized:
        print("ERROR: Failed to connect to MT5 API!")
        print(f"MT5 Last Error: {mt5.last_error()}")
        return
    
    # Programmatic login using .env credentials
    env_login = os.getenv("MT5_LOGIN")
    env_password = os.getenv("MT5_PASSWORD")
    env_server = os.getenv("MT5_SERVER")
    if env_login and env_password and env_server:
        try:
            login_num = int(env_login)
            print(f"Logging in to {login_num} on {env_server}...")
            login_ok = mt5.login(login=login_num, password=env_password, server=env_server)
            if not login_ok:
                print(f"WARNING: mt5.login returned False. Error: {mt5.last_error()}")
            # Wait a few seconds for synchronization after login
            time.sleep(5)
        except Exception as e:
            print(f"WARNING: Exception during programmatic login: {e}")

    info = mt5.terminal_info()
    data_path = info.data_path
    
    # Get active account login and server
    account_info = mt5.account_info()
    active_login = account_info.login
    active_server = account_info.server
    print(f"Active Session Login: {active_login} on {active_server}")
    
    # Detect the correct XAUUSD symbol (e.g. XAUUSDm or XAUUSD)
    gold_symbols = [s.name for s in mt5.symbols_get() if "XAUUSD" in s.name]
    detected_symbol = gold_symbols[0] if gold_symbols else "XAUUSD"
    print(f"Detected Gold Symbol: {detected_symbol}")
    
    mt5.shutdown()
    
    print(f"MT5 Data Path: {data_path}")
    
    # 2. Copy deployment_validator.ex5 to MQL5/Scripts
    current_dir = os.path.dirname(os.path.abspath(__file__))
    src_ex5 = os.path.join(current_dir, "deployment_validator.ex5")
    dest_dir = os.path.join(data_path, "MQL5", "Scripts")
    os.makedirs(dest_dir, exist_ok=True)
    dest_ex5 = os.path.join(dest_dir, "deployment_validator.ex5")
    shutil.copy2(src_ex5, dest_ex5)
    print(f"Copied {src_ex5} -> {dest_ex5}")
    
    # 3. Create a dynamic .env in MQL5/Files matching the active session
    dest_files_dir = os.path.join(data_path, "MQL5", "Files")
    os.makedirs(dest_files_dir, exist_ok=True)
    dest_env = os.path.join(dest_files_dir, ".env")
    
    # Read the existing .env file
    src_env = os.path.join(current_dir, ".env")
    env_lines = []
    if os.path.exists(src_env):
        with open(src_env, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("MT5_LOGIN="):
                    env_lines.append(f"MT5_LOGIN={active_login}\n")
                elif line.startswith("MT5_SERVER="):
                    env_lines.append(f"MT5_SERVER={active_server}\n")
                else:
                    env_lines.append(line)
    else:
        env_lines = [
            f"MT5_LOGIN={active_login}\n",
            f"MT5_SERVER={active_server}\n",
            "ENV_MODE=DEMO\n",
            "ALLOW_REAL_TRADING=false\n",
            "MAX_DAILY_DD_PERCENT=2.0\n",
            "MAX_WEEKLY_DD_PERCENT=5.0\n",
            "HARD_KILL_DD_PERCENT=8.0\n"
        ]
        
    with open(dest_env, "w", encoding="utf-8") as f:
        f.writelines(env_lines)
    print(f"Created active-session .env in sandbox: {dest_env}")
    
    # 4. Generate temporary ini config to run the script using current active session
    config_ini_path = os.path.join(current_dir, "temp_validator_config.ini")
    ini_content = f"""[Charts]
Symbol={detected_symbol}
Period=M5

[Script]
Name=deployment_validator
UseInputs=false
"""
    with open(config_ini_path, "w", encoding="utf-16") as f:
        f.write(ini_content)
        
    terminal_path = find_terminal_path()
    if not terminal_path:
        print("ERROR: terminal64.exe not found!")
        return
        
    print("Launching MT5 terminal to execute validator script...")
    cmd = f'"{terminal_path}" /config:"{config_ini_path}"'
    subprocess.Popen(cmd, shell=True)
    
    # 5. Wait for report to be generated
    report_path = os.path.join(dest_files_dir, "deployment_check_report.md")
    report_json = os.path.join(dest_files_dir, "deployment_check_report.json")
    
    # Delete existing reports in workspace first if they exist
    ws_report_path = os.path.join(current_dir, "deployment_check_report.md")
    ws_report_json = os.path.join(current_dir, "deployment_check_report.json")
    if os.path.exists(ws_report_path):
        os.remove(ws_report_path)
    if os.path.exists(ws_report_json):
        os.remove(ws_report_json)
        
    print("Waiting for deployment check report...")
    timeout = 90
    start_time = time.time()
    success = False
    while time.time() - start_time < timeout:
        if os.path.exists(report_path) and os.path.exists(report_json):
            time.sleep(2) # Make sure write is completed
            success = True
            break
        time.sleep(1)
        
    if success:
        # Copy reports back to workspace
        shutil.copy2(report_path, ws_report_path)
        shutil.copy2(report_json, ws_report_json)
        print("Architecture validation report synchronized successfully!")
        print(f"-> {ws_report_path}")
        print(f"-> {ws_report_json}")
    else:
        print("ERROR: Timeout waiting for report generation!")
        
    # Clean up ini
    if os.path.exists(config_ini_path):
        os.remove(config_ini_path)
        
    # Close MT5 terminal
    print("Closing MT5 terminal...")
    os.system("taskkill /f /im terminal64.exe")

if __name__ == "__main__":
    run()
