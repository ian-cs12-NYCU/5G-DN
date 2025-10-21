FROM eclipse-mosquitto:latest

# 安裝 Python 3 和 pip
RUN apk add --no-cache python3 py3-pip

# 安裝 paho-mqtt（使用 --break-system-packages 繞過限制）
RUN pip3 install --break-system-packages --no-cache-dir paho-mqtt==1.6.1

# 複製 responder 腳本
COPY responder.py /usr/local/bin/responder.py
RUN chmod +x /usr/local/bin/responder.py

# 複製啟動腳本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 使用自定義啟動腳本
CMD ["/start.sh"]
