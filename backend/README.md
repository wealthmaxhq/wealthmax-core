# WealthMax backend

## Decision report API

`POST /api/v1/decision-reports` runs the Dart financial engine and returns a
versioned REP-002 portable snapshot. The endpoint requires a bearer token from
the authentication API.

Financial decimals must be JSON strings. This preserves exact decimal values
across JavaScript, Dart, storage, and report-generation boundaries.

```json
{
  "title": "Loan versus investment",
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

- `GET /api/v1/decision-reports` lists report metadata without large snapshots.
- `GET /api/v1/decision-reports/:id` returns one stored snapshot.
- `DELETE /api/v1/decision-reports/:id` permanently deletes an owned report.

Invalid report inputs return HTTP 400. An unavailable or timed-out calculation
engine returns HTTP 503. Bridge output is capped at 2 MiB and calculations time
out after 60 seconds.

The service invokes `dart run bin/decision_report_bridge.dart` from the
repository root. On Windows, set `DART_EXECUTABLE` to the absolute path of
`dart.exe`; shell wrappers are intentionally not used.
