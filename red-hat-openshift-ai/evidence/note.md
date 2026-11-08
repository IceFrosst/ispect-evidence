# Red Hat OpenShift AI: what ran

Refreshed Sun 8 Nov 2026, 03:07–03:40 UTC (05:07–05:40 EET), from the live cluster and the live VM. Every claim below
points to a file in this folder. Captured with `oc`, the cluster's pipeline API and `ssh`; no tokens, passwords or keys
in any file. **The files are the evidence; the live links are a supplementary check** (see "Reliability").

| File | What it proves |
|---|---|
| `e2e-whatif-kserve-20261108.txt` | one end-to-end transaction: the What-if on the Vultr VM (deployed code = commit `ff9f304`) → HTTP 200 → `POST /predict 200` in the KServe predictor log one second later, all UTC-timestamped |
| `whatif-ml.png` | the deployed What-if (same VM, 03:40 UTC) with the antenna height unknown: outcome **Not assessed**, below it the ML estimate |
| `oc-status-20261108.txt` | InferenceServices, Deployments, Routes, Jobs in the namespace |
| `healthz-kserve-20261108.json`, `healthz-route-20261108.json` | the served model's metrics; KServe reads `/mnt/models`, the fallback reads the image |
| `model-hashes-20261108.txt` | the three model files in S3 `v1` and in the KServe pod are byte-identical (sha256) |
| `pipeline-runs-20261108.json` | all four pipeline runs with terminal state and every step's state, from the pipeline API |
| `pipeline-calc-lane-verify-6f2182e7.json` | the `verify.json` written by the successful calculation pipeline (`ok: true`, `outcomes_identical: true`) |
| `pipeline-train-metrics-10cde0f0.json`, `pipeline-train-register-10cde0f0.txt` | the training pipeline's metrics and the registration in S3 |
| `pipeline-train-90e85d7d-failed.txt` | the failed first training run, with its cause |
| `granite-stats.json`, `granite-sample-accepted.json` | the Granite batch: counts and one accepted text |
| `../calc/evidence/` | the cold calculation Job (a failed run, see below) |
| `../kserve/`, `../pipelines/`, `../llm/` | the manifests and pipeline sources |

## The platform
**Red Hat OpenShift AI 3.5.2 on the Red Hat Developer Sandbox**, cluster `rm2` (`api.rm2.thpm.p1.openshiftapps.com`),
namespace `danialheidari619-dev`. Quota: 3 CPU / 14 GiB for builds, 3 CPU / 30 GiB for deployments, 80 GiB storage,
**no GPU** (confirmed by Red Hat). Free; the sandbox lasts 30 days from 6 Nov.

## What is deployed and what it is for
**One model is in production use: the P.1546 risk model**, a LightGBM quantile surrogate (q05 / q50 / q95) of ITU-R
P.1546-6 field strength. It is served by **KServe `InferenceService p1546-risk`** (custom ServingRuntime = our FastAPI
`risk_api.py`, RawDeployment; model files versioned in S3 (MinIO) through the OpenShift AI data connection
`models-connection`, staged to PVC `p1546-models`, mounted at `/mnt/models`). A plain Deployment `p1546-risk` serves
the same model as a fallback.

**Its one caller is the What-if calculator**, when a transmitter's antenna height is unknown: it then shows an interval
and a probability over the trigger instead of a margin. **It never sets an outcome, a margin or a rank**, and no result
file depends on it; the screenshot shows the outcome staying "Not assessed".

Model quality (`healthz-kserve-20261108.json`, `pipeline-train-metrics-10cde0f0.json`): trained on 96,000 samples
labelled by the exact P.1546-6 code, tested on 24,000: held-out **MAE 0.711 dB** with all inputs; **6.165 dB** when
each of effective height, receiver height and sea share is hidden half the time; **0.285 %** of real trigger
exceedances missed with all inputs.

## Pipelines (`pipeline-runs-20261108.json`)
Pipeline server: Data Science Pipelines (DSPA `dspa`, KFP v2, artefacts in our MinIO).

| Run | Pipeline | State | Steps |
|---|---|---|---|
| `90e85d7d` (Sat 19:00 UTC) | `p1546-risk-train` | **FAILED** | `train-model` failed: the image lacked `libgomp` (`pipeline-train-90e85d7d-failed.txt`); image fixed |
| `10cde0f0` (Sat 19:23) | `p1546-risk-train` | **SUCCEEDED** | generate-samples → train-model → gate-and-register all SUCCEEDED; registered `s3://models/p1546-risk/runs/10cde0f0…/` |
| `6f2182e7` (Sat 19:23) | `sinceai-calc-lane` | **SUCCEEDED** | fetch-ific ×2 → calculate ×2 → verify-results all SUCCEEDED; `verify.json`: `ok: true`, `outcomes_identical: true` vs the committed results (commit `117a18e`) |
| `df180855` (Sat 21:01) | `ific-time-machine` | **still RUNNING** after 6 h: 3 per-IFIC backtest steps SUCCEEDED, the loop has not finished; treat as not completed | |

The training pipeline **reproduced the reported predictive metrics**: 22 of 25 keys in `metrics.json` identical, the 3
that differ are timing; its q50 model file is byte-identical to `v1` (`model-hashes-20261108.txt`).

## The cold calculation Job: a failed run
`../calc/evidence/job-sinceai-calc-lane.yaml` and `lane-run1.json`: the Job `sinceai-calc-lane` (`backoffLimit: 0`)
ran Sat 19:00–19:09 UTC, executed the calculations (fetch 78 s, space 3074 417 s, terrestrial 3076 35 s, peak 3.3 GiB)
and then **failed its comparison step** (pod exit 1, `ok: false`): its counts equal the committed results (space
12 / 36 / 22 / 126, terrestrial 8 / 1 / 83 / 22), but the files are not byte-identical because the pod had no terrain
cache, and the comparison at that time required identical files. The comparison was then changed to compare outcome
and reason code per notice; the pipeline run `6f2182e7` passed it (above).

## Granite (`granite-stats.json`)
**Granite 3.3 2B Instruct** (Apache-2.0) runs on the platform's vLLM CPU runtime as KServe `InferenceService granite`
(Ready). An in-cluster batch Job tried it on the 53 over-limit findings of four result files: **8 accepted, 45 fell back
to the deterministic template** (rejected by our number guard, or timed out), 17,929 s on CPU. One accepted text:
`granite-sample-accepted.json`. **Granite is not the live explanation model**; Featherless stays live.

## Reliability
The live endpoints are a supplementary check, not uninterrupted service: the KServe `isvc p1546-risk` was
`Ready=False` for ~11 h on Saturday (a rolling update could not attach the model PVC) until it was fixed at 17:43 EET
with `deploymentStrategy: Recreate`, and the sandbox scales idle workloads to zero after ~12 h. **Before judging:**
`curl https://p1546-risk-danialheidari619-dev.apps.rm2.thpm.p1.openshiftapps.com/healthz`; if it does not answer,
`oc scale deploy/p1546-risk-predictor --replicas=1 -n danialheidari619-dev`.

## Why OpenShift AI
Traficom would run this on-prem. Everything here is Kubernetes manifests, a KServe InferenceService, KFP pipelines and
an open-weight model, so it moves to an on-prem OpenShift without code changes.
