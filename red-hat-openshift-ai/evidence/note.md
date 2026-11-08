# Red Hat OpenShift AI: what ran

Refreshed Sun 8 Nov 2026 ~05:10 EET (03:07 UTC) from the live cluster. Every claim below points to a file in this
folder or the folder named next to it. Captured with `oc` and `curl`; no tokens, passwords or keys in any file.

| File | What it shows | Captured |
|---|---|---|
| `oc-status-20261108.txt` | InferenceServices, Deployments, Routes and Jobs in the namespace | Sun 03:07 UTC |
| `healthz-kserve-20261108.json` | `GET /healthz` of the KServe model endpoint (`model_source: /mnt/models`) | Sun 03:07 UTC |
| `healthz-route-20261108.json` | the same model on the fallback Deployment (`model_source: image`) | Sun 03:07 UTC |
| `whatif-calls-kserve-20261108.txt` | a What-if call on the Vultr VM and the matching `POST /predict 200` in the KServe pod log, same minute | Sun 03:08 UTC |
| `whatif-ml.png` | the What-if calculator with "Height unknown" ticked | Sat 02:22 EET (older UI) |
| `../kserve/`, `../pipelines/`, `../calc/evidence/`, `../llm/` | manifests, pipeline sources, the cold-run log | Sat 7 Nov |

## The platform
**Red Hat OpenShift AI 3.5.2 on the Red Hat Developer Sandbox**, cluster `rm2` (`api.rm2.thpm.p1.openshiftapps.com`),
namespace `danialheidari619-dev`. Quota: 3 CPU / 14 GiB for builds, 3 CPU / 30 GiB for deployments, 80 GiB storage,
**no GPU** (confirmed by Red Hat). Free; the sandbox lasts 30 days from 6 Nov.

## What runs on it (`oc-status-20261108.txt`)
| Component | What it does | State now | Evidence |
|---|---|---|---|
| **KServe `InferenceService p1546-risk`** | serves the P.1546 risk model: three LightGBM quantile regressors (q05 / q50 / q95) of ITU-R P.1546-6 field strength. Custom ServingRuntime = our FastAPI `risk_api.py` (`/healthz`, `/predict`, `/assess`), RawDeployment | **Ready** | `healthz-kserve-20261108.json`, `../kserve/inferenceservice.yaml`, `../kserve/servingruntime.yaml` |
| Model storage | model files versioned in S3 (MinIO, bucket `models`, `p1546-risk/v1`) through the OpenShift AI data connection `models-connection`, staged to PVC `p1546-models`, mounted at `/mnt/models` | running | `../kserve/stage-model-job.yaml`, `../kserve/model-pvc.yaml` |
| Fallback Deployment `p1546-risk` | the same model baked into the image at build time | running | `healthz-route-20261108.json` |
| **Data Science Pipelines** (DSPA `dspa`, KFP v2, artefacts in our MinIO) | pipeline server for the three pipelines below | 6 deployments Ready | `oc-status-20261108.txt`, `../pipelines/dspa.yaml` |
| Pipeline **`p1546-risk-train`** | exact P.1546-6 samples → train q05/q50/q95 → evaluate → safety gate → register in S3 | run `10cde0f0…` SUCCEEDED Sat | `../pipelines/train_pipeline.py`, `../pipelines/README.md` |
| Pipeline **`sinceai-calc-lane`** | fetches the public ITU IFIC, runs our screening engines unchanged (space pfd vs RR Art. 21, terrestrial P.1546 vs ECC T/R 25-08), compares every notice's outcome and reason code with `results/` | run `6f2182e7…` SUCCEEDED Sat, 380 s warm | `../pipelines/calc_pipeline.py`, `../pipelines/README.md` |
| Pipeline `ific-time-machine` | one pod per space IFIC 3062–3083 | run `df180855…` started Sat 23:00; outcome not recorded here | `../pipelines/timeline_pipeline.py` |
| **KServe `InferenceService granite`** | Granite 3.3 2B Instruct (Apache-2.0) on the platform's vLLM CPU runtime, OCI ModelCar, token auth | **Ready** | `../llm/granite.yaml` |
| Job `granite-batch-explain` | Granite writes the explanation for every over-limit finding, in-cluster | Complete (4 h 59 min on CPU) | `oc-status-20261108.txt`, `../llm/batch_explain.py` |

## The model (`healthz-kserve-20261108.json`)
Trained inside an OpenShift build on **96,000** samples labelled by the exact P.1546-6 code, tested on 24,000:
held-out **MAE 0.711 dB** with all inputs; **6.165 dB** when each of effective height, receiver height and sea share is
hidden half the time; **0.285 %** of real trigger exceedances missed with all inputs. Both endpoints report the same
metrics.

## It is called by the live product (`whatif-calls-kserve-20261108.txt`)
The What-if calculator on the Vultr VM, with the transmitter's antenna height unknown, returns an ML estimate
(interval 10.7 / 25.3 / 52.1 dB(µV/m), 66 % chance over the 20 dB(µV/m) trigger). In the same minute the KServe
predictor pod logs `POST /predict 200`. The VM's `RISK_API_URL` points at the KServe route, and the client code
(`risk/assess.py`, `_quantiles`) has no silent local fallback on this path.

**What the model is not used for:** it never sets an outcome, a margin or a rank. It only gives a review-priority
estimate when an input is missing, and the result says so ("not a calculation result; outcome stays
insufficient_data"). Every verdict comes from the physics engines.

## Honest limits
- **The cold calculation Job (`../calc/evidence/lane-run1.json`) reports `ok: false`:** its outcome counts equal
  `results/` exactly (space 3074: 12 / 36 / 22 / 126; terrestrial 3076: 8 / 1 / 83 / 22), but the file bytes differ
  because the pod ran without the 2.4 GB terrain cache (margins differ in the 4th decimal). The later pipeline run
  compares outcome and reason code per notice and SUCCEEDED. The `sinceai-calc-lane` Job object in the cluster now
  shows `Failed (BackoffLimitExceeded)` from a later retry; it is not the evidence run.
- Granite is **not** the live explanation model: about 3 minutes per finding on sandbox CPU. Featherless stays live.
- No GPU in the sandbox; the sandbox scales idle workloads to zero after ~12 h. Both model endpoints answered at
  03:07 UTC Sun; check `/healthz` again before judging.

## Why OpenShift AI
Traficom would run this on-prem; everything here is Kubernetes manifests, a KServe InferenceService, KFP pipelines
and an open-weight model, so it moves to an on-prem OpenShift without code changes.
