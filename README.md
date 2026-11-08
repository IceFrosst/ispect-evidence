# Ispect: partner-award evidence (evidence only)

Team **As Always** (Since AI Hackathon 2026, Traficom challenge). **Ispect** screens the ITU's public BR IFIC releases for
foreign satellite and terrestrial filings that could affect radio use in Finland; the expert decides. This repository holds
**evidence only** for three partner awards: notes, screenshots, command output and deployment manifests captured from the
running systems. It contains **no engine source code, no datasets and no challenge material**; the project code is
submitted separately as the source zip.

| Award | Folder | Start with |
|---|---|---|
| Red Hat OpenShift AI Technology Award | [`red-hat-openshift-ai/`](red-hat-openshift-ai/) | `evidence/note.md` (what runs on OpenShift AI, how it is used, honest limits) |
| FIWARE Open Innovation Award | [`fiware/`](fiware/) | `evidence/vm/current/note.md` (Orion-LD / NGSI-LD on the demo VM) |
| MLH Best Use of Vultr | [`vultr/`](vultr/) | `evidence/note.md` (one Vultr VM runs the whole product) |

All captures are real outputs from the live systems (timestamps inside the files). Where something is partial or
unverified the notes say so. Files are plain text, JSON, YAML and PNG; secrets, personal data and internal addresses were
masked before publishing and every text file was scanned.
