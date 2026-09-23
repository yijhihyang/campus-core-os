#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLECT_DIR="$REPO_ROOT/supabase/migrations"

echo "彙整目標資料夾：$COLLECT_DIR"

rm -rf "$COLLECT_DIR"
mkdir -p "$COLLECT_DIR"

count=0
for module_migration_dir in "$REPO_ROOT"/modules/*/supabase/migrations; do
  if [ -d "$module_migration_dir" ]; then
    for f in "$module_migration_dir"/*.sql; do
      [ -e "$f" ] || continue
      cp "$f" "$COLLECT_DIR/"
      count=$((count + 1))
    done
  fi
done

echo "共彙整 $count 個 migration 檔案："
ls -1 "$COLLECT_DIR" | sort

echo ""
echo "⚠️  提醒：.sql.disabled 檔案（例如 RLS 待補 policy 的檔案）"
echo "    刻意不會被彙整進來，這是正確行為，不是遺漏。"
echo ""
echo "接下來執行 supabase db push 即可套用到目前連結的專案。"
