#!/usr/bin/env python3
"""
Minimal DNS responder using dnslib.

Reads a simple hosts file (domain IP per line) and replies to A queries.
If a name isn't found it returns NXDOMAIN. Optionally you can run on a
non-privileged port (e.g., 5353) to avoid needing root to bind 53.
"""
import argparse
import socket
from dnslib import DNSRecord, DNSHeader, RR, QTYPE, A, RCODE


def load_hosts(path):
    m = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            if len(parts) >= 2:
                domain = parts[0].rstrip('.')
                ip = parts[1]
                m[domain.lower()] = ip
    return m


def handle_request(data, addr, sock, hosts_path):
    try:
        req = DNSRecord.parse(data)
    except Exception:
        return

    q = req.q
    qname = str(q.get_qname()).rstrip('.')
    qtype = QTYPE[q.qtype]

    # reload hosts on each request so updates to the mounted hosts.txt take effect immediately
    hosts = load_hosts(hosts_path)

    reply = DNSRecord(DNSHeader(id=req.header.id, qr=1, aa=1, ra=0), q=req.q)

    if qtype == 'A':
        ip = hosts.get(qname.lower())
        if ip:
            reply.add_answer(RR(q.get_qname(), QTYPE.A, rdata=A(ip), ttl=60))
        else:
            reply.header.rcode = RCODE.NXDOMAIN
    else:
        reply.header.rcode = RCODE.NXDOMAIN

    sock.sendto(reply.pack(), addr)


def serve(hosts_path, bind_addr, port):
    # do not cache hosts here; handle_request will reload every time
    print(f"Using hosts file: {hosts_path}")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((bind_addr, port))
    print(f"DNS responder listening on {bind_addr}:{port} (udp)")

    try:
        while True:
            data, addr = sock.recvfrom(4096)
            handle_request(data, addr, sock, hosts_path)
    except KeyboardInterrupt:
        print("Shutting down")


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--hosts', default='hosts.txt', help='Path to hosts file')
    p.add_argument('--bind', default='0.0.0.0', help='Bind address')
    p.add_argument('--port', type=int, default=53, help='UDP port to listen on')
    args = p.parse_args()

    serve(args.hosts, args.bind, args.port)


if __name__ == '__main__':
    main()
