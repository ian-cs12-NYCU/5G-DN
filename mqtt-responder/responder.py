#!/usr/bin/env python3
import os
import json
import time
import paho.mqtt.client as mqtt

# 從環境變數取得設定
MQTT_BROKER = os.getenv('MQTT_BROKER', 'localhost')
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
SUBSCRIBE_TOPIC = 'hello world'

def on_connect(client, userdata, flags, rc):
    """當連線到 MQTT broker 時的回調函數"""
    if rc == 0:
        print(f"✓ Connected to MQTT Broker at {MQTT_BROKER}:{MQTT_PORT}")
        # 訂閱 topic
        client.subscribe(SUBSCRIBE_TOPIC)
        print(f"✓ Subscribed to topic: '{SUBSCRIBE_TOPIC}'")
    else:
        print(f"✗ Failed to connect, return code {rc}")

def on_message(client, userdata, msg):
    """當收到訊息時的回調函數"""
    print(f"📨 Received message on topic '{msg.topic}': {msg.payload.decode()}")
    
    # 建立回應訊息
    response = {
        "ok": True,
        "echo": "hello world"
    }
    
    # 發送回應到同一個 topic
    client.publish(msg.topic, json.dumps(response))
    print(f"📤 Sent response: {json.dumps(response)}")

def on_disconnect(client, userdata, rc):
    """當斷線時的回調函數"""
    if rc != 0:
        print(f"⚠ Unexpected disconnection. Return code: {rc}")
        print("🔄 Attempting to reconnect...")

def main():
    print("🚀 Starting MQTT Responder...")
    print(f"📡 Broker: {MQTT_BROKER}:{MQTT_PORT}")
    
    # 建立 MQTT client
    client = mqtt.Client(client_id="mqtt-responder")
    
    # 設定回調函數
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect
    
    # 連線到 broker (帶重試機制)
    max_retries = 10
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            print(f"🔌 Connecting to MQTT broker (attempt {retry_count + 1}/{max_retries})...")
            client.connect(MQTT_BROKER, MQTT_PORT, 60)
            break
        except Exception as e:
            retry_count += 1
            print(f"✗ Connection failed: {e}")
            if retry_count < max_retries:
                print(f"⏳ Retrying in 5 seconds...")
                time.sleep(5)
            else:
                print("✗ Max retries reached. Exiting.")
                return
    
    # 開始監聽
    print("👂 Listening for messages...")
    client.loop_forever()

if __name__ == "__main__":
    main()
