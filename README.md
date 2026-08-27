# WealthMax Core

WealthMax Core is the full-stack foundation for WealthMax Pro. It combines precise financial calculations with an authenticated planning API and a React web interface.

## Architecture

- **Financial SDK (`lib/`, `test/`, `bin/`)** — a Dart package for money, percentage, loan, investment, and decision calculations, plus the decision-report bridge.
- **Backend API (`backend/`)** — an Express and TypeScript service for authentication, account management, goals, reports, and financial decision analysis.
- **Frontend (`frontend/`)** — a React, TypeScript, and Vite application for authenticated financial planning workflows.

The web interface includes an accessible responsive navigation menu so every
planning workspace and account action remains reachable on phone and tablet
layouts.

The Node projects are managed as a pnpm workspace with a root `pnpm-lock.yaml`.

The authenticated dashboard consolidates goal progress, decision reports, and
goal-based monthly savings and allocation guidance. Recommendations are derived
on demand from the current user's goals and are not stored. Dashboard services
load independently, so available planning data remains visible during a partial
service outage and failed requests can be retried in place.
The dashboard also ranks up to three planning priorities from successfully
loaded workspace data and the latest financial-health findings. Unavailable
services never produce speculative actions.

The portfolio workspace stores assets and liabilities and calculates net worth
separately for each currency, avoiding misleading cross-currency totals.

Financial-health calculations are saved as private account snapshots. The
workspace restores the latest result, charts score history, and the dashboard
surfaces the latest check-in so progress remains visible over time.

Account settings provide a versioned JSON data export covering the user's
profile, goals, decision reports, portfolio records, and financial-health
history without credentials or internal session metadata.

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
Set `WEALTHMAX_DB_PATH` to a persistent-volume location for production data.
Use `/health` for process liveness and `/ready` for traffic readiness; readiness
includes a database query.

## Continuous integration

The full-stack CI workflow runs for every pull request and push to `main`. Dart validation is split into parallel formatting/analysis, core financial tests, and calculation-heavy decision/reporting tests. Backend validation is also parallelized into typecheck/build, fast API tests, and Dart-bridge integration tests, so ordinary API failures return without waiting for the calculation engine. The tier manifest is checked in CI so every backend test belongs to exactly one tier. Frontend validation runs independently, and superseded runs on the same branch are cancelled automatically.

Run the same checks locally from the repository root:

```sh
dart format --output=none --set-exit-if-changed lib test bin
dart analyze --fatal-infos
dart test

# Faster focused Dart tiers used by CI
dart test test/calculation test/currency test/health test/investment test/loan test/money test/percentage test/rounding
dart test test/decision test/reporting

pnpm install --frozen-lockfile
pnpm --filter wealth-planner-backend run typecheck
pnpm --filter wealth-planner-backend run build
pnpm --filter wealth-planner-backend test
pnpm --filter wealth-planner-backend run test:fast
pnpm --filter wealth-planner-backend run test:dart-bridge
pnpm --filter wealth-planner-frontend run typecheck
pnpm --filter wealth-planner-frontend test
pnpm --filter wealth-planner-frontend run build
```

Frontend behavior tests cover authentication restoration, financial-health
calculation and history, account security, authentication forms, dashboard aggregation,
decision-report management, goal management, and the portfolio workspace's
history, CRUD, and export flows.

Use `NODE_ENV=test` and a test-only `JWT_SECRET` when running backend tests. CI never uses production secrets and does not deploy.

## Releases

All package versions and the changelog are checked for alignment in CI. To
publish a release, create a semantic version tag such as `v0.1.0` on a commit
already contained in `main`, then push the tag. The release workflow reruns the
complete Dart, backend, and frontend validation suites before publishing:

- a static frontend bundle;
- a compiled backend bundle with its production package manifest;
- the Dart financial SDK source package; and
- SHA-256 checksums for every archive.

The workflow never publishes an untested artifact and rejects tags that do not
match the repository package versions or changelog.
