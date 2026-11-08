# Red Hat OpenShift AI: calculation lane, pipelines, LLM serving (#69)

Everything here runs in the Developer Sandbox namespace `danialheidari619-dev` (OpenShift AI 3.5.2, cluster `rm2`,
no GPU). Log in first: `oc login --web https://api.rm2.thpm.p1.openshiftapps.com:6443`.

| What | Where | State (Sat 7 Nov 2026, EET) |
|---|---|---|
| Calculation image `sinceai-calc` (repo at one commit + mdbtools + Py1546 + LightGBM) | `infra/openshift/calc/Dockerfile`, `build.sh` | VERIFIED 21:20, built from 117a18e |
| Calculation lane as a **Job** (fetch public ITU IFICs → radar engines unchanged → verify) | `infra/openshift/calc/job.yaml`, `lane.py` | VERIFIED 21:10, cold run |
| **Pipeline server** (Data Science Pipelines, KFP v2, artefacts in our MinIO via `models-connection`) | `dspa.yaml`, `minio-netpol.yaml` | VERIFIED Ready 20:57 |
| **Pipeline `sinceai-calc-lane`**: fetch → space pfd vs RR Art. 21 → terrestrial P.1546 vs T/R 25-08 → verify + metrics | `calc_pipeline.py` → `calc_pipeline.yaml` | VERIFIED run `6f2182e7…` SUCCEEDED |
| **Pipeline `p1546-risk-train`**: exact P.1546-6 samples → train q05/q50/q95 → evaluate → safety gate → register in S3 | `train_pipeline.py` → `train_pipeline.yaml` | VERIFIED run `10cde0f0…` SUCCEEDED |
| **Pipeline `ific-time-machine`**: one pod per space IFIC 3062–3083 (`tools/backtest_space.py` unchanged) → `results/space_timeline.json` with a `compute` block; the timeline page (`#/timeline`) shows "Computed on Red Hat OpenShift AI" | `timeline_pipeline.py` → `timeline_pipeline.yaml` | run `df180855…` started Sat 23:00 |
| **Granite 3.3 2B Instruct** on the platform's vLLM CPU runtime (KServe, OCI ModelCar, token auth, AI asset endpoint label) | `infra/openshift/llm/granite.yaml` | VERIFIED Ready; too slow on CPU for live explanations (see below) |

## Calculation lane (the #69 handoff)

```bash
bash infra/openshift/calc/build.sh                 # image from `git archive HEAD`
oc apply -f infra/openshift/calc/job.yaml          # PVC calc-data (5 Gi) + Job
oc logs -f job/sinceai-calc-lane
```

**Measured, cold** (empty PVC, Sat 21:00–21:10, pod limits 4 CPU / 6 GiB, single process): fetch + sha256-verify
space 3074 **78 s**, terrestrial 3076 **4 s**; `radar run --space 3074` **417 s**; `--terrestrial 3076 --previous 3075`
**35 s**; peak RSS **3.3 GiB** (ingest of the 274 MB MDB). Evidence: `infra/openshift/calc/evidence/`.
**Pipeline, warm** (IFICs already on the PVC): space step 162 s, terrestrial 62 s, end to end 380 s.

**What "verified" means.** Every notice in `space_ific3074` (196) and `terrestrial_ific3076` (114) has the **same
outcome and reason code** as the committed `results/`, and the counts are identical (space 12 exceeds / 36 excluded /
22 insufficient / 126 overlap; terrestrial 8 / 1 / 83 / 22). The file **bytes are not identical**, for two reasons that
are not about OpenShift:
1. the committed results on main were built with the 2.4 GB terrain cache (space; margins differ in the 4th decimal,
   e.g. INTELSAT7 66E 10.96695 vs 10.96754 dB) and with terrain mode `off` (terrestrial: sensitivity column text);
   the pod runs `SINCEAI_TERRAIN_MODE=auto` without a cache;
2. the committed `results/space_ific3074.json` on main has **234 findings for 196 notices** (duplicates after the
   18:43–20:20 merges), which `infra.serve` rejects as a contracts v2 ValidationError. Owners: Ignas / Anton.
`lane.py` therefore fails only when an outcome or reason code differs, and still reports per-file byte/normalised
matches. To get byte-identical files the terrain cache would have to be built on the PVC (`make dem`, ~2.4 GB).

## Pipelines

```bash
pip install kfp kfp-kubernetes                    # SDK 2.18 used here
python infra/openshift/pipelines/calc_pipeline.py  # compile -> calc_pipeline.yaml
python infra/openshift/pipelines/train_pipeline.py
python infra/openshift/pipelines/submit.py calc    # or: calc space_ific=3083 terrestrial_ific=3077
python infra/openshift/pipelines/submit.py train --wait
```

Runs, metrics (outcome counts per run, per-file matches; MAE / coverage / missed exceedances) and artefacts are in the
OpenShift AI dashboard → Data science pipelines → Runs, experiment `sinceai-2026`. Calc steps share the PVC
`calc-data` (ReadWriteOnce, so they run one after another). The training gate refuses to register a model whose
missed-exceedance rate is over 0.5 % or whose q05–q95 coverage is under 0.85 (full inputs).
Training run `10cde0f0…` reproduced the committed `risk/metrics.json` exactly (MAE 0.711 dB, coverage 0.9077, missed
exceedances 0.285 %) and registered `s3://models/p1546-risk/runs/10cde0f0-b5be-4b9f-a170-09c8c598c2ff/`.
Serving still reads `p1546-risk/v1`; promoting a run = copy that prefix to the PVC with `kserve/stage-model-job.yaml`.

## Granite on OpenShift AI (LLM)

`oc apply -f infra/openshift/llm/granite.yaml` deploys `granite` (OpenAI-compatible `/v1`), served name `granite`,
behind token auth: `oc create token explain-client` gives a caller token (never commit it).
`explain/` can use it unchanged: `EXPLAIN_LLM_BASE_URL=https://granite-danialheidari619-dev.apps.rm2.thpm.p1.openshiftapps.com/v1`,
`EXPLAIN_LLM_MODEL=granite`, `EXPLAIN_LLM_API_KEY=<token>`, `EXPLAIN_LLM_TIMEOUT=280`, `EXPLAIN_LLM_COMPACT=1`.

**Measured limits (Sat 21:15–21:30):** a short question answers in ~15 s; a finding-sized prompt (2,077 tokens in,
102 out) takes **195 s** on the sandbox CPU. The KServe auth proxy (kube-rbac-proxy) cuts requests at 30 s, so through
the public route only short prompts work. Live explanations therefore stay on Featherless (Qwen2.5-72B); Granite is
usable for in-cluster batch work via the internal service `granite-metrics:8080` (no proxy). Memory: requests 7 GiB,
limit 11 GiB of the 30 GiB quota; scale to 0 when not needed: `oc patch isvc granite --type merge -p '{"spec":{"predictor":{"minReplicas":0}}}'`.
