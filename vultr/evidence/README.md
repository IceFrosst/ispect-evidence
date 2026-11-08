# Evidence: Best Use of Vultr (MLH)

Collect **before** teardown (the VM is gone afterwards). Put files here; keep each screenshot < 1 MB.

- [x] `instance.png`: Vultr console instance page (plan, region, label `sinceai-2026-batch`).
- [x] `watcher.txt`: `systemctl list-timers sinceai-watcher`, watcher state, `ls -la` of the runs folder.
- [x] `server.txt`: `systemctl status sinceai-api caddy` + last 30 API log lines (client IPs masked).
- [x] `ui.png`: IFIC 3074 Notices table (current UI, 08 Nov).
- [x] `releases.png`: the Releases list (pulled and automatic runs).
- [x] `dialog.png`: the case pop-up (verdict, key numbers, decision bar).
- [x] `archive.png`: the Archive tab over 22 IFICs.
- [x] `whatif.png`: What-if calculator result (P.1546), current UI.
- [x] `runs.json`: `GET /api/runs` on the VM (run counts used in `note.md`).
- [x] `note.md`: what ran (UI + API + watcher), plan + cost, URL, uptime. Numbers from logs, not from memory.

Submission (README §20 / guide §1.5): tick *Best Use of Vultr*, put `Vultr` in the first five "Built with".
