# WealthMax backend

## API contract

The server exposes its OpenAPI 3.1 contract at `GET /openapi.json`. The contract
documents all health, authentication, account, goal, and decision-report
operations, including bearer authentication, request constraints, response
codes, and CSV export content.

Start the backend and open `http://localhost:3000/openapi.json`, or import that
URL into an OpenAPI-compatible client or documentation viewer. The contract is
kept dependency-free and is covered by an integration test that checks route
coverage and unique operation identifiers.

## Production readiness and storage

`GET /health` is a lightweight process-liveness probe. `GET /ready` verifies
that SQLite can answer a query and returns HTTP 503 when the data layer is not
available; production traffic should only be routed to ready instances.

Data defaults to `data/db.sqlite` at the repository root. Set
`WEALTHMAX_DB_PATH` to an explicit persistent-volume path in production. The
parent directory is created automatically. SQLite uses foreign-key enforcement,
write-ahead logging, normal synchronous durability, and a five-second busy
timeout. Back up the database and its WAL consistently using a SQLite-aware
backup process. The server handles SIGTERM and SIGINT by stopping new requests,
waiting for active requests to finish, and closing the database connection.

## Goal recommendations API

`GET /api/v1/recommendations` turns the authenticated user's goals into a
monthly savings target and a transparent allocation heuristic. Each goal shows
its remaining amount, planning horizon in calendar months, and monthly amount.
Goals without a target date use a five-year planning horizon. The allocation is
educational guidance based on the nearest goal, not individualized investment
advice, and no other user's goals or account details are returned.

## Authentication

Email addresses are trimmed, normalized to lowercase, and validated by the
server. Passwords must contain 8 to 128 characters; optional names are limited
to 100 characters. These rules apply to direct API clients as well as the web
interface.

`JWT_SECRET` is mandatory and must contain at least 32 characters. Tokens expire
after one hour and are restricted to the WealthMax issuer and web audience.

## HTTP security

The API suppresses Express framework identification and applies restrictive
content, framing, referrer, resource, and browser-permission headers to every
response. Authenticated API responses use `Cache-Control: no-store`. JSON request
bodies are capped at 64 KiB; malformed JSON returns HTTP 400 and oversized JSON
returns HTTP 413 with stable public errors. Cross-origin browser access is not
enabled, so production web clients should use the same origin or a trusted
reverse proxy.

Public authentication endpoints reject excessive traffic with HTTP 429 and
standard `RateLimit` and `Retry-After` headers. Registration allows 10 attempts
per client per hour. Login allows 30 failed attempts per client and 10 failed
attempts per normalized account identifier per 15 minutes; successful logins do
not consume the failure quota. The default in-memory counters are appropriate
for one backend process. Configure a shared `express-rate-limit` store before
running multiple backend replicas so every instance enforces one global quota.

- `GET /api/auth/me` returns the authenticated user's public profile.
- `GET /api/auth/me/export` downloads a versioned JSON archive containing the
  current user's profile and planning records. Password hashes, session
  metadata, internal ownership columns, and other users' records are excluded.
- `PATCH /api/auth/me` updates or clears the authenticated user's display name.
- `DELETE /api/auth/me` requires the current password and the exact confirmation
  value `DELETE`, then permanently removes the account and all owned planning
  data in one transaction.
- `POST /api/auth/change-password` verifies the current password, stores a newly
  hashed replacement, revokes every existing token, and returns one replacement
  token for the current client. Deploying this migration also invalidates tokens
  issued before session versioning was introduced.
- `POST /api/auth/logout-all` immediately revokes every bearer token issued for
  the current account without changing its password or deleting planning data.

## Financial health API

`POST /api/v1/financial-health-score` calculates the authenticated user's
transparent 0–100 score and stores the result as a private progress snapshot.
Monetary inputs are decimal strings and share one declared `currency` (`INR`,
`USD`, or `EUR`). The response contains the overall rating, three component
scores, underlying ratios, and ordered actionable findings. Raw submitted input
fields are not stored. `GET /api/v1/financial-health-score/history` returns up
to 12 chronological snapshots by default; `limit` accepts 1 through 100.

## Portfolio API

`GET /api/v1/portfolio` returns the authenticated user's assets and liabilities
plus asset, liability, and net-worth totals grouped by currency. WealthMax never
adds unlike currencies together. `POST /api/v1/portfolio` creates an entry;
`PUT /api/v1/portfolio/:id` replaces one; and `DELETE /api/v1/portfolio/:id`
removes one. Every operation is owner-scoped, and deleting an account also
deletes its portfolio entries.

Every portfolio mutation also records an immutable per-currency snapshot.
`GET /api/v1/portfolio/history?currency=INR` returns up to 90 chronological
snapshots by default; `limit` accepts 1 through 365. History remains currency
separated and is removed with the account. `GET /api/v1/portfolio/export.csv`
downloads the authenticated user's entries as an Excel-compatible UTF-8 CSV;
text cells are escaped to prevent spreadsheet formula injection.

## Decision report API

`POST /api/v1/decision-reports` runs the Dart financial engine and returns a
versioned REP-002 portable snapshot. The endpoint requires a bearer token from
the authentication API.

Financial decimals must be JSON strings. This preserves exact decimal values
across JavaScript, Dart, storage, and report-generation boundaries.

```json
{
  "title": "Loan versus investment",
  "goalId": "optional-owned-goal-id",
  "cases": [
    {
      "id": "base",
      "label": "Base case",
      "currency": "INR",
      "loan": {
        "principal": "1000000",
        "annualInterestRatePercent": "9.5",
        "tenureMonths": 240,
        "processingFee": "5000",
        "prepayment": "0"
      },
      "extraCash": "100000",
      "decisionInstallment": 1,
      "grossAnnualInvestmentReturnPercent": "12",
      "annualExpenseRatioPercent": "1",
      "allocationStepPercent": 10,
      "objective": "maximumFutureValue",
      "grossAnnualReturnScenariosPercent": ["8", "12", "16"],
      "investmentGainTaxRatePercent": "20",
      "annualInflationRatePercent": "6"
    }
  ]
}
```

Supported objectives are `maximumFutureValue`, `minimumInterestCost`,
`fastestDebtFree`, and `maximumInvestedCapital`. Supported currencies are INR,
USD, and EUR. `processingFee` and `prepayment` are optional.

Successful responses use HTTP 201:

```json
{
  "apiVersion": "v1",
  "id": "server-generated-report-id",
  "createdAt": "2026-08-02T00:00:00.000Z",
  "report": {
    "schemaVersion": 1,
    "snapshotFormula": { "id": "REP-002" },
    "sourceReport": { "formulaId": "REP-001" }
  }
}
```

Successful calculations are stored for the authenticated user. The collection
and item endpoints never expose another user's reports:

`goalId` is optional. When supplied, it must identify a goal owned by the
authenticated user. Deleting that goal keeps the report and removes the link.

- `GET /api/v1/decision-reports` lists report metadata without large snapshots.
- `GET /api/v1/decision-reports/:id` returns one stored snapshot.
- `PATCH /api/v1/decision-reports/:id/goal` reassigns an existing report to an
  owned goal, or unlinks it when `goalId` is `null`, without recalculating it.
- `GET /api/v1/decision-reports/:id/export.csv` downloads an Excel-compatible
  UTF-8 CSV containing the report's case-level decision results.
- `DELETE /api/v1/decision-reports/:id` permanently deletes an owned report.

Invalid report inputs return HTTP 400. An unavailable or timed-out calculation
engine returns HTTP 503. Bridge output is capped at 2 MiB and calculations time
out after 60 seconds.

The service invokes `dart run bin/decision_report_bridge.dart` from the
repository root. On Windows, set `DART_EXECUTABLE` to the absolute path of
`dart.exe`; shell wrappers are intentionally not used.
