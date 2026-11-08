# Post-mortem: Orion-LD OOM-killed on the demo VM (Sun 8 Nov 2026)

Blameless, short. Facts come from `infra/fiware/evidence/vm/current/note.md`, `runtime.txt`, and git history
(`057bd77`, `a418f72`). Times are UTC unless stated.

## Impact
For about 4 hours (00:52 UTC to the fix at ~03:00 UTC) the FIWARE subscription notifications for new IFIC releases
failed. The app itself, the pipeline results and the committed result files were not affected: the broker is a read-only
publication target, never a source of results. No user-visible outage.

## Timeline
- **~00:52** Orion-LD hit its 384 MB container memory cap (`mem_limit: 384m`) while resident memory was ~0.35 GB and was OOM-killed.
  Docker's `restart: unless-stopped` brought it back.
- The receiver container shares Orion's network namespace (`network_mode: service:orion`). After the restart it stayed
  attached to the **dead** namespace, so it no longer received anything. The IficRelease subscription showed `lastFailure`.
- **~03:00 (found while refreshing the evidence)** Checking `status.json` / `subscriptions.json` showed the failure.
- Restarting the receiver revealed a second, older bug: it answered **404** to every notification, because Orion appends
  `?subscriptionId=...` to the callback and the receiver compared the whole path with `/notify`.
- Fix pushed 05:01 EET (`057bd77`): receiver compares only the path; regression test
  `test_receiver_accepts_the_query_string_orion_appends`; Orion `mem_limit` 384m to 640m.
- Verified: `runtime.txt` shows `POST /notify?subscriptionId=urn:ngsi-ld:Subscription:demo:IficRelease HTTP/1.1" 204`, and the
  subscription has `lastSuccess` and no new `lastFailure`.

## Root causes
1. Memory cap sized from a cold-start observation; Orion grows after the publisher loads ~550 findings and 3,484 stations.
2. A sidecar sharing another container's network namespace does not follow it across a restart.
3. The receiver had only been tested with a hand-written path, never with Orion's real callback URL.

## What we changed
- Orion 640 MB (steady state ~247 MB, 39 % of the cap); Mongo 512 MB; receiver 64 MB (`docker stats` in `runtime.txt`).
- Receiver ignores the query string (tested). Runbook: always restart `orion` and `receiver` together.
- `infra/vultr/health_check.sh` checks all three containers are `healthy`, so a detached receiver or dead Orion fails the check.

## What we did not do (honest)
- No alerting: this was found by a person refreshing evidence. A health check exists but nothing runs it on a timer.
- The receiver still only logs notifications; there is no durable downstream processing.
