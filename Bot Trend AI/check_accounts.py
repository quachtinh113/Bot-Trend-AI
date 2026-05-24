import os
import time
import MetaTrader5 as mt5

def check_account(label, login, password, server):
    print("=" * 60)
    print(f"CHECKING ACCOUNT [{label}]: {login} on {server}...")
    print("=" * 60)
    
    default_paths = [
        "C:\\Program Files\\MetaTrader 5 EXNESS\\terminal64.exe",
        "C:\\Program Files\\MetaTrader 5\\terminal64.exe",
        "C:\\Program Files (x86)\\MetaTrader 5\\terminal64.exe"
    ]
    terminal_path = None
    for p in default_paths:
        if os.path.exists(p):
            terminal_path = p
            break
            
    if terminal_path:
        initialized = mt5.initialize(path=terminal_path)
    else:
        initialized = mt5.initialize()
        
    if not initialized:
        print(f"ERROR: Failed to connect to MT5! Error code: {mt5.last_error()}")
        return False
        
    # Attempt login
    login_success = mt5.login(login=int(login), password=password, server=server)
    if not login_success:
        print(f"FAILED to log in! Error code: {mt5.last_error()}")
        mt5.shutdown()
        return False
        
    # Fetch account info
    info = mt5.account_info()
    if info is None:
        print("FAILED to retrieve account info!")
    else:
        print(f"STATUS     : SUCCESS")
        print(f"Name       : {info.name}")
        print(f"Server     : {info.server}")
        print(f"Balance    : {info.balance:.2f} {info.currency}")
        print(f"Equity     : {info.equity:.2f} {info.currency}")
        print(f"Leverage   : 1:{info.leverage}")
        print(f"Company    : {info.company}")
        trade_mode_desc = "Demo/Trial" if info.trade_mode != 0 else "Demo/Trial"
        if info.trade_mode == 2:
            trade_mode_desc = "Real/Live"
        print(f"Trade Mode : {info.trade_mode} ({trade_mode_desc})")
        print(f"Allowed    : Trading={info.trade_allowed}, Expert={info.trade_expert}")
        
    mt5.shutdown()
    return True

if __name__ == "__main__":
    # Kill any running terminal first to start fresh
    os.system("taskkill /f /im terminal64.exe >nul 2>&1")
    time.sleep(2)
    
    check_account("MASTERTRADER", "415764545", "87u3D1$6", "Exness-MT5Trial14")
    time.sleep(3)
    
    # Kill terminal between checks to ensure clean session state
    os.system("taskkill /f /im terminal64.exe >nul 2>&1")
    time.sleep(2)
    
    check_account("US100", "463316450", "87u3D1$6", "Exness-MT5Trial17")
    time.sleep(2)
    
    # Clean up at the end
    os.system("taskkill /f /im terminal64.exe >nul 2>&1")
