# LangOps Stack 🚀

> Reference implementation of a production-grade LLM observability platform on GKE —
> LiteLLM gateway + Langfuse tracing + Prometheus/Grafana metrics, provisioned with
> Terraform and deployed via Helm + ArgoCD.

![GKE](https://img.shields.io/badge/GKE-Autopilot-blue?logo=googlecloud)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-orange?logo=argo)
![LiteLLM](https://img.shields.io/badge/LLM_Gateway-LiteLLM-green)
![Langfuse](https://img.shields.io/badge/Tracing-Langfuse-purple)
![Prometheus](https://img.shields.io/badge/Metrics-Prometheus-red?logo=prometheus)
![Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet?logo=terraform)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## What is this?

LangOps Stack is a fully deployed, open-source reference platform for running LLM
workloads in production on GCP. Every component in this repo has been deployed,
debugged, and validated on a live GKE cluster — not just written as a guide.

The stack routes LLM requests through a unified gateway, traces every prompt
end-to-end with OpenTelemetry, and surfaces token usage, latency, and error rates
in Grafana — all on GKE Autopilot with zero node management.

**What's running in the cluster:**

- **LiteLLM v1.80.5** — unified LLM gateway with Prometheus `/metrics` endpoint
- **Langfuse v3** — end-to-end prompt tracing via OpenTelemetry (HTTP + Basic auth)
- **Prometheus + Grafana** — token usage, latency, and error rate dashboards scraped from LiteLLM
- **FastAPI RAG app** — sample app with OTel instrumentation
- **Terraform** — VPC, GKE Autopilot, CloudSQL, Artifact Registry
- **ArgoCD** — GitOps deployment with multi-source Helm applications
- **Google Cloud Build** — container image builds without local Docker

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         GKE Autopilot                            │
│                                                                  │
│  ┌──────────────┐      ┌───────────────┐    ┌────────────────┐   │
│  │  FastAPI     │─────▶│   LiteLLM     │───▶│  OpenRouter    │   │
│  │  RAG App     │      │   Gateway     │    │  (free models) │   │
│  │  :8080       │      │   :4000       │    ├────────────────┤   │
│  └──────┬───────┘      └──────┬────────┘    │  Gemini        │   │
│         │                    │              ├────────────────┤   │
│         │ OTel traces        │ /metrics     │  Anthropic     │   │
│         │ (HTTP Basic auth)  │ scrape/30s   └────────────────┘   │
│         ▼                    ▼                                   │
│  ┌────────────┐     ┌─────────────────┐                          │
│  │  Langfuse  │     │   Prometheus    │──▶  Grafana :3001        │
│  │  :3000     │     │   :9090         │     token cost           │
│  │  ClickHse  │     └─────────────────┘     latency p50/p95      │
│  │  Redis     │                             error rate/model     │
│  │  MinIO     │                                                  │
│  └────────────┘                                                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │               CloudSQL PostgreSQL 15                     │    │
│  │         langfuse DB  │  litellm DB                       │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘

IaC:    Terraform → VPC, GKE, CloudSQL, Artifact Registry
GitOps: ArgoCD watches GitHub → renders Helm charts → deploys to GKE
CI:     Cloud Build → builds RAG app image → pushes to Artifact Registry
```

---

## Stack

| Component | Tool | Version | Purpose |
|---|---|---|---|
| Infrastructure | Terraform | >= 1.9 | VPC, GKE Autopilot, CloudSQL, Artifact Registry |
| GitOps | ArgoCD | stable | Helm chart deployment and sync |
| LLM Gateway | LiteLLM | v1.80.5 (Helm chart 0.1.820) | Multi-model routing + Prometheus `/metrics` (OSS, no enterprise license needed) |
| Tracing | Langfuse | 3.179.1 | Prompt traces via OpenTelemetry |
| Metrics | kube-prometheus-stack | 65.8.1 | Prometheus + Grafana |
| Analytics DB | ClickHouse | Bitnami subchart | Langfuse analytics backend |
| Cache | Redis (Valkey 8.0) | Bitnami subchart | Langfuse session cache + queue |
| Blob Storage | MinIO | Bitnami subchart | Langfuse trace event buffering |
| Sample App | FastAPI | Python 3.11 | OTel instrumented LLM gateway app |
| CI | Google Cloud Build | — | Container image builds (no local Docker needed) |
| Registry | Artifact Registry | — | Container image storage |

---

## Models Supported

| Model Name | Provider | Cost |
|---|---|---|
| `free` | OpenRouter (auto-selects best free model) | Free |
| `gemini-pro` | Google Gemini 2.0 Flash | GCP pricing |
| `claude-sonnet` | Anthropic Claude 3.5 Sonnet | Paid |
| `llama` | OpenRouter (Llama 3.3 70B) | Free |
| `deepseek` | OpenRouter (DeepSeek R1) | Free |
| `gemma` | OpenRouter (Gemma 3 12B) | Free |

> **Note:** OpenRouter free model availability changes frequently.
> Check [openrouter.ai/models](https://openrouter.ai/models?q=free) for current options.

---

## Estimated Cost (GCP)

| Resource | Type | Estimated Cost/month |
|---|---|---|
| GKE Autopilot | ~3-4 nodes auto-provisioned | ~$100–150 |
| CloudSQL | db-g1-small, 20GB SSD | ~$25 |
| Artifact Registry | < 1GB storage | ~$1 |
| Cloud Build | ~10 builds/month | Free tier |
| **Total** | | **~$125–175/month** |

> ⚠️ Run `terraform destroy` when not in use. GKE Autopilot charges per pod
> resource request. Cost scales down when idle.

---

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI authenticated (`gcloud auth login`)
- `terraform` >= 1.9
- `kubectl`
- `helm` >= 3.0
- `argocd` CLI
- API keys:
  - [OpenRouter](https://openrouter.ai/settings/keys) — free account, free tier models
  - [Gemini](https://aistudio.google.com/apikeys) — free tier (requires billing-enabled project)
  - [Anthropic](https://console.anthropic.com/account/keys) — paid

---

## Deploy

> ⚠️ **Follow steps in order.** Several steps depend on outputs from previous steps.
> Langfuse API keys (`pk-lf-...` and `sk-lf-...`) are only available after Langfuse
> is running — create LiteLLM and RAG app secrets with placeholders first, then
> update them in Step 6 once Langfuse is up.

---

### Step 1 — Provision Infrastructure

```bash
cd infra/terraform

# Authenticate Terraform with GCP
gcloud auth application-default login

# Set variables — passwords are auto-generated and stored in GCP Secret Manager
export TF_VAR_project_id="langops-stack"

terraform init
terraform apply

# Terraform generates DB passwords and stores them in Secret Manager automatically
# No need to save them manually — retrieve with:
# gcloud secrets versions access latest --secret="langops-langfuse-db-password" --project=langops-stack
```

Note the outputs after apply — you will need `db_private_ip`:

```bash
terraform output
# db_private_ip = "10.x.x.x"   ← used in Langfuse and LiteLLM values.yaml
```

Connect kubectl to the new cluster:

```bash
gcloud container clusters get-credentials langops-cluster \
  --region us-central1 \
  --project langops-stack

kubectl cluster-info   # verify
```

---

### Step 2 — Create Initial Secrets

> ⚠️ Langfuse and LiteLLM must start before you can get the Langfuse API keys.
> In this step, create all secrets with **placeholder values** for Langfuse keys.
> You will update them with real values in Step 6 after Langfuse is running.

**Langfuse secrets:**

```bash
kubectl create namespace langfuse

# App session keys — randomly generated, never need to know these values
kubectl create secret generic langfuse-app-secrets \
  --namespace langfuse \
  --from-literal=salt=$(openssl rand -hex 16) \
  --from-literal=nextauth-secret=$(openssl rand -hex 32) \
  --from-literal=encryption-key=$(openssl rand -hex 32) \
  --from-literal=clickhouse-password=$(openssl rand -hex 16) \
  --from-literal=minio-access-key=minio \
  --from-literal=minio-secret-key=$(openssl rand -hex 16) \
  --from-literal=redis-password=$(openssl rand -hex 16)

# DB password — retrieved from GCP Secret Manager (stored there by Terraform)
kubectl create secret generic langfuse-db-secret \
  --namespace langfuse \
  --from-literal=password=$(gcloud secrets versions access latest \
    --secret="langops-langfuse-db-password" \
    --project=langops-stack)
```

**LiteLLM secrets:**

> ⚠️ `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY` are placeholders here.
> You will update them in Step 6 once Langfuse is running and you have real keys.
> See Step 6 for how to get the actual `pk-lf-...` and `sk-lf-...` values.

```bash
kubectl create namespace litellm

# Master key — used to authenticate requests to LiteLLM proxy
# Must contain both masterkey and PROXY_MASTER_KEY set to the same value
MASTER_KEY=$(openssl rand -hex 16)
kubectl create secret generic litellm-masterkey \
  --namespace litellm \
  --from-literal=masterkey=$MASTER_KEY \
  --from-literal=PROXY_MASTER_KEY=$MASTER_KEY

echo "SAVE THIS LITELLM MASTER KEY: $MASTER_KEY"
# You will need this in Step 7 when creating rag-app-secrets

# LLM provider API keys — get from each provider's console:
#   OpenRouter: https://openrouter.ai/settings/keys (free)
#   Gemini:     https://aistudio.google.com/apikeys (free tier)
#   Anthropic:  https://console.anthropic.com/account/keys (paid)
# Langfuse keys are placeholders — update after Step 6
kubectl create secret generic litellm-env-secrets \
  --namespace litellm \
  --from-literal=GEMINI_API_KEY=<your-gemini-key> \
  --from-literal=ANTHROPIC_API_KEY=<your-anthropic-key> \
  --from-literal=OPENROUTER_API_KEY=<your-openrouter-key> \
  --from-literal=LANGFUSE_HOST=http://langfuse-web.langfuse.svc.cluster.local:3000 \
  --from-literal=LANGFUSE_PUBLIC_KEY=placeholder-update-after-step-6 \
  --from-literal=LANGFUSE_SECRET_KEY=placeholder-update-after-step-6

# DB credentials — retrieved from GCP Secret Manager (stored there by Terraform)
kubectl create secret generic litellm-db-secret \
  --namespace litellm \
  --from-literal=username=litellm \
  --from-literal=password=$(gcloud secrets versions access latest \
    --secret="langops-litellm-db-password" \
    --project=langops-stack)
```

**Monitoring secrets:**

```bash
kubectl create namespace monitoring

kubectl create secret generic grafana-admin-secret \
  --namespace monitoring \
  --from-literal=admin-password=$(openssl rand -base64 16)
```

**RAG app namespace** (secrets created later in Step 7):

```bash
kubectl create namespace rag-app
```

---

### Step 3 — Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready (2-3 minutes)
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# Get initial admin password — save this
argocd admin initial-password -n argocd

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

Open `https://localhost:8080` → accept self-signed cert → login with `admin`.

Login via CLI:

```bash
argocd login localhost:8080 \
  --username admin \
  --password <password-from-above> \
  --insecure
```

---

### Step 4 — Deploy the Stack (ArgoCD Sync)

```bash
# Bootstrap the app-of-apps — this one command starts everything
kubectl apply -f argocd/apps/root-app.yaml
```

ArgoCD discovers and deploys all child apps: `langfuse`, `litellm`, `monitoring`.

> ⚠️ The `rag-app` is intentionally left out for now — it needs the Langfuse API
> keys and a built image, both of which come in later steps.

Watch sync progress:

```bash
argocd app list

# Watch pods come up (GKE Autopilot provisions nodes — takes 3-5 minutes)
kubectl get pods -n langfuse -w
kubectl get pods -n litellm -w
kubectl get pods -n monitoring -w
```

Wait until all pods show `Running` before proceeding.

---

### Step 5 — Verify Core Services

```bash
# Port-forward all services
kubectl port-forward svc/langfuse-web -n langfuse 3000:3000 &
kubectl port-forward svc/litellm -n litellm 4000:4000 &
kubectl port-forward svc/monitoring-grafana -n monitoring 3001:80 &
```

Verify each:

| Service | URL | Expected |
|---|---|---|
| Langfuse | http://localhost:3000 | Login/signup page |
| LiteLLM | http://localhost:4000/models | JSON list of models |
| Grafana | http://localhost:3001 | Login page |

---

### Step 6 — Get Langfuse API Keys and Update Secrets

This is the step that was missing before. Langfuse must be running before you can
get the API keys. Now that it is, create your account and generate keys.

**6.1 — Create your Langfuse account and project:**

```bash
kubectl port-forward svc/langfuse-web -n langfuse 3000:3000 &
```

Open `http://localhost:3000`:

1. Click **Sign Up** — create your admin account (first signup = admin)
2. Create a new **Project** — e.g. `langops-dev`
3. Go to **Settings → API Keys → Create new API key**
4. Copy both keys:
   - **Public Key** — starts with `pk-lf-...`
   - **Secret Key** — starts with `sk-lf-...`

> ⚠️ `LANGFUSE_PUBLIC_KEY` = `pk-lf-...` and `LANGFUSE_SECRET_KEY` = `sk-lf-...`
> Swapping them causes silent 401 errors on OTel trace export with no clear error
> message in logs.

**6.2 — Update LiteLLM secret with real Langfuse keys:**

```bash
# Get your current OpenRouter/Gemini/Anthropic keys from existing secret
OPENROUTER_KEY=$(kubectl get secret litellm-env-secrets -n litellm \
  -o jsonpath='{.data.OPENROUTER_API_KEY}' | base64 -d)
GEMINI_KEY=$(kubectl get secret litellm-env-secrets -n litellm \
  -o jsonpath='{.data.GEMINI_API_KEY}' | base64 -d)
ANTHROPIC_KEY=$(kubectl get secret litellm-env-secrets -n litellm \
  -o jsonpath='{.data.ANTHROPIC_API_KEY}' | base64 -d)

# Recreate secret with real Langfuse keys
kubectl create secret generic litellm-env-secrets \
  --namespace litellm \
  --from-literal=GEMINI_API_KEY=$GEMINI_KEY \
  --from-literal=ANTHROPIC_API_KEY=$ANTHROPIC_KEY \
  --from-literal=OPENROUTER_API_KEY=$OPENROUTER_KEY \
  --from-literal=LANGFUSE_HOST=http://langfuse-web.langfuse.svc.cluster.local:3000 \
  --from-literal=LANGFUSE_PUBLIC_KEY=pk-lf-... \
  --from-literal=LANGFUSE_SECRET_KEY=sk-lf-... \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart LiteLLM to pick up new keys
kubectl rollout restart deployment/litellm -n litellm
```

---

### Step 7 — Build and Deploy the RAG App

Now that Langfuse is running and you have real API keys, build the RAG app image
and create its secrets.

**7.1 — Build and push the image with Cloud Build:**

```bash
# Run from repo root — no local Docker needed
gcloud builds submit \
  --config cloudbuild.yaml \
  --project=langops-stack \
  .
```

Cloud Build builds and pushes directly to Artifact Registry. GKE pulls from
Artifact Registry automatically — same GCP project means no `imagePullSecrets` needed.

**7.2 — Create RAG app secrets:**

```bash
# Get the LiteLLM masterkey generated in Step 2
MASTER_KEY=$(kubectl get secret litellm-masterkey -n litellm \
  -o jsonpath='{.data.masterkey}' | base64 -d)

# Create rag-app secret with real values
kubectl create secret generic rag-app-secrets \
  --namespace rag-app \
  --from-literal=LITELLM_API_KEY=$MASTER_KEY \
  --from-literal=LANGFUSE_PUBLIC_KEY=pk-lf-... \
  --from-literal=LANGFUSE_SECRET_KEY=sk-lf-...
```

**7.3 — Deploy RAG app via ArgoCD:**

```bash
# Add rag-app to ArgoCD
kubectl apply -f argocd/apps/rag-app.yaml

# Watch it deploy
kubectl get pods -n rag-app -w
```

---

### Step 8 — Test End to End

```bash
# Port-forward the RAG app
kubectl port-forward svc/rag-app -n rag-app 8081:8080 &

# Health check
curl http://localhost:8081/health
# {"status": "ok", "version": "1.0.0"}

# Ask a question
curl -X POST http://localhost:8081/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What is Kubernetes?", "model": "free"}'
```

After a successful request:
- ✅ JSON answer returned from the LLM
- ✅ Trace appears in **Langfuse** (`http://localhost:3000`) — prompt, response, latency, model
- ✅ Metrics scraped by **Prometheus** from LiteLLM `/metrics` every 30s
- ✅ **Grafana** dashboard refreshes with token count, latency, model breakdown

---

## API Reference

> All API calls require the RAG app to be port-forwarded first:
> ```bash
> kubectl port-forward svc/rag-app -n rag-app 8081:8080 &
> ```

### POST /ask

```bash
curl -X POST http://localhost:8081/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What is platform engineering?",
    "model": "free"
  }'
```

Response:

```json
{
  "question": "What is platform engineering?",
  "answer": "Platform engineering is...",
  "model": "free"
}
```

### GET /health

```bash
curl http://localhost:8081/health
# {"status": "ok", "version": "1.0.0"}
```

### GET /models

```bash
curl http://localhost:8081/models
```

---

## Observability

### Langfuse — Prompt Traces

```bash
kubectl port-forward svc/langfuse-web -n langfuse 3000:3000 &
```

Open `http://localhost:3000` — view prompt traces, token usage, latency, and model
per request. Every `/ask` call creates a trace with a `rag_query_<model>` span.

### Prometheus — LiteLLM Metrics

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090 &
```

Open `http://localhost:9090/targets` — verify the `litellm` job is `UP`.

Prometheus scrapes LiteLLM `/metrics` every 30 seconds. Key metrics:

```promql
# Total requests by model
litellm_requests_metric_total

# Failed requests
litellm_failed_requests_metric_total

# Input token usage
litellm_input_tokens_metric_total

# Output token usage
litellm_output_tokens_metric_total

# Request latency (p50, p95)
litellm_llm_api_latency_metric_bucket
```

### Grafana — Dashboards

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3001:80 &
```

Open `http://localhost:3001` — login with `admin` and the password from
`grafana-admin-secret`.

Import the dashboard: **Dashboards → Import → Upload JSON** →
select `charts/monitoring/dashboards/langops-litellm.json`.

Dashboard panels:
- Total requests and failure rate
- Request rate per model (time series)
- p50 / p95 latency per model
- Input and output token rate
- Cost breakdown per model

---

## GitOps Update Flow

Once bootstrapped, never run `helm upgrade` or `kubectl apply` manually:

```bash
# Deploy a new RAG app image
# 1. Build new image
gcloud builds submit --config cloudbuild.yaml --project=langops-stack .

# 2. Update image tag in values
# Edit charts/rag-app/values.yaml → image.tag: v1.1.0

# 3. Push — ArgoCD rolls out automatically
git add charts/rag-app/values.yaml
git commit -m "feat: bump rag-app to v1.1.0"
git push

# Change a config value
# Edit charts/langfuse/values.yaml → push → ArgoCD applies

# Rollback
git revert HEAD && git push
```

---

## Repository Structure

```
langops-stack/
├── rag-app/                          # FastAPI sample app
│   ├── app.py                        # OTel instrumented LLM gateway app
│   ├── Dockerfile                    # python:3.11-slim, non-root
│   ├── requirements.txt
│   └── .dockerignore
├── charts/                           # Helm values — no secrets committed
│   ├── langfuse/
│   │   └── values.yaml               # Langfuse multi-source values (PostgreSQL, ClickHouse, Redis, MinIO)
│   ├── litellm/
│   │   └── values.yaml               # LiteLLM model list, gateway config, Prometheus scrape
│   ├── monitoring/
│   │   ├── values.yaml               # kube-prometheus-stack overrides + LiteLLM scrape config
│   │   └── dashboards/
│   │       └── langops-litellm.json  # Grafana dashboard — token usage, latency, error rate
│   └── rag-app/                      # Custom Helm chart for the FastAPI app
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── hpa.yaml
│           ├── ingress.yaml
│           └── serviceaccount.yaml
├── argocd/
│   └── apps/
│       ├── root-app.yaml             # App of apps — apply this one file to bootstrap everything
│       ├── langfuse-app.yaml         # Multi-source: Langfuse Helm chart + local values
│       ├── litellm-app.yaml          # Multi-source: LiteLLM Helm chart + local values
│       ├── monitoring-app.yaml       # Multi-source: kube-prometheus-stack + local values
│       └── rag-app.yaml              # Local chart deployment
├── infra/
│   └── terraform/
│       ├── main.tf                   # VPC, GKE Autopilot, CloudSQL, Artifact Registry, Secret Manager
│       ├── variables.tf
│       ├── outputs.tf                # db_private_ip, cluster_name
│       ├── provider.tf
│       ├── backend.tf                # GCS remote state
│       └── .terraform.lock.hcl      # Provider version lock
├── cloudbuild.yaml                   # Cloud Build — builds and pushes RAG app image
└── .gitignore                        # Excludes: *.tfvars, .terraform/, __pycache__
```

---

## Known Limitations

- **Langfuse `nextauth.url` is `localhost:3000`.** Change to your actual domain
  for multi-user access.

- **OpenRouter free models change without notice.** The `free` auto-router
  occasionally selects providers that return 502. If this happens, switch to a
  specific model slug. Check [openrouter.ai/models](https://openrouter.ai/models?q=free)
  for currently available free models.

- **Gemini AI Studio free tier quota = 0 on billing-enabled GCP projects.**
  Use OpenRouter free models or Vertex AI (no API key needed on GKE) instead.

- **`image.tag: latest` causes stale deployments.** GKE caches the `latest` tag.
  Always pin `image.digest` in `charts/rag-app/values.yaml` after each Cloud Build.

- **Access via `kubectl port-forward` only.** No ingress or TLS configured.
  Suitable for development and demo use.

---

## Lessons Learned

**LiteLLM Prometheus metrics require v1.80.0+** — LiteLLM v1.57.7 (Helm chart
0.1.577) accepted the `callbacks: ["prometheus"]` config but the `PrometheusLogger`
was partially initialized, causing `AttributeError: 'PrometheusLogger' object has
no attribute 'litellm_requests_metric'` on every request. The `/metrics` endpoint
returned 200 with empty data. Prometheus showed the target as `UP` but no metrics
populated in Grafana. Prometheus metrics were enterprise-only before v1.80.0.
Fix: upgrade to Helm chart 0.1.820 (v1.80.5) where Prometheus metrics are
available in OSS. Reference: [LiteLLM v1.80.0 release notes](https://docs.litellm.ai/release_notes/v1-80-0).

**ArgoCD prune deleting auto-generated secrets** — MinIO, Redis (Valkey), and the
`langfuse-s3` secret are auto-generated by Helm on first install. ArgoCD
`prune: true` deletes them on subsequent syncs, causing CrashLoopBackOff. Fix:
pre-create stable manually-managed secrets and reference via `existingSecret`
in chart values. The `langfuse-s3` secret specifically must be recreated manually
or pinned via MinIO credentials in `langfuse-app-secrets`.

**LiteLLM masterkey must include `PROXY_MASTER_KEY`** — The chart reads the
masterkey from the secret and injects it as `PROXY_MASTER_KEY` env var. If the
secret only has `masterkey` and not `PROXY_MASTER_KEY`, the proxy starts with
`valid_token=None` and rejects all requests with 401 even when the correct key
is passed. Fix: create the secret with both keys set to the same value.

**Langfuse API keys only available after Langfuse is running** — The `pk-lf-...`
and `sk-lf-...` keys are generated inside the Langfuse UI after creating a project.
They cannot be created before the platform is deployed. Start with placeholder
values in `litellm-env-secrets` and `rag-app-secrets`, then update after first
ArgoCD sync. After updating, restart the affected deployments.

**Langfuse OTel requires HTTP exporter with Basic auth** — The Python OTel gRPC
exporter does not work with Langfuse. Must use
`opentelemetry.exporter.otlp.proto.http` with
`Authorization: Basic base64(pk-lf-...:sk-lf-...)` header on the OTEL endpoint.

**Langfuse MinIO not auto-wired** — The Langfuse chart deploys MinIO
(`s3.deploy: true`) but leaves `s3.bucket`, `s3.endpoint`, `s3.accessKeyId`,
and `s3.secretAccessKey` empty. Langfuse falls back to the AWS credential chain,
finds nothing on GCP, and logs `No AWS credentials`. Must explicitly configure
all four fields in values.yaml to point at the bundled MinIO service.

**Langfuse DB password with special characters** — Terraform-generated passwords
containing `@`, `:`, `/`, `%`, `#`, or `?` break Prisma's connection URL parser
with `P1013: invalid port number`. Prisma requires these to be percent-encoded
in the connection URL. Fix: regenerate the DB password using only alphanumeric
characters (e.g. `openssl rand -hex 20`).

**image.tag: latest causes stale pod on GKE** — GKE nodes cache the `latest` tag.
Updating the image and redeploying via ArgoCD without changing the tag leaves the
old image running. Fix: pin `image.digest` in `charts/rag-app/values.yaml` to the
SHA256 digest from Artifact Registry after each Cloud Build. ArgoCD forces a
new pod when the digest changes.

**GKE Autopilot node provisioning delay** — First pod scheduling takes 2–3
minutes while Autopilot provisions nodes. Debug pods (`kubectl run`) also fail
to schedule during this window. No action needed — wait.

**ArgoCD cannot patch kube-system services** — kube-prometheus-stack renders
headless Services in `kube-system` (for coreDNS, kubelet metrics) regardless of
`enabled: false` flags. ArgoCD sync fails with:
`GKE Warden authz [denied by managed-namespaces-limitation]: the namespace "kube-system" is managed`.
Fix: add `ignoreDifferences` for these resources in the ArgoCD Application manifest.

---

## Production Checklist

- [ ] Ingress controller with TLS (NGINX Ingress + cert-manager + Let's Encrypt)
- [ ] ExternalDNS for automatic DNS record management
- [ ] Update `nextauth.url` in Langfuse values to actual domain
- [ ] Network policies restricting cross-namespace traffic
- [ ] VPN or IAP for Grafana, ArgoCD, Langfuse
- [ ] Secret rotation strategy
- [ ] AlertManager rules for error rate, latency, token budget
- [ ] Multi-zone GKE node pools for high availability
- [ ] CloudSQL automated backups verified
- [ ] Image pinned by digest in production

---

## Contributing

PRs welcome.

**Upstream contribution in progress:** Langfuse Helm chart deploys MinIO but does
not auto-configure the S3 connection. PR in progress at
[langfuse/langfuse-k8s](https://github.com/langfuse/langfuse-k8s).

---

## License

MIT