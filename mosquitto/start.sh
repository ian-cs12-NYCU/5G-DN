#!/bin/sh

echo "🚀 Starting Mosquitto MQTT Broker with Responder..."

# 啟動 mosquitto 在背景
echo "📡 Starting Mosquitto broker..."
/usr/sbin/mosquitto -c /mosquitto/config/mosquitto.conf &
MOSQUITTO_PID=$!

# 等待 mosquitto 啟動並準備好接受連線
echo "⏳ Waiting for Mosquitto to be ready..."
sleep 3

# 啟動 responder
echo "🤖 Starting MQTT Responder..."
python3 /usr/local/bin/responder.py &
RESPONDER_PID=$!

# 監控兩個進程，如果任一個結束就退出
wait -n $MOSQUITTO_PID $RESPONDER_PID

# 如果其中一個進程結束，終止另一個
kill $MOSQUITTO_PID $RESPONDER_PID 2>/dev/null

exit $?
