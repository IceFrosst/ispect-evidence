# Evidence: Red Hat OpenShift AI Technology Award

**Start with `note.md`** (refreshed Sun 8 Nov, 03:07 UTC: what runs, model metrics, proof that the live What-if calls KServe, honest limits). The list below is the original Friday capture.

Captured Sat 7 Nov 2026 (UTC), while the model was serving.

- `healthz.json`: `GET /healthz` of the live `p1546-risk` route (`https://p1546-risk-tls-danialheidari619-dev.apps.rm2.thpm.p1.openshiftapps.com`): the LightGBM quantile surrogate of ITU-R P.1546-6, trained inside the OpenShift build, with its test metrics.
- `oc-status.txt`: `oc get` of the build config, builds, deployment and routes in namespace `danialheidari619-dev`.
- `whatif-ml.png`: the live product's What-if calculator with "Height unknown" ticked; the "49 % chance over trigger" estimate comes from this model (the VM calls it through `RISK_API_URL`, see `docs/stack-facts.md`).
- `../evidence-p1546-risk.yaml`: the deployment manifest captured Fri 6 Nov.
