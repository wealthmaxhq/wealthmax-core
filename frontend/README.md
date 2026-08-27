# WealthMax frontend

The React and TypeScript web application provides authenticated dashboards,
goals, decision reports, financial-health tracking, portfolio management, and
account security controls.

Install workspace dependencies from the repository root, then start the app:

```sh
pnpm install --frozen-lockfile
pnpm --filter wealth-planner-frontend run dev
```

The development server proxies `/api` to the backend on port 3000. Set
`VITE_API_BASE_URL` when the API is hosted elsewhere.

## Validation

```sh
pnpm --filter wealth-planner-frontend run typecheck
pnpm --filter wealth-planner-frontend test
pnpm --filter wealth-planner-frontend run build
```

Vitest uses one bounded thread for deterministic jsdom interaction tests. This
avoids process-spawn failures on constrained hosts and timing contention between
the longer goal, portfolio, and dashboard workflows. Keep new tests within the
standard `src/**/*.test.ts` or `src/**/*.test.tsx` discovery patterns.
