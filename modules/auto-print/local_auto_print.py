# -*- coding: utf-8 -*-
import subprocess
import os

def smart_print(file_path, copies=1, duplex=True, pages=None):
    # 1. 取得你的印表機精確名稱
    # 你可以執行 lpstat -p 確認，根據你的截圖應該是 "HP_LaserJet_M15w__90F2D3_"
    # 注意：指令中的名稱通常會把空格換成底線
    printer_name = "HP_LaserJet_M15w__90F2D3_" 

    if not os.path.exists(file_path):
        print(f"找不到檔案: {file_path}")
        return

    # 2. 組合 lp 指令參數
    # -d: 指定印表機
    # -n: 份數
    # -o media=A4: 紙張大小
    # -o fit-to-page: 這就是你要求的「縮放比例：以可列印範圍自動調整」
    # -o sides: 雙面設定
    # -o number-up=1: 每張工作表頁數 1
    cmd = [
        "lp",
        "-d", printer_name,
        "-n", str(copies),
        "-o", "media=A4",
        "-o", "fit-to-page",
        "-o", f"sides={'two-sided-long-edge' if duplex else 'one-sided'}",
        "-o", "number-up=1",
        file_path
    ]

# 指定列印頁數 (例如 "1-2")
    if pages:
        cmd.extend(["-P", str(pages)])

    cmd.append(file_path)

    try:
        print(f"正在送往 HP 印表機: {os.path.basename(file_path)}")
        subprocess.run(cmd, check=True)
        print("列印指令已成功送出！")
    except subprocess.CalledProcessError:
        print("列印失敗，請檢查印表機名稱是否正確。")

# 測試
test_file = "/Users/yy/Desktop/0402國三輔導卷_理學_5-6冊_學用.pdf" 
smart_print(test_file, copies=1, duplex=True,pages="2")
