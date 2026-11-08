# Verify it yourself (read-only)

Everything below only reads. On the VM (SSH) the broker is on loopback; from outside use the app's proxy (needs a login).

## On the VM
```bash
curl -s localhost:1026/version                                        # orionld version 1.8.0
docker ps --format '{{.Names}} {{.Image}} {{.Status}}'                # orion, mongo, receiver: (healthy)
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}'           # orion ~250 MiB of 640, mongo ~150 of 512
systemctl list-timers fiware-publish                                  # hourly read-only publisher
bash /opt/sinceai/app/infra/vultr/health_check.sh                     # all PASS (after the next deploy; or pipe it over ssh)

# counts per type (needs the project context in the Link header; copy it from the subscription)
CTX=$(curl -s localhost:1026/ngsi-ld/v1/subscriptions/urn:ngsi-ld:Subscription:demo:Finding | python3 -c 'import sys,json; print(json.load(sys.stdin)["jsonldContext"])')
LINK="<${CTX/http:\/\/*:1026/http://127.0.0.1:1026}>; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
for T in Finding FinnishStation IficRelease SpaceNotice TerrestrialNotice; do
  curl -s -D- -o /dev/null "localhost:1026/ngsi-ld/v1/entities?type=$T&limit=1&count=true" -H "Link: $LINK" | grep -i ngsild-results-count; done
# expected: 550, 3484, 4, 322, 228  (= counts.tsv)

# NGSI-LD query: findings over the limit; geo-query: stations within 50 km of Helsinki
curl -s -D- -o /dev/null "localhost:1026/ngsi-ld/v1/entities?type=Finding&q=outcome==%22exceeds_limit%22&limit=1&count=true" -H "Link: $LINK" | grep -i ngsild-results-count   # 53
curl -s "localhost:1026/ngsi-ld/v1/entities?type=FinnishStation&georel=near;maxDistance==50000&geometry=Point&coordinates=%5B24.94,60.17%5D&limit=1&count=true" -H "Link: $LINK" -H "Accept: application/json" | head -c 300
# delivery: the receiver's HTTP answers to Orion
docker logs --tail 3 fiware-receiver-1                                # POST /notify?subscriptionId=... 204
```

## From outside, through the proxy (login required; `U=user:password`)
```bash
curl -s -u "$U" https://80-240-25-225.sslip.io/api/fiware/status | python3 -m json.tool | head -20
curl -s -o /dev/null -w '%{http_code}\n' -X POST -u "$U" https://80-240-25-225.sslip.io/api/fiware/entities   # 405: GET only
curl -s -o /dev/null -w '%{http_code}\n' https://80-240-25-225.sslip.io/api/fiware/status                       # 401 without login
```
Files next to this one are captures of the same commands: `status.json`, `subscriptions.json`, `counts.tsv`, `runtime.txt`,
`finding-sample.json`, `exceeds-limit-sample.json`.
