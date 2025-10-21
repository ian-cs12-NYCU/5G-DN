FROM python:3.11-slim

WORKDIR /app

# 複製依賴檔案
COPY requirements.txt .

# 安裝依賴（使用多個鏡像源以提高成功率）
RUN pip install --no-cache-dir -r requirements.txt || \
    pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt || \
    pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple -r requirements.txt

# 複製應用程式
COPY responder.py .

# 設定預設環境變數
ENV MQTT_BROKER=localhost
ENV MQTT_PORT=1883

# 執行 responder
CMD ["python", "-u", "responder.py"]
