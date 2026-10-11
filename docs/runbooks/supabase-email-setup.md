# Supabase 寄信（SMTP）與登入信件設定

報名表和後台都用「Email 驗證碼」登入，信件由 Supabase 寄出。

## 為什麼要自訂 SMTP
Supabase 內建寄信服務每小時只能寄很少幾封（會出現 `email rate limit exceeded`），只適合測試。
自訂 SMTP 就是讓 Supabase 改用我們自己的信箱寄信。

## 目前設定（dev 專案）
位置：Supabase → Authentication → Emails → SMTP Settings

| 欄位 | 值 |
|---|---|
| Sender email | yijhihyang@gmail.com |
| Sender name | 金牌集團活動組（測試） |
| Host | smtp.gmail.com |
| Port | 465 |
| Username | yijhihyang@gmail.com |
| Password | Google「應用程式密碼」（只存在 Supabase，不寫進任何文件） |

- Gmail 的寄件人必須和登入帳號相同。
- 應用程式密碼在 https://myaccount.google.com/apppasswords 產生；需要先開兩步驟驗證。外洩時到同一頁刪除再重產生。

## 其他相關設定
- **Rate Limits**：email 每小時上限調高（例如 100）。
- **Templates → Magic Link**：信件內容要包含 `{{ .Token }}`，信裡才會有 6 位數驗證碼；可同時保留 `{{ .ConfirmationURL }}` 登入連結。
- **URL Configuration**：
  - Site URL：考猜報名表網址
  - Redirect URLs：`https://yijhihyang.github.io/campus-core-os/**`

## 正式環境（prod）待辦
- 改用補習班公用信箱寄信，寄件人名稱用「金牌集團活動組」。
