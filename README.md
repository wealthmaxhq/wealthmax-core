# WealthMax Core

WealthMax Core is the full-stack foundation for WealthMax Pro. It combines precise financial calculations with an authenticated planning API and a React web interface.

## Architecture

- **Financial SDK (`lib/`, `test/`, `bin/`)** — a Dart package for money, percentage, loan, investment, and decision calculations, plus the decision-report bridge.
- **Backend API (`backend/`)** — an Express and TypeScript service for authentication, account management, goals, reports, and financial decision analysis.
- **Frontend (`frontend/`)** — a React, TypeScript, and Vite application for authenticated financial planning workflows.

The Node projects are managed as a pnpm workspace with a root `pnpm-lock.yaml`.

## Local development

Requirements: Dart 3.12.2, Node.js 22, and pnpm 11.

Install dependencies from the repository root:

```sh
dart pub get
pnpm install --frozen-lockfile
```

Start the backend and frontend in separate terminals:

```sh
pnpm --filter wealth-planner-backend run dev
pnpm --filter wealth-planner-frontend run dev
```

The backend requires a `JWT_SECRET` of at least 32 characters. Keep production secrets outside the repository.

## Continuous integration

The full-stack CI workflow runs for every pull request and push to `main`. It checks Dart formatting, analysis, and tests; backend TypeScript, build, and Jest tests; and frontend TypeScript and production build. Superseded runs on the same branch are cancelled automatically.

Run the same checks locally from the repository root:

```sh
dart format --output=none --set-exit-if-changed lib test bin
dart analyze --fatal-infos
dart test

pnpm install --frozen-lockfile
pnpm --filter wealth-planner-backend run typecheck
pnpm --filter wealth-planner-backend run build
pnpm --filter wealth-planner-backend test
pnpm --filter wealth-planner-frontend run typecheck
pnpm --filter wealth-planner-frontend run build
```

Use `NODE_ENV=test` and a test-only `JWT_SECRET` when running backend tests. CI never uses production secrets and does not deploy.
