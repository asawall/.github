# kingdom-gpt-hosting (ARCHIVED)

> **Status:** GitHub-archived (read-only). This document is hosted in the `.github` repo because the source repository can no longer accept pushes.

## What it was

Kingdom SaaS Master-Setup — a production-ready, multi-tenant SaaS platform draft with AI/GPT integration, team management, payment processing, and Grafana/Prometheus/Logstash monitoring. Built on Docker Compose with Ansible roles for Nextcloud, Ollama, and Ollama-Models.

## Repository content (snapshot at archive time)

```
ansible/                        # Ansible inventory + roles (nextcloud, ollama, ollama-models)
api-integrations/digistore24/   # Digistore24 webhook handler (Python)
config/grafana/                 # dashboards.yml, datasources.yml
config/prometheus/              # prometheus.yml
config/logstash/                # pipeline.conf
dashboard-ui/                   # legacy dashboard (Next.js)
database/init/                  # SQL seed data
docker-compose.yml              # full stack
frontend/dashboard/             # alternate dashboard with own Dockerfile
docs/                           # INSTALLATION.md, SUPPORT.md, plus pre-generated DE/EN docs
.env.example, LICENSE, README.md
```

## Tech stack

Docker Compose, Ansible, Nextcloud, Ollama (local LLM serving), Prometheus, Grafana, Logstash, Next.js dashboard, PostgreSQL, Digistore24 webhook integration.

## Why archived

Superseded by tenant-specific repositories. Functions migrated to:
- **Kingdom Hosting infrastructure** — operational hosting moved to dedicated tenant tooling under `kingdom-ai`
- **Digistore24 integration** — moved to `automation-hub` n8n workflows (`*_stripe_purchase.json` patterns)
- **Monitoring** — superseded by `infra-monitoring` for daily watchdog and dedicated Grafana dashboards on KingdomAI-Server

## What to read for current equivalents

| Old (this repo) | New |
|---|---|
| `docker-compose.yml` (multi-service stack) | `kingdom-ai` repo, `kingdom-hosting` server config |
| `api-integrations/digistore24/` | `automation-hub/workflows/_shared/intake_hub.json` + per-tenant Stripe flows |
| `config/grafana/` + `config/prometheus/` | KingdomAI-Server `/opt/monitoring/` (separate config repo planned) |
| `dashboard-ui/` (Next.js) | replaced by per-product UIs (rissfest, vertriebsarchitekt, etc.) |
| `ansible/roles/ollama*/` | KingdomAI-Server provisioning (private infra repo) |

## Recovery

`git clone https://github.com/asawall/kingdom-gpt-hosting.git` still works (read-only). The repo is preserved verbatim — no force-push or history rewrite has occurred. Unarchive via repo settings if active development resumes.
