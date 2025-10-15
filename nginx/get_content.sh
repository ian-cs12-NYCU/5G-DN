#!/usr/bin/env bash
set -euo pipefail
ROOT="$(dirname "$0")/data"
mkdir -p "$ROOT/feed" "$ROOT/video/720p"

# 首頁
cat > "$ROOT/index.html" <<'HTML'
<!doctype html><title>DN mock</title><h1>OK</h1>
HTML

# feed：000..999.json（20KB~800KB）
for i in $(seq -w 0 999); do
  size_kb=$(( 20 + RANDOM % 781 ))  # 20..800 KB
  python3 - "$ROOT/feed/$i.json" $((size_kb*1024)) <<'PY'
import sys
path, target = sys.argv[1], int(sys.argv[2])
base = b'{"pad":"'
tail = b'"}'
fill = max(0, target - len(base) - len(tail))
with open(path, "wb") as f:
    f.write(base); f.write(b"a"*fill); f.write(tail)
PY
done

# video：seg-1..1000.ts（1MB~4MB，truncate 建稀疏檔，傳輸時仍會送出對應大小）
for i in $(seq 1 1000); do
  size_kb=$(( 1024 + RANDOM % 3072 ))  # 1024..4095 KB
  truncate -s "${size_kb}K" "$ROOT/video/720p/seg-$i.ts"
done

echo "Done. Generated feed(1000) and video segments(1000)."
