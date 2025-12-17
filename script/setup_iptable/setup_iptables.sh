#!/bin/bash

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 開始設置 iptables 規則 ===${NC}\n"

# 檢查 Docker 容器是否運行
echo -e "${YELLOW}檢查 Docker 容器狀態...${NC}"
docker ps

# 獲取容器 IP
echo -e "\n${YELLOW}獲取容器 IP 地址...${NC}"
CIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dn-web)
MQTT_CIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mqtt-broker)
DNS_CIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-responder)

if [ -z "$CIP" ] || [ -z "$MQTT_CIP" ]; then
    echo -e "${YELLOW}錯誤: 無法獲取容器 IP 地址，請確認容器是否正在運行${NC}"
    exit 1
fi

if [ -z "$DNS_CIP" ]; then
  echo -e "${YELLOW}錯誤: 無法獲取 dns-responder 容器 IP 地址，請確認 dns-responder 是否正在運行${NC}"
  exit 1
fi

echo -e "${GREEN}Web 容器 IP: $CIP${NC}"
echo -e "${GREEN}MQTT 容器 IP: $MQTT_CIP${NC}"
echo -e "${GREEN}dns-responder 容器 IP: $DNS_CIP${NC}"

# 設置變量（從設定檔載入或使用預設）
CONFIG_FILE="$(dirname "$0")/iptables.conf"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  echo -e "${YELLOW}已從設定檔載入變數: $CONFIG_FILE${NC}"
fi

: "${ANDY:=10.200.0.2}"
: "${SEG:=10.201.0.0/26}"

echo -e "\n${YELLOW}設置變量:${NC}"
echo -e "  UE 地址 (ANDY): $ANDY"
echo -e "  DN 網段 (SEG): $SEG"

# === [FIX 1] 核心參數設置 (這是讓主機變成路由器的關鍵) ===
echo -e "\n${YELLOW}開啟核心轉送功能...${NC}"
# 載入必要模組 (解決 Docker 網橋過濾問題)
sudo modprobe br_netfilter
# 開啟 IPv4 轉送
sudo sysctl -w net.ipv4.ip_forward=1
# 讓 iptables 能過濾 bridge 流量
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
# 放寬反向路徑過濾 (避免因為多網卡導致的回程封包被丟棄)
sudo sysctl -w net.ipv4.conf.all.rp_filter=2
sudo sysctl -w net.ipv4.conf.default.rp_filter=2

# === 清除舊規則 ===
echo -e "\n${YELLOW}清除舊的 iptables 規則...${NC}"
echo "  清除舊的 NAT PREROUTING 規則"
sudo iptables -t nat -D PREROUTING -s $ANDY -d $SEG -p tcp --dport 1883 -j DNAT --to-destination ${MQTT_CIP}:1883 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -s $ANDY -d $SEG -p tcp --dport 8883 -j DNAT --to-destination ${MQTT_CIP}:8883 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -s $ANDY -d $SEG -p tcp -j DNAT --to-destination ${CIP} 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -s $ANDY -d $SEG -p udp -j DNAT --to-destination ${CIP} 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -s $ANDY -d $SEG -p udp --dport 53 -j DNAT --to-destination ${DNS_CIP}:53 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -s $ANDY -d $SEG -p tcp --dport 53 -j DNAT --to-destination ${DNS_CIP}:53 2>/dev/null || true

echo "  清除舊的 NAT POSTROUTING 規則"
sudo iptables -t nat -D POSTROUTING -s $ANDY -d 172.18.0.0/16 -j MASQUERADE 2>/dev/null || true

echo "  清除舊的 FORWARD 規則"
sudo iptables -D FORWARD -s $ANDY -d ${CIP} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -s ${CIP} -d $ANDY -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -s $ANDY -d ${MQTT_CIP} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -s ${MQTT_CIP} -d $ANDY -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -p icmp -s $ANDY -d ${CIP} -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -p icmp -s ${CIP} -d $ANDY -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -p icmp -s $ANDY -d ${MQTT_CIP} -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -p icmp -s ${MQTT_CIP} -d $ANDY -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -s $ANDY -d ${DNS_CIP} -p udp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -s $ANDY -d ${DNS_CIP} -p tcp --dport 53 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
sudo iptables -D FORWARD -s ${DNS_CIP} -d $ANDY -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# 設置 NAT 規則 - 將目標為 SEG 網段的流量 DNAT 到容器
echo -e "\n${YELLOW}設置 NAT PREROUTING 規則 (轉發所有端口)...${NC}"

# 先加入較精確的 DNAT，確保 MQTT 的 1883/8883 優先匹配
echo "  添加到 MQTT 容器的 DNAT 規則 (TCP 1883) - 優先於廣域 DNAT"
sudo iptables -t nat -I PREROUTING 1 -s $ANDY -d $SEG -p tcp --dport 1883 \
  -j DNAT --to-destination ${MQTT_CIP}:1883

echo "  添加到 MQTT 容器的 DNAT 規則 (TCP 8883) - 優先於廣域 DNAT"
sudo iptables -t nat -I PREROUTING 1 -s $ANDY -d $SEG -p tcp --dport 8883 \
  -j DNAT --to-destination ${MQTT_CIP}:8883

# 原本的較廣泛的 DNAT 規則保留（較後匹配）
echo "  添加到 Web 容器的 DNAT 規則 (所有 TCP 端口)"
sudo iptables -t nat -A PREROUTING -s $ANDY -d $SEG -p tcp \
  -j DNAT --to-destination ${CIP}

echo "  添加到 Web 容器的 DNAT 規則 (所有 UDP 端口)"
sudo iptables -t nat -A PREROUTING -s $ANDY -d $SEG -p udp \
  -j DNAT --to-destination ${CIP}

# 將進入 SEG 的 DNS 流量導向 dns-responder（優先於廣域 DNAT）
echo "  添加到 dns-responder 的 DNAT 規則 (UDP 53) - DNS UDP"
sudo iptables -t nat -I PREROUTING 1 -s $ANDY -d $SEG -p udp --dport 53 \
  -j DNAT --to-destination ${DNS_CIP}:53

echo "  添加到 dns-responder 的 DNAT 規則 (TCP 53) - DNS TCP"
sudo iptables -t nat -I PREROUTING 1 -s $ANDY -d $SEG -p tcp --dport 53 \
  -j DNAT --to-destination ${DNS_CIP}:53

# === [FIX 2] 設置 POSTROUTING (確保回程封包能回到 UE) ===
echo -e "\n${YELLOW}設置 NAT POSTROUTING 規則 (Masquerade)...${NC}"
echo "  設置 Masquerade (偽裝)，確保容器能回傳封包給 Host"
sudo iptables -t nat -I POSTROUTING 1 -s $ANDY -d 172.18.0.0/16 -j MASQUERADE

# 設置 FORWARD 規則 - 允許所有流量通過
echo -e "\n${YELLOW}設置 FORWARD 規則 (允許所有流量)...${NC}"

echo "  允許從 UE 到 Web 容器的所有流量 (Insert at Top)"
sudo iptables -I FORWARD 1 -s $ANDY -d ${CIP} \
  -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

echo "  允許從 Web 容器回到 UE 的所有流量"
sudo iptables -I FORWARD 1 -s ${CIP} -d $ANDY \
  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "  允許從 UE 到 MQTT 容器的所有流量"
sudo iptables -I FORWARD 1 -s $ANDY -d ${MQTT_CIP} \
  -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

echo "  允許從 MQTT 容器回到 UE 的所有流量"
sudo iptables -I FORWARD 1 -s ${MQTT_CIP} -d $ANDY \
  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo -e "\n${YELLOW}設置 ICMP (ping) FORWARD 規則 (允許 ping) ...${NC}"

echo "  允許 ICMP (ping) 從 UE 到 Web 容器"
sudo iptables -I FORWARD 1 -p icmp -s $ANDY -d ${CIP} -j ACCEPT

echo "  允許 ICMP (ping) 從 Web 容器到 UE"
sudo iptables -I FORWARD 1 -p icmp -s ${CIP} -d $ANDY -j ACCEPT

echo "  允許 ICMP (ping) 從 UE 到 MQTT 容器"
sudo iptables -I FORWARD 1 -p icmp -s $ANDY -d ${MQTT_CIP} -j ACCEPT

echo "  允許 ICMP (ping) 從 MQTT 容器到 UE"
sudo iptables -I FORWARD 1 -p icmp -s ${MQTT_CIP} -d $ANDY -j ACCEPT

echo "  允許從 UE 到 dns-responder 的 DNS 流量 (UDP 53 和 TCP 53)"
sudo iptables -I FORWARD 1 -s $ANDY -d ${DNS_CIP} -p udp --dport 53 \
  -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -I FORWARD 1 -s $ANDY -d ${DNS_CIP} -p tcp --dport 53 \
  -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

echo "  允許從 dns-responder 回到 UE 的 DNS 回應"
sudo iptables -I FORWARD 1 -s ${DNS_CIP} -d $ANDY \
  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo -e "\n${GREEN}=== iptables 規則設置完成 ===${NC}\n"

# 顯示當前規則
echo -e "${YELLOW}當前 NAT 規則:${NC}"
sudo iptables -t nat -L PREROUTING -n -v --line-numbers | grep -E "$ANDY|Chain"

echo -e "\n${YELLOW}當前 FORWARD 規則:${NC}"
sudo iptables -L FORWARD -n -v --line-numbers | grep -E "$ANDY|$CIP|$MQTT_CIP|Chain"

echo -e "\n${BLUE}注意: 此配置允許 $ANDY 訪問 $SEG 網段容器的所有端口${NC}"
