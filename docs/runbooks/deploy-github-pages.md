# 部署網頁到 GitHub Pages

這個 repo 是公開的，GitHub Pages 會把 `main` 分支的檔案原樣發佈成網站。

## 網址規則
`https://yijhihyang.github.io/campus-core-os/` 加上檔案在 repo 裡的路徑。

| 頁面 | 網址 |
|---|---|
| 考猜報名表 | https://yijhihyang.github.io/campus-core-os/modules/kaocai-site/kaocai.html |
| 考猜後台 | https://yijhihyang.github.io/campus-core-os/modules/kaocai-site/admin.html |

## 更新網頁
```bash
cd ~/Desktop/campus-core-os
git add modules/kaocai-site
git commit -m "Update kaocai admin console"
git push
```
推上去後約 1～2 分鐘生效。進度看 https://github.com/yijhihyang/campus-core-os/actions

## 常見問題
- **一直 404 或沒更新**：到 Actions 頁面看是否建置失敗。若是 Jekyll 錯誤，在 repo 根目錄加空檔案 `.nojekyll` 後再 push。
- **網頁開得了但資料讀不到**：通常是沒登入，或登入的 Email 沒有權限，不是部署問題。
