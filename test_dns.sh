#!/usr/bin/env bash
# Quick test script for the minimal DNS responder

set -euo pipefail

PORT=${1:-5353}
HOST=${2:-127.0.0.1}

echo "Testing DNS server at ${HOST}:${PORT}"

# Domains to test (auto-respond list)
domains=(
	google.com
	example.com
	github.com
	stackoverflow.com
	youtube.com
	facebook.com
	twitter.com
	amazon.com
	wikipedia.org
	reddit.com
	linkedin.com
	netflix.com
	instagram.com
	apple.com
	microsoft.com
)

# Additional subdomains the user reported NXDOMAIN for; test these explicitly
extra_domains=(
	api.example.com
	api.facebook.com
	blog.microsoft.com
)

print_result() {
	local d=$1
	# capture short answer
	out=$(dig +short @${HOST} -p ${PORT} ${d} A || true)

	# capture header status (e.g., NOERROR, NXDOMAIN)
	status=$(dig +noall +comments @${HOST} -p ${PORT} ${d} A 2>/dev/null | awk -F"status: " '/status:/{print $2}' | awk -F"," '{print $1}') || status="UNKNOWN"

	if [ -z "${out// }" ]; then
		printf "%-30s : %-15s : %s\n" "${d}" "NO ANSWER" "${status}"
	else
		first=$(echo "$out" | head -n1)
		printf "%-30s : %-15s : %s\n" "${d}" "$first" "${status}"
	fi
}

for d in "${domains[@]}"; do
	print_result "$d"
done

echo "-- extra subdomain checks --"
for d in "${extra_domains[@]}"; do
	print_result "$d"
done

echo "Done. Domains above should return a 10.x.x.x A record (for auto-respond list) or values from hosts.txt if configured." 
