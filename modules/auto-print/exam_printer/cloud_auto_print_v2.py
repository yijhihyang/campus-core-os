import gspread
from google.oauth2.service_account import Credentials
import subprocess
import time
import os
import io
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload

# --- 設定區 ---
CREDENTIALS_FILE = 'credentials.json' # 請確保此檔案與腳本在同一個資料夾
SPREADSHEET_NAME = "考卷得來速"
SHEET_NAME = "temp_print_job"
CHECK_INTERVAL = 10  # 每 10 秒檢查一次雲端有無新任務

def download_file_from_drive(file_id, file_name):
    # 建立 Drive API 服務
    scope = ['https://www.googleapis.com/auth/drive']
    creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    service = build('drive', 'v3', credentials=creds)

    print(f"   正在從雲端下載: {file_name}...")
    
    request = service.files().get_media(fileId=file_id)
    # 確保檔名結尾有 .pdf
    if not file_name.lower().endswith('.pdf'):
        file_name += ".pdf"
        
    file_path = os.path.join(os.getcwd(), file_name)
    
    with io.FileIO(file_path, 'wb') as fh:
        downloader = MediaIoBaseDownload(fh, request)
        done = False
        while done is False:
            status, done = downloader.next_chunk()
    
    return file_path

def execute_printing_mission():
    # 1. 登入 Google Sheet
    
    scope = [
        'https://www.googleapis.com/auth/spreadsheets',
        'https://www.googleapis.com/auth/drive'
    ] 
    try:
        creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
        client = gspread.authorize(creds)
        spreadsheet = client.open(SPREADSHEET_NAME)
        temp_sheet = spreadsheet.worksheet(SHEET_NAME)
    except Exception as e:
        print(f"❌ 連線失敗或找不到檔案: {e}")
        return

    print(f"📡 監控中... 只要在 Google Sheet 點擊打包，我就會自動列印。")

    while True:
        try:
            # 2. 取得所有待列印任務
            tasks = temp_sheet.get_all_records()

            if tasks:
                print(f"📦 偵測到 {len(tasks)} 件任務，開始處理...")
                
                for task in tasks:
                    file_name = task.get('檔案名稱', '未知檔案')
                    file_id   = task.get('檔案ID', '')
                    pages     = str(task.get('頁數', ''))
                    copies    = int(task.get('份數', 1))
                    
                    if not file_id: continue

                    # 3. 下載檔案
                    pdf_path = download_file_from_drive(file_id, file_name)

                    # 4. 組裝 Mac 列印指令 (lp)
                    print(f" 正在列印：{file_name} (份數: {copies}, 頁數: {pages})")
                    
                    lp_command = [
                        "lp",
                        "-d", "HP_LaserJet_M15w__90F2D3_", # 請確認印表機名稱正確
                        "-n", str(copies),
                        "-o", "media=A4",
                        "-o", "sides=two-sided-long-edge",
                        "-o", "Duplex=DuplexNoTumble",      # 強制長邊翻頁
                        "-o", "fit-to-page"
                    ]
                    
                    if pages and pages.strip() and pages != "nan":
                        lp_command.extend(["-P", pages])
                    
                    lp_command.append(pdf_path)

                    # 5. 執行列印
                    try:
                        subprocess.run(lp_command, check=True)
                        print(f"    {file_name} 已成功送往印表機")
                    except Exception as e:
                        print(f"    列印失敗: {e}")

                # 6. 任務全數完成後，立刻清空雲端清單，避免重複列印
                # resize(1) 會保留標題列並刪除下方所有資料
                temp_sheet.resize(1)
                print("🧹 雲端清單已清空，回到待命狀態。")
            
        except Exception as e:
            print(f"⚠️循環檢查時發生錯誤 (將在 10 秒後重試): {e}")

        # 等待設定的時間後再次檢查
        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    # 啟動自動監控
    execute_printing_mission()
