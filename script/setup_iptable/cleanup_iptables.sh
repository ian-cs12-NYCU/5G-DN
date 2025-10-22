#!/bin/bash

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 開始清理 iptables 規則 ===${NC}\n"

# 設置變量（從設定檔載入或使用預設）
CONFIG_FILE="$(dirname "$0")/iptables.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
    echo -e "${YELLOW}已從設定檔載入變數: $CONFIG_FILE${NC}"
fi

: "${ANDY:=10.200.0.2}"
: "${SEG:=10.201.0.0/26}"

# 獲取容器 IP（如果容器還在運行）
CIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dn-web 2>/dev/null)
MQTT_CIP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mqtt-broker 2>/dev/null)

echo -e "${YELLOW}目標配置:${NC}"
echo -e "  UE 地址 (ANDY): $ANDY"
echo -e "  DN 網段 (SEG): $SEG"
if [ -n "$CIP" ]; then
    echo -e "  Web 容器 IP: $CIP"
fi
if [ -n "$MQTT_CIP" ]; then
    echo -e "  MQTT 容器 IP: $MQTT_CIP"
fi

# 顯示當前規則數量
echo -e "\n${YELLOW}清理前的規則:${NC}"
NAT_COUNT=$(sudo iptables -t nat -L PREROUTING -n | grep -c "$ANDY")
FORWARD_COUNT=$(sudo iptables -L FORWARD -n | grep -c "$ANDY")
echo -e "  NAT PREROUTING 規則: ${RED}$NAT_COUNT${NC} 條"
echo -e "  FORWARD 規則: ${RED}$FORWARD_COUNT${NC} 條"

# 詢問確認
echo -e "\n${YELLOW}即將刪除以下類型的規則:${NC}"
echo -e "  - 所有來源為 $ANDY 的 NAT PREROUTING 規則"
echo -e "  - 所有來源為 $ANDY 的 FORWARD 規則"
if [ -n "$CIP" ]; then
    echo -e "  - 所有涉及 $CIP 的 FORWARD 規則"
fi
if [ -n "$MQTT_CIP" ]; then
    echo -e "  - 所有涉及 $MQTT_CIP 的 FORWARD 規則"
fi

read -p "確定要繼續嗎? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}操作已取消${NC}"
    exit 0
fi

echo -e "\n${YELLOW}開始清理規則...${NC}"

# 清理 NAT PREROUTING 規則
echo -e "\n${BLUE}清理 NAT PREROUTING 規則...${NC}"
while sudo iptables -t nat -L PREROUTING -n --line-numbers | grep "$ANDY" > /dev/null; do
    LINE=$(sudo iptables -t nat -L PREROUTING -n --line-numbers | grep "$ANDY" | head -1 | awk '{print $1}')
    if [ -n "$LINE" ]; then
        echo "  刪除 NAT PREROUTING 規則 #$LINE"
        sudo iptables -t nat -D PREROUTING $LINE
    else
        break
    fi
done

# 清理 FORWARD 規則（基於源地址 ANDY）
echo -e "\n${BLUE}清理來源為 $ANDY 的 FORWARD 規則...${NC}"
while sudo iptables -L FORWARD -n --line-numbers | grep "$ANDY" > /dev/null; do
    LINE=$(sudo iptables -L FORWARD -n --line-numbers | grep "$ANDY" | head -1 | awk '{print $1}')
    if [ -n "$LINE" ]; then
        echo "  刪除 FORWARD 規則 #$LINE"
        sudo iptables -D FORWARD $LINE
    else
        break
    fi
done

# 清理涉及容器 IP 的 FORWARD 規則
if [ -n "$CIP" ]; then
    echo -e "\n${BLUE}清理涉及 Web 容器 IP ($CIP) 的 FORWARD 規則...${NC}"
    while sudo iptables -L FORWARD -n --line-numbers | grep "$CIP" > /dev/null; do
        LINE=$(sudo iptables -L FORWARD -n --line-numbers | grep "$CIP" | head -1 | awk '{print $1}')
        if [ -n "$LINE" ]; then
            echo "  刪除 FORWARD 規則 #$LINE"
            sudo iptables -D FORWARD $LINE
        else
            break
        fi
    done
fi

if [ -n "$MQTT_CIP" ]; then
    echo -e "\n${BLUE}清理涉及 MQTT 容器 IP ($MQTT_CIP) 的 FORWARD 規則...${NC}"
    while sudo iptables -L FORWARD -n --line-numbers | grep "$MQTT_CIP" > /dev/null; do
        LINE=$(sudo iptables -L FORWARD -n --line-numbers | grep "$MQTT_CIP" | head -1 | awk '{print $1}')
        if [ -n "$LINE" ]; then
            echo "  刪除 FORWARD 規則 #$LINE"
            sudo iptables -D FORWARD $LINE
        else
            break
        fi
    done
fi

echo -e "\n${GREEN}=== iptables 規則清理完成 ===${NC}\n"

# 顯示清理後的狀態
NAT_COUNT_AFTER=$(sudo iptables -t nat -L PREROUTING -n | grep -c "$ANDY")
FORWARD_COUNT_AFTER=$(sudo iptables -L FORWARD -n | grep -c "$ANDY")
echo -e "${YELLOW}清理後的規則:${NC}"
echo -e "  NAT PREROUTING 規則: ${GREEN}$NAT_COUNT_AFTER${NC} 條"
echo -e "  FORWARD 規則: ${GREEN}$FORWARD_COUNT_AFTER${NC} 條"

if [ $NAT_COUNT_AFTER -eq 0 ] && [ $FORWARD_COUNT_AFTER -eq 0 ]; then
    echo -e "\n${GREEN}✓ 所有相關規則已成功清理${NC}"
else
    echo -e "\n${YELLOW}⚠ 可能還有部分規則未清理，請手動檢查${NC}"
fi
