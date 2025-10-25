# Minimal DNS responder container

This folder contains a tiny DNS responder suitable for generating realistic DNS traffic in a test network.

Files:

- `Dockerfile` - builds an image with a Python-based DNS responder using `dnslib`.
- `server.py` - the DNS responder. Reads `hosts.txt` and answers A queries.
- `hosts.txt` - sample domain -> IP mappings.

Usage (build & run):

1. Build the image:

   docker build -t dns_simple .

2. Run listening on the real DNS port (requires root):

   docker run --rm -p 53:53/udp --name dns_simple dns_simple

   Or run on an unprivileged port (e.g., 5353) and map it:

   docker run --rm -p 5353:53/udp dns_simple

   Then query with: `dig @127.0.0.1 -p 5353 example.local A`

Hosts file format

Each non-comment line contains: `domain ip` (separated by whitespace). The server matches the exact domain and returns the IPv4 address for A queries. Example:

    example.local 10.10.0.5

Do I need a DNS->IP mapping table?

Yes — for this minimal responder you must provide the mappings for the names you want the server to answer. Put them in `hosts.txt`. If a name is not found the server returns NXDOMAIN.

If you need more advanced behaviour (recursive resolving, wildcards, PTR records, SRV, or forwarding to upstream resolvers), consider using `dnsmasq` or `bind9` instead.
