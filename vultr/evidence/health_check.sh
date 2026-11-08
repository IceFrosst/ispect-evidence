#!/usr/bin/env bash
# Read-only health check. Run ON the VM (as root), or from a laptop:
#   ssh -i ~/.ssh/<key> root@80.240.25.225 'bash -s' < infra/vultr/health_check.sh
# Exit code 0 = every check passed, 1 = at least one FAIL line. It changes nothing and prints no secrets.
FAIL=0
ok()   { printf 'PASS  %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; FAIL=1; }
echo "# health check $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(hostname)"

# 1. app answers on loopback (Caddy adds the login in front; the public URL must answer 401 without it)
RUNS=$(curl -fsS --max-time 5 http://127.0.0.1:8000/api/runs 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null)
[ -n "$RUNS" ] && [ "$RUNS" -ge 1 ] && ok "GET /api/runs -> $RUNS runs" || bad "GET /api/runs did not return a run list"
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://${DOMAIN:-80-240-25-225.sslip.io}/api/runs")
[ "$CODE" = "401" ] && ok "public URL without login -> 401" || bad "public URL without login -> $CODE (expected 401)"

# 2. systemd
for u in sinceai-api caddy docker; do
  [ "$(systemctl is-active $u)" = active ] && ok "service $u active" || bad "service $u not active"
done
for t in sinceai-watcher.timer fiware-publish.timer; do
  [ "$(systemctl is-active $t)" = active ] && ok "timer $t active" || bad "timer $t not active"
done

# 3. FIWARE stack (containers + broker)
for c in fiware-orion-1 fiware-mongo-1 fiware-receiver-1; do
  s=$(docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{end}}' $c 2>/dev/null)
  [ "$s" = "running/healthy" ] && ok "container $c $s" || bad "container $c state '$s'"
done
V=$(curl -fsS --max-time 3 http://127.0.0.1:1026/version 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)["orionld version"])' 2>/dev/null)
[ -n "$V" ] && ok "Orion-LD $V answers on loopback" || bad "Orion-LD /version failed"
docker stats --no-stream --format 'INFO  {{.Name}} {{.MemUsage}}' 2>/dev/null

# 4. memory and disk (thresholds: <90 % used)
read -r TOT AVAIL < <(free -m | awk '/^Mem:/ {print $2, $7}')
[ $((AVAIL * 100 / TOT)) -ge 10 ] && ok "memory: ${AVAIL} MB available of ${TOT} MB" || bad "memory: only ${AVAIL} of ${TOT} MB available"
USE=$(df --output=pcent / | tail -1 | tr -dc 0-9)
[ "$USE" -lt 90 ] && ok "disk /: ${USE}% used" || bad "disk /: ${USE}% used"

# 5. firewall: exactly 22, 80, 443 open (IPv4 rules)
OPEN=$(ufw status | awk '/ALLOW/ && !/\(v6\)/ {split($1,a,"/"); print a[1]}' | sort -n | tr '\n' ' ')
[ "$OPEN" = "22 80 443 " ] && ok "ufw allows only 22 80 443" || bad "ufw open ports: '$OPEN'"
# nothing but SSH and Caddy listens on a public address
PUB=$(ss -ltnH | awk '$4 !~ /^(127\.|\[::1\]|\[?::1)/ && $4 !~ /%lo/ {n=split($4,a,":"); print a[n]}' | sort -un | tr '\n' ' ')
[ "$PUB" = "22 80 443 " ] && ok "public listeners: $PUB" || bad "public listeners: '$PUB'"

[ $FAIL -eq 0 ] && echo "RESULT: all checks passed" || echo "RESULT: FAILED"
exit $FAIL
