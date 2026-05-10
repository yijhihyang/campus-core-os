"""
智慧取餐監控程式 v2
功能：
  1. 監聽 USB 讀卡機 HID 輸入
  2. 捕捉卡號後查詢 Supabase 確認學生身份
  3. 寫入打卡紀錄到 attendance table
  4. 推送刷卡事件到 scan_events table
  5. 取餐網頁透過 Realtime 即時顯示結果

安裝依賴：
  pip install keyboard requests

執行：
  Windows: python meal_monitor.py（用系統管理員身份）
  Mac:     sudo python meal_monitor.py

打包成 exe（Windows）：
  pip install pyinstaller
  pyinstaller --onefile meal_monitor.py
"""

import keyboard
import requests
import time
import logging
from datetime import datetime
from pathlib import Path

# ══════════════════════════════════════════
# ⚙️  設定區
# ══════════════════════════════════════════
SUPABASE_URL  = 'https://ixdowmddybxdesgdgecp.supabase.co'
SUPABASE_KEY  = 'sb_publishable_fjpfXR09MR3U9dTB4u2HAg_Heiy-W5s'
TIMEOUT       = 0.1   # 字元間隔超過此秒數視為新的一筆
# ══════════════════════════════════════════

# ── 日誌設定 ────────────────────────────
LOG_FILE = Path(__file__).parent / 'meal_monitor.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

# ── Supabase headers ─────────────────────
HEADERS = {
    'apikey':        SUPABASE_KEY,
    'Authorization': f'Bearer {SUPABASE_KEY}',
    'Content-Type':  'application/json',
    'Prefer':        'return=representation'
}

# ── 全域狀態 ─────────────────────────────
buffer     = []
last_time  = time.time()
scan_count = 0


# ════════════════════════════════════════
# Supabase 查詢函式
# ════════════════════════════════════════

def get_student_by_card(card_uid: str):
    """用卡號查詢學生資料"""
    try:
        res = requests.get(
            f'{SUPABASE_URL}/rest/v1/student',
            headers=HEADERS,
            params={
                'select':    'student_id,name,grade',
                'card_uid':  f'eq.{card_uid}',
                'is_active': 'eq.true',
                'limit':     '1'
            },
            timeout=5
        )
        data = res.json()
        return data[0] if data else None
    except Exception as e:
        log.error(f'查詢學生失敗: {e}')
        return None


def get_today_order(student_id: str):
    """查詢學生今日是否有訂餐"""
    today = datetime.now().strftime('%Y-%m-%d')
    try:
        res = requests.get(
            f'{SUPABASE_URL}/rest/v1/meal_orders',
            headers=HEADERS,
            params={
                'select':     'order_id,picked_up',
                'student_id': f'eq.{student_id}',
                'order_date': f'eq.{today}',
                'limit':      '1'
            },
            timeout=5
        )
        data = res.json()
        return data[0] if data else None
    except Exception as e:
        log.error(f'查詢訂單失敗: {e}')
        return None


def record_attendance(student_id: str) -> bool:
    """記錄到校打卡"""
    today = datetime.now().strftime('%Y-%m-%d')
    now   = datetime.now().isoformat()
    try:
        res = requests.post(
            f'{SUPABASE_URL}/rest/v1/attendance',
            headers={**HEADERS, 'Prefer': 'resolution=merge-duplicates,return=representation'},
            json={
                'student_id': student_id,
                'date':       today,
                'punched_at': now,
                'status':     'present'
            },
            timeout=5
        )
        return res.status_code in (200, 201)
    except Exception as e:
        log.error(f'記錄打卡失敗: {e}')
        return False


def push_scan_event(student: dict, order) -> bool:
    """推送刷卡事件到 scan_events，取餐網頁透過 Realtime 接收"""
    try:
        res = requests.post(
            f'{SUPABASE_URL}/rest/v1/scan_events',
            headers=HEADERS,
            json={
                'student_id':   student['student_id'],
                'student_name': student['name'],
                'grade':        student.get('grade', ''),
                'has_order':    order is not None,
                'order_id':     order['order_id'] if order else None,
                'scanned_at':   datetime.now().isoformat()
            },
            timeout=5
        )
        return res.status_code in (200, 201)
    except Exception as e:
        log.error(f'推送事件失敗: {e}')
        return False


# ════════════════════════════════════════
# 刷卡處理主邏輯
# ════════════════════════════════════════

def handle_card(card_uid: str):
    global scan_count
    scan_count += 1
    log.info(f'[第{scan_count}次] 偵測到卡號：{card_uid}')

    # 1. 查學生
    student = get_student_by_card(card_uid)
    if not student:
        log.warning(f'卡號 {card_uid} 查無學生')
        push_scan_event(
            {'student_id': None, 'name': '未知卡號', 'grade': ''},
            None
        )
        return

    log.info(f'學生：{student["name"]} ({student.get("grade", "")})')

    # 2. 記錄到校打卡
    ok = record_attendance(student['student_id'])
    log.info(f'打卡記錄：{"成功" if ok else "失敗"}')

    # 3. 查今日訂餐
    order = get_today_order(student['student_id'])
    log.info(f'今日訂餐：{"有" if order else "無"}')

    # 4. 推送到取餐網頁
    ok = push_scan_event(student, order)
    log.info(f'推送事件：{"成功" if ok else "失敗"}')


# ════════════════════════════════════════
# HID 鍵盤監聽
# ════════════════════════════════════════

def on_key(event):
    global buffer, last_time

    now = time.time()
    if now - last_time > TIMEOUT and buffer:
        buffer.clear()
    last_time = now

    if event.name == 'enter':
        if buffer:
            card_uid = ''.join(buffer).strip()
            buffer.clear()
            handle_card(card_uid)
        return

    if len(event.name) == 1:
        buffer.append(event.name)


# ════════════════════════════════════════
# 啟動
# ════════════════════════════════════════

if __name__ == '__main__':
    log.info('══════════════════════════════════')
    log.info('  智慧取餐監控程式 v2 啟動')
    log.info(f'  Supabase: {SUPABASE_URL}')
    log.info('  等待刷卡...')
    log.info('══════════════════════════════════')

    keyboard.on_press(on_key)

    try:
        keyboard.wait()
    except KeyboardInterrupt:
        log.info(f'程式結束，共處理 {scan_count} 次刷卡')
