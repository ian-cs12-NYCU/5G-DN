#!/usr/bin/env bash
set -euo pipefail
ROOT="$(dirname "$0")/data"
mkdir -p "$ROOT/feed" "$ROOT/video/720p"

# 決定要生成多少個 video_id 的 playlist
VIDEO_IDS=${VIDEO_IDS:-100}  # 預設生成 100 個，可用環境變數覆蓋

# 首頁
cat > "$ROOT/index.html" <<'HTML'
<!doctype html><title>DN mock</title><h1>OK</h1>
HTML

# feed：000..999.json（20KB~800KB，隨檔名遞增）
for i in $(seq -w 0 999); do
  # 計算基準大小：從 20KB 線性增長到 800KB
  base_size=$(( 20 + (10#$i * 780 / 999) ))
  # 在基準大小 ±5% 範圍內隨機
  variation=$(( base_size * 5 / 100 ))
  size_kb=$(( base_size - variation + RANDOM % (variation * 2 + 1) ))
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

# video：seg-1..1000.ts（1MB~4MB，隨檔名遞增，truncate 建稀疏檔，傳輸時仍會送出對應大小）
for i in $(seq 1 1000); do
  # 計算基準大小：從 1MB 線性增長到 4MB
  base_size=$(( 1024 + ((i - 1) * 3072 / 999) ))
  # 在基準大小 ±5% 範圍內隨機
  variation=$(( base_size * 5 / 100 ))
  size_kb=$(( base_size - variation + RANDOM % (variation * 2 + 1) ))
  truncate -s "${size_kb}K" "$ROOT/video/720p/seg-$i.ts"
done

# playlist.m3u8：為每個 video-{id} 生成 HLS 播放清單
for vid in $(seq 1 $VIDEO_IDS); do
  mkdir -p "$ROOT/video/720p/video-$vid"
  
  # 每個 video 隨機包含 5~15 個片段
  num_segments=$(( 5 + RANDOM % 11 ))
  
  cat > "$ROOT/video/720p/video-$vid/playlist.m3u8" <<PLAYLIST
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
PLAYLIST

  # 隨機選擇片段編號並加入播放清單
  for seg_idx in $(seq 1 $num_segments); do
    seg_num=$(( 1 + RANDOM % 1000 ))
    cat >> "$ROOT/video/720p/video-$vid/playlist.m3u8" <<PLAYLIST
#EXTINF:10.0,
../../seg-$seg_num.ts
PLAYLIST
  done
  
  echo "#EXT-X-ENDLIST" >> "$ROOT/video/720p/video-$vid/playlist.m3u8"
done

echo "Done. Generated feed(1000), video segments(1000), and playlists($VIDEO_IDS)."
