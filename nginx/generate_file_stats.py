#!/usr/bin/env python3
"""
生成 nginx data 目錄的檔案統計報告
統計 feed（種子）和 video（影片）兩種 API 的檔案大小分佈
"""

import os
import sys
import json
from pathlib import Path
from datetime import datetime
from statistics import mean, median, stdev
from collections import defaultdict

def format_bytes(bytes_val):
    """將位元組轉換為可讀的格式"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_val < 1024:
            return f"{bytes_val:.0f} {unit}"
        bytes_val /= 1024
    return f"{bytes_val:.0f} TB"

def get_file_stats(file_list):
    """計算檔案大小的統計資訊"""
    if not file_list:
        return {
            'count': 0,
            'total': 0,
            'avg': 0,
            'min': 0,
            'max': 0,
            'median': 0,
            'stdev': 0,
            'sizes': []
        }
    
    sizes = sorted([f['size'] for f in file_list])
    total = sum(sizes)
    count = len(sizes)
    avg = total // count
    min_val = sizes[0]
    max_val = sizes[-1]
    median_val = sizes[count // 2] if count % 2 else (sizes[count // 2 - 1] + sizes[count // 2]) // 2
    stdev_val = int(stdev(sizes)) if count > 1 else 0
    
    return {
        'count': count,
        'total': total,
        'avg': avg,
        'min': min_val,
        'max': max_val,
        'median': median_val,
        'stdev': stdev_val,
        'sizes': sizes
    }

def count_in_range(sizes, min_val, max_val):
    """統計在指定範圍內的檔案數"""
    return sum(1 for s in sizes if min_val <= s < max_val)

def scan_files(directory, pattern):
    """掃描目錄並獲取匹配的檔案"""
    files = []
    if not os.path.isdir(directory):
        return files
    
    for filename in sorted(os.listdir(directory)):
        filepath = os.path.join(directory, filename)
        if os.path.isfile(filepath) and filename.endswith(pattern):
            size = os.path.getsize(filepath)
            files.append({
                'name': filename,
                'path': filepath,
                'size': size
            })
    
    return files

def generate_report(data_dir, output_file):
    """生成統計報告"""
    
    print(f"[*] 分析 nginx 檔案統計...")
    
    # 掃描檔案
    print(f"[*] 掃描 Feed 目錄...")
    feed_dir = os.path.join(data_dir, 'feed')
    feed_files = scan_files(feed_dir, '.json')
    
    print(f"[*] 掃描 Video 目錄...")
    video_dir = os.path.join(data_dir, 'video', '720p')
    video_files = scan_files(video_dir, '.ts')
    
    # 計算統計值
    feed_stats = get_file_stats(feed_files)
    video_stats = get_file_stats(video_files)
    
    print(f"[✓] 統計完成！")
    print(f"[*] 生成報告文件: {output_file}")
    
    # 建立報告內容
    report = []
    report.append("# Nginx 檔案統計報告\n")
    report.append(f"> 自動生成於 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    report.append("## 概述\n")
    report.append("nginx container 提供兩種 API：\n")
    report.append("| API 類型 | 路徑 | 用途 | 檔案數 |\n")
    report.append("|---------|------|------|-------|\n")
    report.append(f"| **Feed API** | `/feed?since=xxx` | 獲取播放清單（種子） | {feed_stats['count']} |\n")
    report.append(f"| **Video API** | `/video/720p/seg-*.ts` | 獲取影片片段（模擬） | {video_stats['count']} |\n")
    report.append("\n---\n\n")
    
    # Feed 統計
    report.append("## 1. Feed API - 播放清單檔案 (*.json)\n\n")
    report.append("### 1.1 統計摘要\n\n")
    report.append("| 指標 | 數值 |\n")
    report.append("|-----|------|\n")
    report.append(f"| **檔案總數** | {feed_stats['count']} |\n")
    report.append(f"| **總大小** | {format_bytes(feed_stats['total'])} |\n")
    report.append(f"| **平均大小** | {format_bytes(feed_stats['avg'])} |\n")
    report.append(f"| **最小值** | {format_bytes(feed_stats['min'])} |\n")
    report.append(f"| **最大值** | {format_bytes(feed_stats['max'])} |\n")
    report.append(f"| **中位數** | {format_bytes(feed_stats['median'])} |\n")
    report.append(f"| **標準差** | {format_bytes(feed_stats['stdev'])} |\n")
    report.append(f"| **大小範圍** | {format_bytes(feed_stats['min'])} ~ {format_bytes(feed_stats['max'])} |\n\n")
    
    report.append("### 1.2 分佈特性\n\n")
    report.append("- 檔案命名：`000.json` ~ `999.json`（最多1000個檔案）\n")
    report.append("- 大小遞增：隨檔名編號線性增長（20 KB → 800 KB）\n")
    report.append("- 波動範圍：每檔案±5% 的隨機變動\n")
    report.append("- 訪問方式：`GET /feed?since=<編號>` 回傳對應的 JSON\n\n")
    
    report.append("### 1.3 分級統計\n\n")
    report.append("| 大小等級 | 數量 | 佔比 |\n")
    report.append("|---------|------|------|\n")
    
    ranges_feed = [
        (0, 50*1024, "< 50 KB"),
        (50*1024, 150*1024, "50-150 KB"),
        (150*1024, 300*1024, "150-300 KB"),
        (300*1024, 500*1024, "300-500 KB"),
        (500*1024, float('inf'), "500+ KB"),
    ]
    
    for min_val, max_val, label in ranges_feed:
        count = count_in_range(feed_stats['sizes'], min_val, max_val)
        percentage = (count / feed_stats['count'] * 100) if feed_stats['count'] > 0 else 0
        report.append(f"| {label} | {count} | {percentage:.1f}% |\n")
    
    report.append("\n---\n\n")
    
    # Video 統計
    report.append("## 2. Video API - 影片片段檔案 (*.ts)\n\n")
    report.append("### 2.1 統計摘要\n\n")
    report.append("| 指標 | 數值 |\n")
    report.append("|-----|------|\n")
    report.append(f"| **檔案總數** | {video_stats['count']} |\n")
    report.append(f"| **總大小** | {format_bytes(video_stats['total'])} |\n")
    report.append(f"| **平均大小** | {format_bytes(video_stats['avg'])} |\n")
    report.append(f"| **最小值** | {format_bytes(video_stats['min'])} |\n")
    report.append(f"| **最大值** | {format_bytes(video_stats['max'])} |\n")
    report.append(f"| **中位數** | {format_bytes(video_stats['median'])} |\n")
    report.append(f"| **標準差** | {format_bytes(video_stats['stdev'])} |\n")
    report.append(f"| **大小範圍** | {format_bytes(video_stats['min'])} ~ {format_bytes(video_stats['max'])} |\n\n")
    
    report.append("### 2.2 分佈特性\n\n")
    report.append("- 檔案命名：`seg-1.ts` ~ `seg-1000.ts`（1000個檔案）\n")
    report.append("- 大小遞增：隨檔名編號線性增長（1 MB → 4 MB）\n")
    report.append("- 波動範圍：每檔案±5% 的隨機變動\n")
    report.append("- 儲存方式：稀疏檔（truncate），傳輸時仍發送完整大小\n")
    report.append("- 訪問方式：`GET /video/720p/seg-<編號>.ts` 下載檔案\n\n")
    
    report.append("### 2.3 分級統計\n\n")
    report.append("| 大小等級 | 數量 | 佔比 |\n")
    report.append("|---------|------|------|\n")
    
    ranges_video = [
        (0, 1.5*1024*1024, "< 1.5 MB"),
        (1.5*1024*1024, 2.5*1024*1024, "1.5-2.5 MB"),
        (2.5*1024*1024, 3.5*1024*1024, "2.5-3.5 MB"),
        (3.5*1024*1024, float('inf'), "3.5+ MB"),
    ]
    
    for min_val, max_val, label in ranges_video:
        count = count_in_range(video_stats['sizes'], min_val, max_val)
        percentage = (count / video_stats['count'] * 100) if video_stats['count'] > 0 else 0
        report.append(f"| {label} | {count} | {percentage:.1f}% |\n")
    
    report.append("\n---\n\n")
    
    # 詳細檔案列表
    report.append("## 3. 詳細檔案列表\n\n")
    report.append("### 3.1 Feed 檔案 (前30個)\n\n")
    report.append("```\n")
    report.append(f"{'檔名':<15} {'大小':>10}\n")
    report.append("-" * 28 + "\n")
    for f in feed_files[:30]:
        report.append(f"{f['name']:<15} {format_bytes(f['size']):>10}\n")
    report.append("```\n\n")
    
    if len(feed_files) > 30:
        report.append(f"... 共 {len(feed_files)} 個檔案\n\n")
    
    report.append("### 3.2 Video 檔案 (前30個)\n\n")
    report.append("```\n")
    report.append(f"{'檔名':<15} {'大小':>10}\n")
    report.append("-" * 28 + "\n")
    for f in video_files[:30]:
        report.append(f"{f['name']:<15} {format_bytes(f['size']):>10}\n")
    report.append("```\n\n")
    
    if len(video_files) > 30:
        report.append(f"... 共 {len(video_files)} 個檔案\n\n")
    
    report.append("---\n\n")
    
    # 存儲成本分析
    report.append("## 4. 存儲成本分析\n\n")
    report.append("| 項目 | Feed | Video | 合計 |\n")
    report.append("|-----|------|-------|------|\n")
    report.append(f"| **檔案數** | {feed_stats['count']} | {video_stats['count']} | {feed_stats['count'] + video_stats['count']} |\n")
    report.append(f"| **總大小** | {format_bytes(feed_stats['total'])} | {format_bytes(video_stats['total'])} | {format_bytes(feed_stats['total'] + video_stats['total'])} |\n")
    
    feed_avg_per = feed_stats['total'] // feed_stats['count'] if feed_stats['count'] > 0 else 0
    video_avg_per = video_stats['total'] // video_stats['count'] if video_stats['count'] > 0 else 0
    
    report.append(f"| **平均單位** | {format_bytes(feed_avg_per)} | {format_bytes(video_avg_per)} | - |\n\n")
    
    # 使用說明
    report.append("---\n\n")
    report.append("## 5. 使用說明\n\n")
    report.append("### 動態重新生成報告\n\n")
    report.append("當 nginx data 目錄中的檔案發生變化時，可以重新執行此腳本更新統計報告：\n\n")
    report.append("```bash\n")
    report.append("python3 generate_file_stats.py\n")
    report.append("```\n\n")
    
    report.append("### API 訪問示例\n\n")
    report.append("**Feed API:**\n")
    report.append("```bash\n")
    report.append("# 獲取編號為 100 的播放清單\n")
    report.append("curl http://localhost/feed?since=100\n")
    report.append("```\n\n")
    
    report.append("**Video API:**\n")
    report.append("```bash\n")
    report.append("# 獲取第 500 個影片片段\n")
    report.append("curl http://localhost/video/720p/seg-500.ts -o seg-500.ts\n")
    report.append("```\n\n")
    
    report.append("### 環境變數\n\n")
    report.append("若要修改生成的檔案數量，編輯 `get_content.sh` 中的環境變數：\n\n")
    report.append("```bash\n")
    report.append("VIDEO_IDS=200  # 生成 200 個視頻播放清單\n")
    report.append("```\n\n")
    
    report.append("---\n\n")
    report.append(f"*最後更新於: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n")
    
    # 寫入檔案
    with open(output_file, 'w', encoding='utf-8') as f:
        f.writelines(report)
    
    print(f"[✓] 報告已生成！")
    print(f"[✓] 檔案位置: {output_file}")

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(script_dir, 'data')
    output_file = os.path.join(script_dir, 'FILE_STATS.md')
    
    if not os.path.isdir(data_dir):
        print(f"Error: Data directory not found at {data_dir}")
        sys.exit(1)
    
    generate_report(data_dir, output_file)

if __name__ == '__main__':
    main()
