# asawall — Repository Documentation Overview

Master inventory of every repository under the `asawall` GitHub account, with the location of its standardised auto-generated documentation.

## Documentation standard

Every active repository carries a 12-section senior-level documentation stack:

1. Project Overview
2. System Architecture
3. Tech Stack
4. Setup & Installation
5. Code Structure
6. API Documentation
7. Data Model
8. Workflows & Logic
9. Deployment
10. Testing
11. Error Analysis & Debugging
12. Open Items / Risks

Each repository ships:

- `README.md` — primary 12-section overview (English)
- `docs/README.de.md` — parallel German overview
- `docs/technical.md` — English technical supplement
- `docs/technical.de.md` — German technical supplement

These four files live on the branch **`docs/auto-generated`** in each repository. Merge into `main` after review.

## Active repositories — full documentation pushed

12 active repositories carry the full 4-file documentation set on the `docs/auto-generated` branch.

| Repository | Stack | Branch |
|---|---|---|
| [botmatiq](https://github.com/asawall/botmatiq) | C# / .NET 8 | `docs/auto-generated` |
| [kingdom-ai](https://github.com/asawall/kingdom-ai) | Python | `docs/auto-generated` |
| [easyarchitekt](https://github.com/asawall/easyarchitekt) | TypeScript | `docs/auto-generated` |
| [wegmark](https://github.com/asawall/wegmark) | TypeScript | `docs/auto-generated` |
| [frag-einen-v2](https://github.com/asawall/frag-einen-v2) | Vue / Laravel / Nuxt | `docs/auto-generated` |
| [vertriebsarchitekt](https://github.com/asawall/vertriebsarchitekt) | HTML + Next.js | `docs/auto-generated` |
| [rissfest](https://github.com/asawall/rissfest) | TypeScript / Next.js 15 | `docs/auto-generated` |
| [piratenquest](https://github.com/asawall/piratenquest) | JS (React + Express, game) | `docs/auto-generated` |
| [sape-control-plane](https://github.com/asawall/sape-control-plane) | TypeScript / Next.js 14 + Infisical | `docs/auto-generated` |
| [automation-hub](https://github.com/asawall/automation-hub) | Shell / n8n GitOps | `docs/auto-generated` |
| [infra-monitoring](https://github.com/asawall/infra-monitoring) | Python | `docs/auto-generated` |
| [.github](https://github.com/asawall/.github) | YAML (this repo) | `docs/auto-generated` |

## Archived repositories — documentation hosted here

7 repositories are GitHub-archived (read-only, no further commits possible). Their documentation lives in this `.github` repo under [`docs/archived-repos/`](archived-repos/):

| Repository | Why archived | Doc |
|---|---|---|
| [ai-dashboard](https://github.com/asawall/ai-dashboard) | Naming placeholder, never populated | [archived-repos/ai-dashboard.md](archived-repos/ai-dashboard.md) |
| [claude-gpt](https://github.com/asawall/claude-gpt) | Early installer prototype, superseded | [archived-repos/claude-gpt.md](archived-repos/claude-gpt.md) |
| [gpt-dashboard](https://github.com/asawall/gpt-dashboard) | Empty repository | [archived-repos/gpt-dashboard.md](archived-repos/gpt-dashboard.md) |
| [kingdom-gpt-hosting](https://github.com/asawall/kingdom-gpt-hosting) | Superseded by tenant-specific repos | [archived-repos/kingdom-gpt-hosting.md](archived-repos/kingdom-gpt-hosting.md) |
| [kingdom-saas](https://github.com/asawall/kingdom-saas) | Naming placeholder, never populated | [archived-repos/kingdom-saas.md](archived-repos/kingdom-saas.md) |
| [mygpt-dashboard](https://github.com/asawall/mygpt-dashboard) | Empty repository | [archived-repos/mygpt-dashboard.md](archived-repos/mygpt-dashboard.md) |
| [nextjs-boilerplate](https://github.com/asawall/nextjs-boilerplate) | Stock create-next-app fork, replaced by direct upstream | [archived-repos/nextjs-boilerplate.md](archived-repos/nextjs-boilerplate.md) |

## Total count

**19 repositories** under `asawall`, of which:

- **12 active** — each carries full 4-file standardised documentation on `docs/auto-generated`.
- **7 archived** — each is documented as a single Markdown file in this repo's `docs/archived-repos/` directory.

## How to update documentation

For active repositories:

```bash
git checkout docs/auto-generated
# edit README.md, docs/README.de.md, docs/technical.md, docs/technical.de.md
git add README.md docs/
git commit -m "docs: <change description>"
git push origin docs/auto-generated
```

To merge into `main`:

```bash
git checkout main
git merge --no-ff docs/auto-generated
git push origin main
```

For archived repositories, edit the corresponding file under `docs/archived-repos/` in this `.github` repo.
