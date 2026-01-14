## 環境設置
```
./script/setup_iptable/setup_iptables.sh
```

## Test dn-web

```
sudo docker exec -it dn-web sh
```

### HTTP 測試 (支援)
```bash
# 測試 feed endpoint
curl -s -D - -o /dev/null "http://localhost/feed?since=123456" -w 'code=%{http_code} size_download=%{size_download} time_total=%{time_total}\n'

# 測試 video endpoint
curl -s -D - -o /dev/null http://localhost/video/720p/seg-7.ts -w 'size_download=%{size_download}\n'

# 測試 react endpoint (POST)
curl -v -X POST http://localhost/react -d 'abc=123'
```

### HTTPS 測試 (支援 - 自簽名證書)
```bash
# 容器已啟用 HTTPS (port 443)，使用自簽名證書
# 使用 -k 選項忽略證書警告

# 驗證 HTTPS 連線成功
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dn-web
# 取得容器 IP (如 172.18.0.10)，然後測試

# 測試 HTTPS 首頁
curl -k https://172.18.0.10/

# 測試 HTTPS feed endpoint
curl -k -s "https://172.18.0.10/feed?since=123"

# 測試 HTTPS POST
curl -k -X POST https://172.18.0.10/react -d 'test=data'
    
# 比較 HTTP 和 HTTPS (同時測試)
echo "=== HTTP ===" && curl -s -w '\nStatus: %{http_code}\n' http://172.18.0.10/ | head -2
echo "=== HTTPS ===" && curl -k -s -w '\nStatus: %{http_code}\n' https://172.18.0.10/ | head -2
```

**測試結果**: ✓ HTTP 正常運作 | ✓ HTTPS 正常運作 (自簽名證書)

## Capture Packets
10.200.0.2 is the IP address of locust user
```
sudo tcpdump -i enp3s0 -s 0 -U host 10.200.0.2 -w "./Pcap/WebUser_20-$(date +'%m-%d_%M').pcap"
```
