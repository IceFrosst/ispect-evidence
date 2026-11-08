# FIWARE on the demo VM: what runs and the evidence (refreshed Sun 8 Nov 2026 ~06:05 EET)

Everything here was captured from the live VM (`runtime.txt`, `status.json`, `subscriptions.json`, `counts.tsv`,
`exceeds-limit-sample.json`, `finding-sample.json`). No secrets. The app reaches the broker only through a read-only
proxy (`GET /api/fiware/status`, `GET /api/fiware/entities`, behind the login); the broker itself listens on the VM's
loopback port.

## How we use FIWARE
- **Orion-LD 1.8.0** (NGSI-LD context broker, Docker) with **MongoDB 5.0.31** on the Vultr VM holds our screening results as
  linked data: `Finding`, `SpaceNotice`, `TerrestrialNotice`, `FinnishStation`, `IficRelease`. A Finding links to its
  notice and to the affected stations, so the broker answers "which Finnish stations does this filing affect" as a graph query.
- **Read-only publisher** (`fiware-publish.timer`, hourly): upserts the committed result files into the broker. It never
  writes back into `results/`.
- **Queries and subscriptions:** `q=outcome=="exceeds_limit"` returns **53 Findings** (space 3073: 15, space 3074: 12,
  terrestrial 3075: 18, terrestrial 3076: 8); geo-queries on stations; NGSI-LD subscriptions notify a receiver when a
  release changes (`subscriptions.json`: status active, `lastSuccess` set, no failure after the fix below).
- **Counts now (`counts.tsv`):** Finding 550, FinnishStation 3,484, IficRelease 4, SpaceNotice 322, TerrestrialNotice 228.
- Earlier laptop evidence (`../../` folder) shows the same flow with every command and its output.

## Honest limits
- The JSON-LD vocabulary is **our own project context**, not an official FIWARE Smart Data Model.
- A subscription notification proves **Orion's HTTP delivery** to our receiver (HTTP 204 in `runtime.txt`); the receiver
  only logs it, there is no durable downstream processing.
- The broker holds only the **reviewed result runs** (3073, 3074, terrestrial 3075, 3076), not the automatic runs.

## Found and fixed on 8 Nov (caught while refreshing this evidence)
1. **Orion was OOM-killed once** (00:52 UTC) at its 384 MB memory cap and auto-restarted; the receiver, which shares Orion's
   network namespace, stayed attached to the dead one, so notifications failed (`lastFailure` on the IficRelease
   subscription). Fix: Orion cap raised to 640 MB (`infra/fiware/docker-compose.yml`), receiver restarted. Orion now uses
   about 243 MB of 640 MB (`runtime.txt`).
2. **The receiver answered 404** to every notification, because Orion appends `?subscriptionId=...` and the receiver compared
   the whole path. Fix in `infra/fiware/receiver.py` plus a regression test (`test_receiver_accepts_the_query_string_orion_appends`).
   Evidence: `runtime.txt` shows `POST /notify?subscriptionId=... 204`.
