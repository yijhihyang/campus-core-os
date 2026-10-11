# 0002 考猜後台改用自製網頁，不用 Retool

> 狀態：已決定
> 日期：2026-10-11

## 背景
考猜後台原本用 Retool 建置，但 Retool 的 AI 額度用完，已發佈的 App 也要登入 Retool 帳號才能開。

## 考慮過的選項
1. **Retool**：元件現成；但受額度與帳號限制，客製化（例如拖拉排座位）不易。
2. **自製網頁（GitHub Pages）＋ Supabase**：免費、可完全客製；登入用 Supabase Email 驗證碼，權限寫在資料庫的 RPC 裡。

## 決定
選 2（架構 B）。後台網頁放在 `/modules/kaocai-site/admin.html`，透過 GitHub Pages 發佈。

## 影響
- 後台權限由資料庫判斷：登入 Email 必須在 `teacher` 或 `staff` 表、且 `is_active = true`。
- Retool 的 App 與資料庫連線帳號（`retool_kaocai`）之後要清除。
