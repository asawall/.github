# claude-gpt (ARCHIVED)

> **Status:** GitHub-archived (read-only).

## What it was

Early prototype installer for "Kingdom SaaS - KI-Plattform" — a multi-tenant AI-as-a-Service platform integrating OpenAI and Anthropic APIs, a Custom GPT Builder, GPU servers for local KI models, a workflow engine, and a Digistore24 integration. Distributed as a single root-required `install.sh` shell script.

## Repository content

```
README.md
readme.md           # duplicate (case-mismatched filename collision)
install.sh          # heredoc-based installer, requires root, prints colored banner
```

The `install.sh` is itself a heredoc-self-extracting script — `cat > install.sh << 'EOF'` style — meaning the version-controlled file is the installer-installer.

## Why archived

Superseded by:
- `kingdom-ai` — current backend for the AI-as-a-Service angle
- `kingdom-gpt-hosting` (also archived) — fuller SaaS-platform draft
- `automation-hub` — replaces ad-hoc Digistore24 integration with n8n workflows

The duplicate `README.md` / `readme.md` filename-collision is a known artifact of the early development period.

## Recovery

Read-only clone available. No active replacement at the same URL — refer to current product repos (kingdom-ai, frag-einen-v2, vertriebsarchitekt) for the modern stack.
