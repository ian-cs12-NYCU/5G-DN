#!/bin/bash

# MQTT 測試腳本
# 用於測試 MQTT Broker 和 Responder 功能

MQTT_HOST="172.18.0.20"
MQTT_PORT="1883"
REQUEST_TOPIC="hello world"
RESPONSE_TOPIC="hello world/reply"

echo "=========================================="
echo "🧪 MQTT 功能測試腳本"
echo "=========================================="
echo "📡 MQTT Broker: ${MQTT_HOST}:${MQTT_PORT}"
echo "📝 Topic: ${TOPIC}"
echo ""

# 檢查容器是否運行
echo "1️⃣ 檢查容器狀態..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker ps --filter "name=mqtt" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 檢查 responder 日誌
echo "2️⃣ 查看 Responder 最新日誌..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker logs --tail 10 mqtt-responder 2>/dev/null || echo "⚠️  mqtt-responder 容器未運行"
echo ""

# 測試連線
echo "3️⃣ 測試 MQTT Broker 連線..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
timeout 2 mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -t "test/connection" -m "ping" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ MQTT Broker 連線成功"
else
    echo "❌ MQTT Broker 連線失敗"
    echo "💡 請確認容器是否啟動: docker compose up -d"
    exit 1
fi
echo ""

# 互動式測試
echo "4️⃣ 開始互動式測試"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "將會訂閱回應並發送請求，request: '${REQUEST_TOPIC}' response: '${RESPONSE_TOPIC}'"
echo "訂閱 5 秒後自動發送測試訊息..."
echo ""

# 在背景訂閱回應 topic
timeout 10 mosquitto_sub -h ${MQTT_HOST} -p ${MQTT_PORT} -t "${RESPONSE_TOPIC}" -v &
SUB_PID=$!

# 等待訂閱建立
sleep 2

# 發送測試訊息（發到 request topic）
echo "發送測試請求..."
mosquitto_pub -h ${MQTT_HOST} -p ${MQTT_PORT} -t "${REQUEST_TOPIC}" -m "test message from script"

# 等待接收回應
echo "👂 等待 Responder 回應（5 秒）..."
sleep 5

# 結束訂閱
kill $SUB_PID 2>/dev/null

echo ""
echo "=========================================="
echo "測試完成！"
echo "=========================================="
echo ""
echo "提示："
echo "   - 如果看到 {\"ok\":true,\"echo\":\"hello world\"} 表示成功"
echo "   - 使用 'docker logs -f mqtt-responder' 查看詳細日誌"
echo ""
