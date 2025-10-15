## Test dn-web

```
sudo docker exec -it dn-web sh
```

```
curl -s -D - -o /dev/null "http://localhost/feed?since=123456" -w 'code=%{http_code} size_download=%{size_download} time_total=%{time_total}\n'
curl -s -D - -o /dev/null http://localhost/video/720p/seg-7.ts -w 'size_download=%{size_download}\n'
curl -v -X POST http://localhost/react -d 'abc=123'

```