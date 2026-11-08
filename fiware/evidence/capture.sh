#!/usr/bin/env bash
# Read-only evidence capture against the already running broker; no Docker access.
set -euo pipefail
cd "$(dirname "$0")"
B=http://127.0.0.1:1026
curl -fsS "$B/version" > version.json
for type in Finding IficRelease; do
  curl -fsS "$B/ngsi-ld/v1/subscriptions/urn:ngsi-ld:Subscription:demo:$type" > "subscription-$type.json"
done
# Use Orion's stored inline context, reachable on the host (not its container hostname).
CONTEXT=$(python3 -c 'import json; print(json.load(open("subscription-Finding.json"))["jsonldContext"].split("/ngsi-ld/")[1])')
LINK="<$B/ngsi-ld/$CONTEXT>; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\""
curl -fsS "$B/ngsi-ld/$CONTEXT" > broker-context.json
printf 'type\tcount\n' > counts.tsv
for type in Finding FinnishStation IficRelease SpaceNotice TerrestrialNotice; do
  curl -fsSG "$B/ngsi-ld/v1/entities" -H "Link: $LINK" \
    --data-urlencode "type=$type" --data-urlencode limit=1 --data-urlencode count=true \
    --data-urlencode attrs=ific_no -D "count-$type.headers" > "count-$type.json"
  printf '%s\t%s\n' "$type" "$(awk 'tolower($1)=="ngsild-results-count:" {gsub("\r", "", $2); print $2}' "count-$type.headers")" >> counts.tsv
done
curl -fsSG "$B/ngsi-ld/v1/entities" -H "Link: $LINK" \
  --data-urlencode type=Finding --data-urlencode 'q=outcome=="exceeds_limit"' \
  --data-urlencode attrs=outcome,ific_no --data-urlencode limit=2 --data-urlencode count=true \
  -D exceeds-limit.headers > exceeds-limit.json
curl -fsSG "$B/ngsi-ld/v1/entities" -H "Link: $LINK" \
  --data-urlencode type=FinnishStation --data-urlencode 'georel=near;maxDistance==50000' \
  --data-urlencode geometry=Point --data-urlencode 'coordinates=[24.9384,60.1699]' \
  --data-urlencode attrs=location,name,synthetic --data-urlencode limit=2 --data-urlencode count=true \
  -D helsinki-50km.headers > helsinki-50km.json
curl -fsSG "$B/ngsi-ld/v1/entities" -H "Link: $LINK" \
  --data-urlencode 'id=urn:ngsi-ld:Finding:space:3073:relevance%3Aspace%3A3073%3Antc_id%3D124545373' \
  --data-urlencode attrs=outcome,notice,affectedStations,release --data-urlencode options=sysAttrs > linked-finding.json
# Follow ALL notice / affected station relationships in this small example.
python3 - <<'PY' > linked-ids.txt
import json
f = json.load(open('linked-finding.json'))[0]
print(f['notice']['object'])
for station in f['affectedStations']['object']:
    print(station)
PY
n=0
while IFS= read -r id; do
  curl -fsSG "$B/ngsi-ld/v1/entities" -H "Link: $LINK" \
    --data-urlencode "id=$id" --data-urlencode attrs=provenance,name,synthetic,location,release \
    > "linked-target-$n.json"
  n=$((n+1))
done < linked-ids.txt
# Normalize HTTP CRLF / terminal blank lines for reviewable text evidence.
python3 - <<'PY'
from pathlib import Path
for path in Path('.').glob('*.headers'):
    path.write_text(path.read_text().rstrip() + '\n')
PY
cat counts.tsv
