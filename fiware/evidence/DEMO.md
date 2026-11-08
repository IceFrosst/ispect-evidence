# FIWARE demo in 90 seconds

Public app: `https://80-240-25-225.sslip.io` (login from the team; below `$U` = `user:password`). The broker itself is never public:
the app reaches Orion-LD only through a fixed-target, GET-only proxy behind the login.

## 1. In the product (45 s)
1. Open **IFICs**, pick **Space IFIC 3074**, click any notice. The case pop-up opens.
2. Open **Details**. The **Context broker** row shows the finding's NGSI-LD id, e.g.
   `urn:ngsi-ld:Finding:space:3074:relevance%3Aspace%3A3074%3Antc_id%3D123520029`.
3. Click **Show NGSI-LD entity**. The panel is filled by `GET /api/fiware/finding?id=...`, i.e. by the broker, not by the page's own data:
   outcome and margin, the linked notice (`urn:ngsi-ld:SpaceNotice:...`), and **affected stations resolved by a broker query**
   (Finding to notice to FinnishStation, three entity types, two linked-data hops). "Entity JSON-LD" shows the trimmed entity.
   (Only reviewed runs are in the broker; for an automatic run the row is not shown.)

## 2. The same through the API (30 s)
```bash
B=https://80-240-25-225.sslip.io
curl -s -u "$U" $B/api/fiware/status | python3 -m json.tool | head -30
#  "orionld version": "1.8.0" ; counts: Finding 550, FinnishStation 3484, IficRelease 4, SpaceNotice 322, TerrestrialNotice 228

curl -s -u "$U" "$B/api/fiware/entities?type=Finding&limit=1&q=outcome%3D%3D%22exceeds_limit%22" | python3 -m json.tool | head -20
#  a Finding as JSON-LD; q is an NGSI-LD query (53 Findings are exceeds_limit over the four reviewed runs)

curl -s -u "$U" "$B/api/fiware/finding?id=urn:ngsi-ld:Finding:space:3074:relevance%253Aspace%253A3074%253Antc_id%253D123520029" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["hops"], d["stationCount"], "stations;", d["notice"]["id"])'
#  ['Finding', 'SpaceNotice', 'FinnishStation'] <n> stations; urn:ngsi-ld:SpaceNotice:space:3074:...
```
(In a URL the id's own `%` is written `%25`; the UI does this for you.)

## 3. Subscriptions: a new IFIC is announced through NGSI-LD (15 s)
`status` also returns both subscriptions with Orion's own delivery counters:
```bash
curl -s -u "$U" $B/api/fiware/status | python3 -c 'import sys,json; [print(s["id"], s["notification"].get("timesSent"), s["notification"].get("lastSuccess")) for s in json.load(sys.stdin)["subscriptions"]]'
#  urn:ngsi-ld:Subscription:demo:Finding ...   urn:ngsi-ld:Subscription:demo:IficRelease 4 2026-11-08T03:02:51Z
```
Each hourly publish changes the `IficRelease` entities; Orion then POSTs to the receiver (HTTP 204 in `vm/current/runtime.txt`).
Be honest about the limit: the receiver logs the notification, it does not trigger downstream work.

## What to say
The broker is not a dump: the product reads its linked data back (case pop-up), the vocabulary and the reasons we did not adopt a Smart Data Model are
in `SMART_DATA_MODELS.md`, the Orion OOM we hit and fixed is in `vultr/incident-orion-oom-20261108.md` in the evidence bundle.
