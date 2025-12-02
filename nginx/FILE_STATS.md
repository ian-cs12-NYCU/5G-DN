# Nginx 檔案統計報告
> 自動生成於 2025-12-02 20:06:50
## 概述
nginx container 提供兩種 API：
| API 類型 | 路徑 | 用途 | 檔案數 |
|---------|------|------|-------|
| **Feed API** | `/feed?since=xxx` | 獲取播放清單（種子） | 1000 |
| **Video API** | `/video/720p/seg-*.ts` | 獲取影片片段（模擬） | 1000 |

---

## 1. Feed API - 播放清單檔案 (*.json)

### 1.1 統計摘要

| 指標 | 數值 |
|-----|------|
| **檔案總數** | 1000 |
| **總大小** | 400 MB |
| **平均大小** | 409 KB |
| **最小值** | 19 KB |
| **最大值** | 830 KB |
| **中位數** | 408 KB |
| **標準差** | 225 KB |
| **大小範圍** | 19 KB ~ 830 KB |

### 1.2 分佈特性

- 檔案命名：`000.json` ~ `999.json`（最多1000個檔案）
- 大小遞增：隨檔名編號線性增長（20 KB → 800 KB）
- 波動範圍：每檔案±5% 的隨機變動
- 訪問方式：`GET /feed?since=<編號>` 回傳對應的 JSON

### 1.3 分級統計

| 大小等級 | 數量 | 佔比 |
|---------|------|------|
| < 50 KB | 39 | 3.9% |
| 50-150 KB | 127 | 12.7% |
| 150-300 KB | 195 | 19.5% |
| 300-500 KB | 259 | 25.9% |
| 500+ KB | 380 | 38.0% |

---

## 2. Video API - 影片片段檔案 (*.ts)

### 2.1 統計摘要

| 指標 | 數值 |
|-----|------|
| **檔案總數** | 1000 |
| **總大小** | 2 GB |
| **平均大小** | 2 MB |
| **最小值** | 997 KB |
| **最大值** | 4 MB |
| **中位數** | 2 MB |
| **標準差** | 890 KB |
| **大小範圍** | 997 KB ~ 4 MB |

### 2.2 分佈特性

- 檔案命名：`seg-1.ts` ~ `seg-1000.ts`（1000個檔案）
- 大小遞增：隨檔名編號線性增長（1 MB → 4 MB）
- 波動範圍：每檔案±5% 的隨機變動
- 儲存方式：稀疏檔（truncate），傳輸時仍發送完整大小
- 訪問方式：`GET /video/720p/seg-<編號>.ts` 下載檔案

### 2.3 分級統計

| 大小等級 | 數量 | 佔比 |
|---------|------|------|
| < 1.5 MB | 176 | 17.6% |
| 1.5-2.5 MB | 328 | 32.8% |
| 2.5-3.5 MB | 333 | 33.3% |
| 3.5+ MB | 163 | 16.3% |

---

## 3. 詳細檔案列表

### 3.1 Feed 檔案 (前30個)

```
檔名                      大小
----------------------------
000.json             19 KB
001.json             19 KB
002.json             20 KB
003.json             22 KB
004.json             24 KB
005.json             24 KB
006.json             23 KB
007.json             26 KB
008.json             25 KB
009.json             26 KB
010.json             27 KB
011.json             27 KB
012.json             29 KB
013.json             29 KB
014.json             30 KB
015.json             30 KB
016.json             32 KB
017.json             33 KB
018.json             34 KB
019.json             35 KB
020.json             35 KB
021.json             37 KB
022.json             37 KB
023.json             36 KB
024.json             38 KB
025.json             40 KB
026.json             39 KB
027.json             40 KB
028.json             42 KB
029.json             44 KB
```

... 共 1000 個檔案

### 3.2 Video 檔案 (前30個)

```
檔名                      大小
----------------------------
seg-1.ts              1 MB
seg-10.ts             1 MB
seg-100.ts            1 MB
seg-1000.ts           4 MB
seg-101.ts            1 MB
seg-102.ts            1 MB
seg-103.ts            1 MB
seg-104.ts            1 MB
seg-105.ts            1 MB
seg-106.ts            1 MB
seg-107.ts            1 MB
seg-108.ts            1 MB
seg-109.ts            1 MB
seg-11.ts             1 MB
seg-110.ts            1 MB
seg-111.ts            1 MB
seg-112.ts            1 MB
seg-113.ts            1 MB
seg-114.ts            1 MB
seg-115.ts            1 MB
seg-116.ts            1 MB
seg-117.ts            1 MB
seg-118.ts            1 MB
seg-119.ts            1 MB
seg-12.ts             1 MB
seg-120.ts            1 MB
seg-121.ts            1 MB
seg-122.ts            1 MB
seg-123.ts            1 MB
seg-124.ts            1 MB
```

... 共 1000 個檔案

---

## 4. 存儲成本分析

| 項目 | Feed | Video | 合計 |
|-----|------|-------|------|
| **檔案數** | 1000 | 1000 | 2000 |
| **總大小** | 400 MB | 2 GB | 3 GB |
| **平均單位** | 409 KB | 2 MB | - |

---

## 5. 使用說明

### 動態重新生成報告

當 nginx data 目錄中的檔案發生變化時，可以重新執行此腳本更新統計報告：

```bash
python3 generate_file_stats.py
```

### API 訪問示例

**Feed API:**
```bash
# 獲取編號為 100 的播放清單
curl http://localhost/feed?since=100
```

**Video API:**
```bash
# 獲取第 500 個影片片段
curl http://localhost/video/720p/seg-500.ts -o seg-500.ts
```

### 環境變數

若要修改生成的檔案數量，編輯 `get_content.sh` 中的環境變數：

```bash
VIDEO_IDS=200  # 生成 200 個視頻播放清單
```

---

*最後更新於: 2025-12-02 20:06:50*
