# Vultr VM runbook (one VM, `sinceai-2026-batch`, Frankfurt, 2 vCPU / 4 GB)

Everything here is a command someone with SSH access can run. No secrets are in this file: logins live in the team
password manager, `/opt/sinceai/.env` is never committed.

| Where | What |
|---|---|
| `/opt/sinceai/app` | the deployed copy of this repo (rsync) |
| `/opt/sinceai/data` | audit log, watcher state, pipeline runs, notifications (kept across deploys) |
| `/opt/sinceai/fiware` | Docker compose stack (Orion-LD, MongoDB, receiver) + Mongo data |
| `/opt/sinceai/backup-app-*.tgz` | one app backup per deploy |
| `/etc/caddy/Caddyfile` | generated from `infra/vultr/backend/Caddyfile` by `setup_backend.sh` |

## Health check (read-only, 5 s)
```bash
ssh root@80.240.25.225 'bash -s' < infra/vultr/health_check.sh (copy: health_check.sh next to this file)     # exit 0 = all PASS; sample: health-check.txt
```
Checks `/api/runs`, public URL answers 401 without login, systemd units and timers, the three FIWARE containers, Orion
`/version`, memory, disk, and that only 22/80/443 are open and listening publicly.

## Deploy (Ignas / whoever holds the logins)
```bash
IP=80.240.25.225 AUTH_USERS="name:<pw> name2:<pw>" ./infra/vultr/deploy_app.sh
```
rsyncs the repo, runs the idempotent `backend/setup_backend.sh` (Caddy, venv, units, **ufw: deny incoming, allow 22/80/443**),
restarts `sinceai-api` and `caddy`. Then run the health check. Do not deploy just before a demo (templates serve first while
the LLM cache warms, see README).

FIWARE stack files (compose, publisher, receiver) are copied to `/opt/sinceai/fiware`; after changing `docker-compose.yml`
or `receiver.py`:
```bash
cd /opt/sinceai/fiware && docker compose up -d && docker compose ps
```

## Restart
```bash
systemctl restart sinceai-api              # app (first minutes serve template explanations while the LLM cache re-warms)
systemctl restart caddy
cd /opt/sinceai/fiware && docker compose restart orion receiver   # restart the receiver too: it shares Orion's network namespace
systemctl start fiware-publish.service     # re-upsert the findings into the broker now (otherwise hourly)
```

## Rollback the app to a previous deploy
```bash
ls -t /opt/sinceai/backup-app-*.tgz | head -3                      # pick one
systemctl stop sinceai-api
mv /opt/sinceai/app /opt/sinceai/app.broken
tar -xzf /opt/sinceai/backup-app-<STAMP>.tgz -C /opt/sinceai       # the archives contain a top-level app/ directory
systemctl start sinceai-api && bash /opt/sinceai/app/infra/vultr/health_check.sh (copy: health_check.sh next to this file)   # (or run it from your laptop as above)
```
`/opt/sinceai/data` is untouched by a rollback (audit log, notifications, runs stay).

## Wake / verify after the VM was idle or rebooted
```bash
systemctl is-active sinceai-api caddy docker sinceai-watcher.timer fiware-publish.timer
docker ps --format '{{.Names}} {{.Status}}'      # three FIWARE containers "(healthy)"; all have restart: unless-stopped
curl -s localhost:1026/version                    # Orion-LD
```
Containers and units are enabled, so a reboot brings everything back without a manual step.

## Memory budget (see ARCHITECTURE.md)
Orion 640 MB cap (384 MB was OOM-killed once, see `incident-orion-oom-20261108.md`), Mongo 512 MB, receiver 64 MB.
If Orion is killed again, restart **orion and receiver together**.

## Teardown (planned: Sun 8 Nov after judging)
Destroy, do not stop (a stopped instance still bills). With the Vultr CLI and the account key held by Ignas:
```bash
vultr-cli instance list                     # find the id of label sinceai-2026-batch
vultr-cli instance delete <ID>
vultr-cli instance list                     # empty
```
Then check the billing page for $0 pending. Before destroying, copy `/opt/sinceai/data/audit*` if the audit log is needed.
