# Real Orion-LD evidence — 2026-11-07

> **Current evidence from the live VM (08 Nov 2026, after the Orion memory-cap and receiver fixes): [`vm/current/note.md`](vm/current/note.md).** The text below is the earlier laptop run.

Broker: Orion-LD 1.8.0 at http://127.0.0.1:1026; owner reports MongoDB 5.0.31.
Stack started by owner; worker had HTTP access only. No Docker commands were run
in this session. Stack deliberately left running. No secrets in these captures.

## Commands executed (repository root)

```sh
export PY=python   # the project venv interpreter (python 3.12 + requirements.txt)
$PY -m infra.fiware.publish --broker http://127.0.0.1:1026 --all
$PY -m infra.fiware.subscribe --broker http://127.0.0.1:1026 --receiver http://127.0.0.1:8089/notify
$PY -m infra.fiware.publish --run terrestrial_ific3076
# Before another publish cycle, save baseline broker counters:
for t in Finding IficRelease; do
  curl -fsS http://127.0.0.1:1026/ngsi-ld/v1/subscriptions/urn:ngsi-ld:Subscription:demo:$t > infra/fiware/evidence/subscription-$t-before-trigger.json
done
$PY -m infra.fiware.publish --all | tee infra/fiware/evidence/publish-all.txt
$PY -m infra.fiware.publish --run terrestrial_ific3076 | tee infra/fiware/evidence/trigger-3076.txt
sleep 2
bash infra/fiware/evidence/capture.sh
$PY -m pytest infra -q
```

`capture.sh` contains exact curl commands for versions, subscription status,
per-type counts, q-filter, Helsinki geo-query, Finding relationships and their
notice / affected station targets. All corresponding outputs are saved here.
Query results are intentionally projected / limited to keep the files small;
headers retain the full matching entity counts.

## Results

- Published space 3073: 1,124; space 3074: 1,264; terrestrial 3075: 1,014;
  terrestrial 3076: 996. Total 4,398 stable entities, even after repeat upserts.
- Broker counts: 455 Finding, 3,484 FinnishStation (871 synthetic rows per release),
  4 IficRelease, 322 SpaceNotice, 133 TerrestrialNotice.
- `q=outcome=="exceeds_limit"`: 29 Findings.
- Stations within 50 km of Helsinki `[24.9384,60.1699]`: 192 release-scoped entities.
- The linked sample Finding points to SpaceNotice 124545373 and exactly one
  affected FinnishStation 405674; both resolved through broker queries.
- Orion subscription counters: Finding 2 → 10, IficRelease 1 → 6; both active,
  notification status ok, matching lastSuccess and lastNotification timestamps.
  This proves Orion HTTP delivery, not durable receiver processing. Host receiver
  logs are unavailable because it shares Orion's network namespace.
- `pytest infra -q`: 50 passed; 2,336 existing NumPy matrix deprecation warnings.

## Compatibility fixes observed against the broker

1. Inline `@vocab` alone left entity types/attributes unexpanded on Orion 1.8.
   Explicit top-level context mappings fixed this; all entities were republished.
2. Expanded context payloads hit HTTP 413 for some batches of 100; adaptive
   splitting now retries smaller batches (single-entity failures still propagate).
3. Subscription JSON rejected literal double quotes as forbidden characters;
   `%22` quoting works. GET q-filters use normal quotes and a context Link header.
4. GeoProperty Point input and underscore-containing mapped attribute names were
   accepted unchanged. Full-IRI q attribute queries returned zero on this version;
   the stored project context and compact names work.

Initial `python -m ...` failed because system Python lacks pydantic; the project
virtualenv above worked. Initial incompatibility attempts are not counted as
successful evidence. The final snapshots use the corrected mapping and broker.

See `docs/fiware.md` for owner startup/teardown, crash versions, security and
model limitations. Broker-generated context IDs and dates are snapshot-specific.
