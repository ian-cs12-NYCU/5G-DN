FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir dnslib

COPY server.py /app/server.py
COPY hosts.txt /app/hosts.txt

EXPOSE 53/udp

CMD ["python", "server.py", "--hosts", "/app/hosts.txt", "--port", "53"]
