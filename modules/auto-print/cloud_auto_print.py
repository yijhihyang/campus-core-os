import os
import tempfile
import subprocess
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
import io

def invisible_print(drive_service, file_id, file_name, copies=1, pages=None):
    # 1. 建立一個「隱形」的暫存檔案空間
    # suffix='.pdf' 確保 lp 指令能識別這是 PDF 格式
    with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as tmp_file:
        temp_path = tmp_file.name
        
        try:
            # 2. 執行第一次 Cmd + P (從雲端抓取數據)
            print(f"正在隱形抓取：{file_name}...")
            request = drive_service.files().get_media(fileId=file_id)
            fh = io.FileIO(temp_path, 'wb')
            downloader = MediaIoBaseDownload(fh, request)
            done = False
            while done is False:
                status, done = downloader.next_chunk()

            # 3. 執行第二次 Cmd + P (發送至印表機)
            # 這裡就是你之前測試成功的 lp 指令
            print(f"正在發送列印：{file_name} (頁數: {pages if pages else '全部'})")
            
            cmd = [
                "lp",
                "-d", "HP_LaserJet_M15w__90F2D3_", # 你的印表機名稱
                "-n", str(copies),
                "-o", "media=A4",
                "-o", "fit-to-page",
                "-o", "sides=two-sided-long-edge"
            ]
            if pages:
                cmd.extend(["-P", str(pages)])
            
            cmd.append(temp_path)
            subprocess.run(cmd, check=True)

        finally:
            # 4. 任務達成，立刻毀屍滅跡
            # 不管列印成功或失敗，這行都會確保暫存檔被刪除
            if os.path.exists(temp_path):
                os.remove(temp_path)
                print(f"暫存檔已清理，空間已釋放。")

# 假設從 Google Sheets 抓到 10 個 ID，就跑 10 次這個 function
