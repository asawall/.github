# .github — Technical Supplement

> Companion document to [README.md](../README.md). Read the README first.

## Why a `.github` profile repo

GitHub special-cases the repository named exactly `.github` in any account or organisation. Three things accrue to it:

1. The `README.md` becomes the public profile page at `https://github.com/asawall`.
2. `.github/workflows/*.yml` files in this repo become reusable workflows that any other repo in the same account can `uses:`.
3. By convention, organisation-wide documentation belongs here — which is why the master inventory and archived-repo docs live under `docs/`.

## BuildKit cache layout

`docker-build-push.yml` configures cache via:

```yaml
cache-from: type=gha,scope=${{ inputs.image-name }}
cache-to:   type=gha,scope=${{ inputs.image-name }},mode=max
```

Per-image scope means a build of `kingdom-ai/backend` does not poison the cache for `botmatiq/agent`. `mode=max` exports cache for every layer (not just the final image), which dramatically improves hit rate at the cost of cache size. GitHub's 10 GB cache quota is per-repository — adjust scope strategy if quota becomes a concern.

## Central deploy key vs per-repo key

`ssh-deploy-central.yml` reads `/home/runner/.ssh/deploy_ed25519` from the runner host (bind-mounted by the runner installer). This means:

- One key, one rotation event, ten consuming repos updated automatically.
- Loss of `gha-runner-01` blocks all deploys; mitigation is a second runner with the same key bind-mounted.

`ssh-deploy.yml` accepts a per-repo `secrets.SSH_KEY` input. Use only when the central key is intentionally not authorised on a target host (rare — typically only when an external system is involved).

## Telegram notify deduplication

`notify-telegram.yml` runs unconditionally with `if: always()` patterns in callers. To deduplicate downstream (e.g. avoid double-firing on workflow_dispatch retries), include a unique identifier in the `message:` input: `SHA: ${{ github.sha }} run: ${{ github.run_id }}`.

## Versioning strategy (pending)

Currently consumers pin to `@main`. A versioned-tag strategy is planned:

- `v1` — current API surface
- `v2` — first breaking change

Tag a release on every breaking change; consumers opt in by changing the `@v1` to `@v2` after they have updated their `with:` blocks.
