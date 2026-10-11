# CampusCore OS 設計手冊（Handbook）

這裡是 CampusCore OS 所有設計文件的唯一存放處。文件跟程式碼放在同一個 repo、一起 commit，
所以每次改設計都有版本紀錄，也能在 GitHub 上直接閱讀。

## 資料夾結構

| 資料夾 | 放什麼 | 例子 |
|---|---|---|
| `architecture/` | 整個系統共用的設計：資料庫總覽、權限模型、登入方式、環境（dev／prod） | 資料表關係、RLS 原則 |
| `modules/<模組名>/` | 單一模組的設計文件，一個模組一個資料夾，名稱對應 `/modules/` 底下的程式資料夾 | `modules/kaocai/` |
| `decisions/` | 重要決定的紀錄（ADR）：當時為什麼這樣選、考慮過哪些選項 | 為什麼不用 Retool |
| `runbooks/` | 操作手冊：照著做就能完成的步驟 | 部署網頁、設定寄信 |
| `templates/` | 新文件的範本，複製後再改 | 設計文件範本、決定紀錄範本 |

## 寫作規則

1. **檔名**用英文小寫加連字號，例如 `multi-branch-design.md`；內容用中文寫。
2. **決定紀錄**依序編號：`0001-xxx.md`、`0002-xxx.md`，寫好之後不改內容；決定被推翻時，另寫一份新的，並在舊的那份標註「已被 00xx 取代」。
3. **每份設計文件開頭**都要寫狀態：`草稿`／`討論中`／`已定案`／`已實作`／`暫緩`／`已廢棄`。
4. **流程圖**用 Mermaid 寫在 ```` ```mermaid ```` 區塊裡，GitHub 會直接畫成圖。
5. **不放機密**：這個 repo 是公開的，不能放金鑰、密碼、學生或家長的個資、財務數字。

## 文件索引

### 架構
- （待補）

### 模組
- **考猜（kaocai）**
  - [多分校架構](modules/kaocai/multi-branch-design.md)：暫緩

### 決定紀錄
- [0001 設計文件改用 repo 內的 Markdown](decisions/0001-markdown-handbook-in-repo.md)
- [0002 考猜後台改用自製網頁，不用 Retool](decisions/0002-kaocai-admin-web-not-retool.md)

### 操作手冊
- [部署網頁到 GitHub Pages](runbooks/deploy-github-pages.md)
- [Supabase 寄信（SMTP）與登入信件設定](runbooks/supabase-email-setup.md)
