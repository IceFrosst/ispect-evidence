# Red Hat OpenShift AI: what ran

Refreshed Sun 8 Nov 2026, 03:07–04:10 UTC (05:07–06:10 EET), from the live cluster and the live VM. Every claim below
points to a file in this folder. Captured with `oc`, the cluster's pipeline API and `ssh`; no tokens, passwords or keys
in any file. **The files are the evidence; the live links are a supplementary check** (see "Reliability").

| File | What it proves |
|---|---|
| `e2e-whatif-kserve-20261108.txt` | end-to-end, UTC-timestamped: the What-if on the Vultr VM (deployed code identified by file hashes) → HTTP 200 → `POST /predict 200` in the KServe predictor log; section 4 ties the screenshot to its own log line; section 5 records tonight's outage |
| `whatif-ml.png` | the deployed What-if (04:10:09 UTC, request logged by KServe the same second), all inputs visible, antenna height unknown: outcome **Not assessed**, below it the ML estimate (88 %, 17.7–55.8 dB(µV/m)) |
| `oc-status-20261108.txt` | InferenceServices, Deployments, Routes, Jobs in the namespace (Job DURATION there is time since start, not run time; `surrogate-api` 0/0 is an unused placeholder from Friday) |
| `healthz-kserve-20261108.json`, `healthz-route-20261108.json` | liveness + where each endpoint loads the model from (KServe `/mnt/models`, fallback the image). The metrics block is the `metrics.json` shipped in the image; it equals `v1/metrics.json` except timing |
| `model-hashes-20261108.txt` | the three model files are byte-identical (sha256) in S3 `v1`, in the KServe pod and in the repo's `risk/artifacts/`; q50 of the pipeline run too (its q05/q95 not compared) |
| `pipeline-runs-20261108.json` | all four pipeline runs with terminal state and every step's state, from the pipeline API |
| `pipeline-calc-lane-verify-6f2182e7.json` | the `verify.json` written by the successful calculation pipeline (`ok: true`, `outcomes_identical: true`) |
| `pipeline-train-metrics-10cde0f0.json`, `pipeline-train-register-10cde0f0.txt` | the training pipeline's metrics and the registration in S3 |
| `pipeline-train-90e85d7d-failed.txt` | the failed first training run, with its cause |
| `granite-stats.json`, `granite-sample-accepted.json` | the Granite batch: counts and one accepted text |
| `../calc/evidence/` | the cold calculation Job (a failed run, see below) |
| `../kserve/`, `../pipelines/`, `../llm/` | the manifests and pipeline sources |

The code that calls the model (`infra/openshift/risk_api.py`, `risk/assess.py`, `infra/playground.py`) and the result
files with the `risk_model` blocks (`results/`) are in the source zip, not in this evidence bundle.

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

**Its network caller is the What-if calculator**, when a transmitter's antenna height is unknown: it then shows an
interval and a probability over the trigger instead of a margin. **The same model bytes** (committed `risk/artifacts/`,
sha256 equal to S3 `v1` and `/mnt/models`) also run in-process in the canonical terrestrial runs, where every finding
carries a `risk_model` uncertainty block (all 114 in `results/terrestrial_ific3076.json`). In both places it is context
only: **it never sets an outcome, a margin or a rank**; the screenshot shows the outcome staying "Not assessed".

Model quality (`pipeline-train-metrics-10cde0f0.json`, also in `healthz-*.json`): trained on 96,000 samples
labelled by the exact P.1546-6 code, tested on 24,000: held-out **MAE 0.711 dB** with all inputs; **6.165 dB** when
each of effective height, receiver height and sea share is hidden half the time; **0.285 %** of real trigger
exceedances missed with all inputs.

## Pipelines (`pipeline-runs-20261108.json`)
Pipeline server: Data Science Pipelines (DSPA `dspa`, KFP v2, artefacts in our MinIO). Step names and states below are
the exported `task_details` (KFP's driver/executor bookkeeping tasks left out).

| Run | Pipeline | State | Steps |
|---|---|---|---|
| `90e85d7d` (Sat 19:00 UTC) | `p1546-risk-train` | **FAILED** | generate-samples SUCCEEDED → `train-model` FAILED (the image lacked `libgomp`, `pipeline-train-90e85d7d-failed.txt`) → gate-and-register never ran; image fixed |
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
**Granite 3.3 2B Instruct** (Apache-2.0) ran on the platform's vLLM CPU runtime as KServe `InferenceService granite`;
**scaled to 0 on Sun 04:00 UTC** to free sandbox quota for the live P.1546 model (see Reliability). An in-cluster batch Job tried it on the 53 over-limit findings of four result files: **8 accepted, 45 fell back
to the deterministic template** (rejected by our number guard, or timed out), 17,929 s on CPU. One accepted text:
`granite-sample-accepted.json`. **Granite is not the live explanation model**; Featherless stays live.

## Reliability
The live endpoints are a supplementary check, not uninterrupted service. **Sun ~03:40–04:05 UTC** both model
deployments went to 0 pods and could not restart because the sandbox quotas were full (memory, then the account-wide
50-pod count that includes finished pipeline pods); fixed by scaling Granite to 0 and deleting 23 finished pipeline
driver pods (`e2e-whatif-kserve-20261108.txt` §5). Earlier: the KServe `isvc p1546-risk` was
`Ready=False` for ~11 h on Saturday (a rolling update could not attach the model PVC) until it was fixed at 17:43 EET
with `deploymentStrategy: Recreate`, and the sandbox scales idle workloads to zero after ~12 h. **Before judging:**
`curl https://p1546-risk-danialheidari619-dev.apps.rm2.thpm.p1.openshiftapps.com/healthz`; if it does not answer,
`oc scale deploy/p1546-risk-predictor --replicas=1 -n danialheidari619-dev`.

## Why OpenShift AI
Traficom would run this on-prem. Everything here is Kubernetes manifests, a KServe InferenceService, KFP pipelines and
an open-weight model, so it moves to an on-prem OpenShift without code changes.
