# Best Use of Vultr: what ran

Captured Sun 8 Nov 2026 between 04:50 and 04:55 EET from the live VM. Every number below comes from the files in this folder:
`instance.png` (Vultr console, Fri/Sat), `server.txt` and `watcher.txt` (shell output on the VM, no secrets),
`runs.json` (`GET /api/runs`), and the screenshots `releases.png`, `ui.png`, `dialog.png`, `whatif.png`, `archive.png`
(headless Chrome, 1440x900 @2x). The VM serves the app on its loopback port behind Caddy (HTTPS + basic auth, so the
public URL answers 401 without a login, see `server.txt`); the screenshots were taken through an SSH tunnel to that
loopback port, i.e. they are the app exactly as the VM serves it.

## The VM (`instance.png`)
`sinceai-2026-batch`, Frankfurt, 2 vCPU, 4096 MB RAM, 80 GB SSD, Ubuntu 24.04 LTS, tag `sinceai-2026`.
One VM only. Charges were $0.21 at the console screenshot (Sat 7 Nov ~00:36 EET); the VM has run about 1.5 days since, so the current spend is a little higher (*estimate:* about $1 through teardown), far below the team's $100 MLH credit.

## What runs on it (`server.txt`)
| Service | What it does | Evidence |
|---|---|---|
| **Caddy** | HTTPS with an automatic certificate for `https://80-240-25-225.sslip.io` + basic auth (one login per person, so the audit log shows who approved) | `server.txt` (401 without login) |
| **`python -m infra.serve`** (loopback only, behind Caddy) | web UI (releases, notices table, case pop-up, map, What-if calculator, archive) + API (runs, notifications, approve/edit/reject a draft reply, CSV export/import) | `ui.png`, `dialog.png`, `whatif.png`, `archive.png` |
| **IFIC watcher** (`sinceai-watcher.timer`) | polls the ITU release pages every 6 h, downloads a new space or terrestrial IFIC, runs the team's pipeline and posts a notification | `watcher.txt` (timer, state, journal) |
| **FIWARE Orion-LD + MongoDB** (Docker) | publishes the findings as NGSI-LD entities through a read-only proxy | `server.txt` (`docker ps`), `infra/fiware/evidence/` |

## Runs the API serves (`runs.json`)
| Run | Notices | Over limit | Within margin | Needs data | Band overlap | Excluded |
|---|---|---|---|---|---|---|
| space IFIC 3074 (reviewed result) | 196 | 12 | 0 | 22 | 126 | 36 |
| space IFIC 3075 (automatic, unreviewed) | 129 | 4 | 0 | 24 | 82 | 19 |
| space IFIC 3083 (automatic, unreviewed) | 168 | 6 | 0 | 18 | 115 | 29 |
| space IFIC 3073 (reviewed result) | 126 | 15 | 0 | 17 | 75 | 19 |
| terrestrial IFIC 3075 (reviewed result) | 114 | 18 | 0 | 8 | 0 | 69 |
| terrestrial IFIC 3076 (reviewed result) | 114 | 8 | 1 | 0 | 0 | 83 |

6 runs, 847 notices in total, none of them mock data. "Automatic, unreviewed" runs were built by the watcher/pull
pipeline on the VM; the app labels them as such and keeps them out of the reviewed results.

## Why Vultr
Judges and Traficom engineers use one HTTPS URL instead of a laptop on venue Wi-Fi; the watcher keeps polling the ITU
while every laptop is closed; one small VM runs the whole product.

## Teardown
*Planned:* destroy (not stop) on Sun 8 Nov after judging, then check billing for $0 pending (issue #27).
