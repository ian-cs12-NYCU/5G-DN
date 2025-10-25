#!/usr/bin/env bash
# Quick test script for the minimal DNS responder

set -euo pipefail

PORT=${1:-5353}
HOST=${2:-127.0.0.1}

echo "Testing DNS server at ${HOST}:${PORT}"

dig +short @${HOST} -p ${PORT} example.local A || true
dig +short @${HOST} -p ${PORT} test.local A || true

echo "If no answers printed, ensure the container is running and the hosts file contains the names." 
