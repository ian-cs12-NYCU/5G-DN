## Test dn-web

```
sudo docker exec -it dn-web sh
```

```
curl -s -D - -o /dev/null "http://localhost/feed?since=123456" -w 'code=%{http_code} size_download=%{size_download} time_total=%{time_total}\n'
curl -s -D - -o /dev/null http://localhost/video/720p/seg-7.ts -w 'size_download=%{size_download}\n'
curl -v -X POST http://localhost/react -d 'abc=123'

```

## Capture Packets
10.200.0.2 is the IP address of locust user
```
sudo tcpdump -i enp3s0 -s 0 -U host 10.200.0.2 -w "./Pcap/WebUser_20-$(date +'%m-%d_%M').pcap"
```
