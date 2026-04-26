# nextjs-boilerplate (ARCHIVED)

> **Status:** GitHub-archived (read-only).

## What it was

A vanilla Next.js boilerplate generated via `create-next-app`, used as a starting point for new product UIs in the early days of the SaPe-Holding portfolio.

## Repository content

Stock `create-next-app` output:

```
app/                # App Router (favicon, globals.css, layout.tsx, page.tsx)
public/
package.json        # name="nextjs", scripts: dev/build/start/lint, next dev --turbopack
tsconfig.json
next.config.ts
README.md           # standard create-next-app readme
.gitignore
```

## Tech stack

Next.js 15+ App Router, TypeScript, Turbopack dev server, no custom components or business logic added.

## Why archived

Boilerplates moved into private templating infrastructure. Active Next.js projects (rissfest, vertriebsarchitekt, easyArchitekt, sape-control-plane) bootstrap directly via `pnpm create next-app` against current upstream rather than against this stale fork.

## Recovery

Read-only clone available. Recommend running `pnpm create next-app@latest` for new projects rather than reviving this fork — Next.js, Turbopack, and the App Router have evolved substantially since archival.
