#!/usr/bin/env python3
"""
Minimal DNS responder using dnslib.

Reads a simple hosts file (domain IP per line) and replies to A queries.
If a name isn't found it returns NXDOMAIN. Optionally you can run on a
non-privileged port (e.g., 5353) to avoid needing root to bind 53.
"""
import argparse
import socket
import random
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


# Domains we should always answer (with a random IP) instead of returning NXDOMAIN.
# This simulates DNS responses for a set of well-known domains in tests.
AUTO_RESPOND_DOMAINS = set([
    "google.com",
    "example.com",
    "github.com",
    "stackoverflow.com",
    "youtube.com",
    "facebook.com",
    "twitter.com",
    "amazon.com",
    "wikipedia.org",
    "reddit.com",
    "linkedin.com",
    "netflix.com",
    "instagram.com",
    "apple.com",
    "microsoft.com",
])


def random_private_ipv4():
    # return an address in 10.0.0.0/8 to avoid appearing as a public routable IP
    return f"10.{random.randint(0,255)}.{random.randint(0,255)}.{random.randint(1,254)}"


def should_autorespond(qname_lower: str) -> bool:
    """Return True if qname should be auto-responded based on AUTO_RESPOND_DOMAINS.

    Matches either an exact domain (example.com) or any subdomain (*.example.com).
    """
    for d in AUTO_RESPOND_DOMAINS:
        if qname_lower == d:
            return True
        if qname_lower.endswith('.' + d):
            return True
    return False


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
        qlower = qname.lower()

        # First, if the name matches the auto-respond list (exact or subdomain), send a random private IPv4
        if should_autorespond(qlower):
            ip = random_private_ipv4()
            reply.add_answer(RR(q.get_qname(), QTYPE.A, rdata=A(ip), ttl=60))
        else:
            ip = hosts.get(qlower)
            if ip:
                reply.add_answer(RR(q.get_qname(), QTYPE.A, rdata=A(ip), ttl=60))
            else:
                # Keep existing behaviour for names we don't handle
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
