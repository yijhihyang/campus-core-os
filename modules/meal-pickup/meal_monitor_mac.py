# -*- coding: utf-8 -*-
"""
智慧取餐監控程式 v2 (Mac 版)
使用 sys.stdin 讀取 HID 輸入，不需要 keyboard 套件

執行方式：
  sudo python3 meal_monitor_mac.py

安裝依賴：
  pip3 install requests
"""

import sys
import requests
import logging
from datetime import datetime
from pathlib import Path

# ══════════════════════════════════════════
# ⚙️  設定區
# ══════════════════════════════════════════
SUPABASE_URL  = 'https://ixdowmddybxdesgdgecp.supabase.co'
SUPABASE_KEY  = 'sb_publishable_fjpfXR09MR3U9dTB4u2HAg_Heiy-W5s'
# ══════════════════════════════════════════

# ── 日誌設定 ────────────────────────────
LOG_FILE = Path(__file__).parent / 'meal_monitor.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(str(LOG_FILE), encoding='utf-8'),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

# ── Supabase headers ─────────────────────
HEADERS = {
    'apikey':        SUPABASE_KEY,
    'Authorization': 'Bearer ' + SUPABASE_KEY,
    'Content-Type':  'application/json',
    'Prefer':        'return=representation'
}

scan_count = 0


# ════════════════════════════════════════
# Supabase 查詢函式
# ════════════════════════════════════════

def get_student_by_card(card_uid):
    try:
        res = requests.get(
            SUPABASE_URL + '/rest/v1/student',
            headers=HEADERS,
            params={
                'select':    'student_id,name,grade',
                'card_uid':  'eq.' + card_uid,
                'is_active': 'eq.true',
                'limit':     '1'
            },
            timeout=5
        )
        data = res.json()
        return data[0] if data else None
    except Exception as e:
        log.error(u'查詢學生失敗: ' + str(e))
        return None


def get_today_order(student_id):
    today = datetime.now().strftime('%Y-%m-%d')
    try:
        res = requests.get(
            SUPABASE_URL + '/rest/v1/meal_orders',
            headers=HEADERS,
            params={
                'select':     'order_id,picked_up',
                'student_id': 'eq.' + student_id,
                'order_date': 'eq.' + today,
                'limit':      '1'
            },
            timeout=5
        )
        data = res.json()
        return data[0] if data else None
    except Exception as e:
        log.error(u'查詢訂單失敗: ' + str(e))
        return None


def record_attendance(student_id):
    today = datetime.now().strftime('%Y-%m-%d')
    now   = datetime.now().isoformat()
    try:
        res = requests.post(
            SUPABASE_URL + '/rest/v1/attendance',
            headers=dict(list(HEADERS.items()) + [('Prefer', 'resolution=merge-duplicates,return=representation')]),
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
        log.error(u'記錄打卡失敗: ' + str(e))
        return False


def push_scan_event(student, order):
    try:
        if student['student_id'] is None:
            payload = {
                'student_name': student['name'],
                'grade':        '',
                'has_order':    False,
                'scanned_at':   datetime.now().isoformat()
            }
        else:
            payload = {
                'student_id':   student['student_id'],
                'student_name': student['name'],
                'grade':        student.get('grade', ''),
                'has_order':    order is not None,
                'order_id':     order['order_id'] if order else None,
                'scanned_at':   datetime.now().isoformat()
            }
        res = requests.post(
            SUPABASE_URL + '/rest/v1/scan_events',
            headers=HEADERS,
            json=payload,
            timeout=5
        )
        log.info(u'推送狀態: ' + str(res.status_code))
        return res.status_code in (200, 201)
    except Exception as e:
        log.error(u'推送事件失敗: ' + str(e))
        return False


# ════════════════════════════════════════
# 刷卡處理主邏輯
# ════════════════════════════════════════

def handle_card(card_uid):
    global scan_count
    scan_count += 1
    log.info(u'[第' + str(scan_count) + u'次] 偵測到卡號：' + card_uid)

    student = get_student_by_card(card_uid)
    if not student:
        log.warning(u'卡號 ' + card_uid + u' 查無學生')
        ok = push_scan_event({'student_id': None, 'name': u'未知卡號', 'grade': ''}, None)
        log.info(u'推送未知卡號：' + (u'成功' if ok else u'失敗'))
        return

    log.info(u'學生：' + student['name'])

    ok = record_attendance(student['student_id'])
    log.info(u'打卡記錄：' + (u'成功' if ok else u'失敗'))

    order = get_today_order(student['student_id'])
    log.info(u'今日訂餐：' + (u'有' if order else u'無'))

    ok = push_scan_event(student, order)
    log.info(u'推送事件：' + (u'成功' if ok else u'失敗'))


# ════════════════════════════════════════
# 主程式：用 stdin 讀取 HID 輸入
# ════════════════════════════════════════

if __name__ == '__main__':
    import tty
    import termios

    log.info(u'══════════════════════════════════')
    log.info(u'  智慧取餐監控程式 v2 (Mac) 啟動')
    log.info(u'  Supabase: ' + SUPABASE_URL)
    log.info(u'  等待刷卡...')
    log.info(u'  (按 Ctrl+C 結束)')
    log.info(u'══════════════════════════════════')

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    try:
        tty.setraw(fd)
        buffer = []

        while True:
            ch = sys.stdin.read(1)

            # Ctrl+C 結束
            if ch == '\x03':
                break

            # Enter 鍵（讀卡機輸入完畢）
            if ch in ('\r', '\n'):
                if buffer:
                    card_uid = ''.join(buffer).strip()
                    buffer = []
                    if card_uid:
                        handle_card(card_uid)
                continue

            buffer.append(ch)

    except Exception as e:
        log.error(u'程式錯誤: ' + str(e))
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        log.info(u'程式結束，共處理 ' + str(scan_count) + u' 次刷卡')
