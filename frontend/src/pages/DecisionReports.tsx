import { FormEvent, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  createDecisionReport,
  DecisionReportSummary,
  deleteDecisionReport,
  exportDecisionReportCsv,
  getDecisionReport,
  listDecisionReports,
  StoredDecisionReport,
} from '../api';

type FormState = {
  title: string;
  currency: string;
  principal: string;
  loanRate: string;
  tenureMonths: string;
  extraCash: string;
  downsideReturn: string;
  investmentReturn: string;
  upsideReturn: string;
  expenseRatio: string;
  taxRate: string;
  inflationRate: string;
  objective: string;
};

const initialForm: FormState = {
  title: 'Loan versus investment',
  currency: 'INR',
  principal: '1000000',
  loanRate: '9.5',
  tenureMonths: '240',
  extraCash: '100000',
  downsideReturn: '8',
  investmentReturn: '12',
  upsideReturn: '16',
  expenseRatio: '1',
  taxRate: '20',
  inflationRate: '6',
  objective: 'maximumFutureValue',
};

const objectiveLabels: Record<string, string> = {
  maximumFutureValue: 'Build the most future wealth',
  minimumInterestCost: 'Pay the least loan interest',
  fastestDebtFree: 'Become debt-free fastest',
  maximumInvestedCapital: 'Keep the most money invested',
};

const objectiveHelp: Record<string, string> = {
  maximumFutureValue: 'Selects the allocation with the highest value at the shared comparison horizon.',
  minimumInterestCost: 'Prioritizes reducing total loan interest, even when another path may build more wealth.',
  fastestDebtFree: 'Prioritizes the earliest loan payoff date.',
  maximumInvestedCapital: 'Prioritizes market exposure and liquidity over debt reduction.',
};

function errorMessage(error: unknown): string {
  const response = error as { response?: { data?: { error?: unknown } } };
  return typeof response.response?.data?.error === 'string'
    ? response.response.data.error
    : 'Something went wrong. Please try again.';
}

function reportPayload(form: FormState) {
  const returns = [
    { id: 'downside', label: 'Downside case', value: form.downsideReturn.trim() },
    { id: 'base', label: 'Base case', value: form.investmentReturn.trim() },
    { id: 'upside', label: 'Upside case', value: form.upsideReturn.trim() },
  ];
  const returnScenarios = returns.map((scenario) => scenario.value);
  return {
    title: form.title.trim(),
    cases: returns.map((scenario) => ({
        id: scenario.id,
        label: scenario.label,
        currency: form.currency,
        loan: {
          principal: form.principal.trim(),
          annualInterestRatePercent: form.loanRate.trim(),
          tenureMonths: Number(form.tenureMonths),
        },
        extraCash: form.extraCash.trim(),
        decisionInstallment: 1,
        grossAnnualInvestmentReturnPercent: scenario.value,
        annualExpenseRatioPercent: form.expenseRatio.trim(),
        allocationStepPercent: 10,
        objective: form.objective,
        grossAnnualReturnScenariosPercent: returnScenarios,
        investmentGainTaxRatePercent: form.taxRate.trim(),
        annualInflationRatePercent: form.inflationRate.trim(),
    })),
  };
}

export default function DecisionReports() {
  const authenticated = Boolean(localStorage.getItem('token'));
  const [form, setForm] = useState<FormState>(initialForm);
  const [reports, setReports] = useState<DecisionReportSummary[]>([]);
  const [selected, setSelected] = useState<StoredDecisionReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [calculating, setCalculating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await listDecisionReports();
      setReports(response.data.reports);
    } catch (requestError) {
      setError(errorMessage(requestError));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (authenticated) void refresh();
    else setLoading(false);
  }, [authenticated]);

  const update = (field: keyof FormState, value: string) => {
    setForm((current) => ({ ...current, [field]: value }));
  };

  const calculate = async (event: FormEvent) => {
    event.preventDefault();
    const downside = Number(form.downsideReturn);
    const base = Number(form.investmentReturn);
    const upside = Number(form.upsideReturn);
    if (!(downside <= base && base <= upside)) {
      setError('Investment returns must be ordered downside, base, then upside.');
      return;
    }
    setCalculating(true);
    setError(null);
    try {
      const response = await createDecisionReport(reportPayload(form));
      setSelected(response.data);
      await refresh();
    } catch (requestError) {
      setError(errorMessage(requestError));
    } finally {
      setCalculating(false);
    }
  };

  const open = async (id: string) => {
    setError(null);
    try {
      const response = await getDecisionReport(id);
      setSelected(response.data);
    } catch (requestError) {
      setError(errorMessage(requestError));
    }
  };

  const remove = async (id: string) => {
    if (!window.confirm('Delete this decision report permanently?')) return;
    setError(null);
    try {
      await deleteDecisionReport(id);
      if (selected?.id === id) setSelected(null);
      await refresh();
    } catch (requestError) {
      setError(errorMessage(requestError));
    }
  };

  const download = async (report: StoredDecisionReport) => {
    setError(null);
    try {
      const response = await exportDecisionReportCsv(report.id);
      const disposition = response.headers['content-disposition'] as string | undefined;
      const filename = disposition?.match(/filename="([^"]+)"/)?.[1]
        ?? 'decision-report.csv';
      const url = URL.createObjectURL(response.data);
      const anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = filename;
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      URL.revokeObjectURL(url);
    } catch (requestError) {
      setError(errorMessage(requestError));
    }
  };

  const printReport = (report: StoredDecisionReport) => {
    const previousTitle = document.title;
    document.title = `${report.title} - WealthMax`;
    window.print();
    document.title = previousTitle;
  };

  const selectedCase = selected?.report.cases.find((item) => item.id === 'base')
    ?? selected?.report.cases[0];

  if (!authenticated) {
    return (
      <main>
        <header className="page-header">
          <div>
            <p className="eyebrow">Decision intelligence</p>
            <h1>Loan or invest?</h1>
            <p className="lede">
              Sign in to calculate, save, and revisit your private decision
              reports.
            </p>
          </div>
        </header>
        <section className="panel auth-gate">
          <span className="empty-icon">W</span>
          <h2>Your reports stay with your account</h2>
          <p className="muted">
            Sign in to continue, or create an account to build your first
            after-tax, inflation-adjusted comparison.
          </p>
          <div className="auth-actions">
            <Link className="primary-button inline-button" to="/login">
              Sign in
            </Link>
            <Link className="secondary-link" to="/register">
              Create account
            </Link>
          </div>
        </section>
      </main>
    );
  }

  return (
    <main>
      <header className="page-header">
        <div>
          <p className="eyebrow">Decision intelligence</p>
          <h1>Loan or invest?</h1>
          <p className="lede">
            Compare both paths on one horizon, after tax and inflation, with a
            report you can return to later.
          </p>
        </div>
      </header>

      {error && <div className="alert">{error}</div>}

      <div className="workspace-grid">
        <section className="panel">
          <div className="section-heading">
            <div>
              <p className="step">Step 1</p>
              <h2>Set your assumptions</h2>
            </div>
            <span className="badge">Exact decimals</span>
          </div>
          <form className="report-form" onSubmit={calculate}>
            <label className="full-field">
              Report name
              <input
                required
                value={form.title}
                onChange={(event) => update('title', event.target.value)}
              />
            </label>
            <label className="full-field">
              What matters most?
              <select
                value={form.objective}
                onChange={(event) => update('objective', event.target.value)}
              >
                {Object.entries(objectiveLabels).map(([value, label]) => (
                  <option key={value} value={value}>{label}</option>
                ))}
              </select>
              <span className="field-help">{objectiveHelp[form.objective]}</span>
            </label>
            <label>
              Currency
              <select
                value={form.currency}
                onChange={(event) => update('currency', event.target.value)}
              >
                <option value="INR">INR</option>
                <option value="USD">USD</option>
                <option value="EUR">EUR</option>
              </select>
            </label>
            <label>
              Loan principal
              <input
                required
                inputMode="decimal"
                value={form.principal}
                onChange={(event) => update('principal', event.target.value)}
              />
            </label>
            <label>
              Loan rate (% p.a.)
              <input
                required
                inputMode="decimal"
                value={form.loanRate}
                onChange={(event) => update('loanRate', event.target.value)}
              />
            </label>
            <label>
              Remaining months
              <input
                required
                min="1"
                max="1200"
                type="number"
                value={form.tenureMonths}
                onChange={(event) => update('tenureMonths', event.target.value)}
              />
            </label>
            <label>
              Extra cash available
              <input
                required
                inputMode="decimal"
                value={form.extraCash}
                onChange={(event) => update('extraCash', event.target.value)}
              />
            </label>
            <label>
              Downside return (% p.a.)
              <input
                required
                inputMode="decimal"
                value={form.downsideReturn}
                onChange={(event) => update('downsideReturn', event.target.value)}
              />
            </label>
            <label>
              Base return (% p.a.)
              <input
                required
                inputMode="decimal"
                value={form.investmentReturn}
                onChange={(event) => update('investmentReturn', event.target.value)}
              />
            </label>
            <label>
              Upside return (% p.a.)
              <input
                required
                inputMode="decimal"
                value={form.upsideReturn}
                onChange={(event) => update('upsideReturn', event.target.value)}
              />
            </label>
            <label>
              Expense ratio (%)
              <input
                required
                inputMode="decimal"
                value={form.expenseRatio}
                onChange={(event) => update('expenseRatio', event.target.value)}
              />
            </label>
            <label>
              Gain tax rate (%)
              <input
                required
                inputMode="decimal"
                value={form.taxRate}
                onChange={(event) => update('taxRate', event.target.value)}
              />
            </label>
            <label>
              Inflation rate (%)
              <input
                required
                inputMode="decimal"
                value={form.inflationRate}
                onChange={(event) => update('inflationRate', event.target.value)}
              />
            </label>
            <button className="primary-button full-field" disabled={calculating}>
              {calculating ? 'Calculating…' : 'Calculate and save report'}
            </button>
          </form>
        </section>

        <section className="panel result-panel">
          <div className="section-heading">
            <div>
              <p className="step">Step 2</p>
              <h2>Your result</h2>
            </div>
          </div>
          {!selectedCase ? (
            <div className="empty-state">
              <span className="empty-icon">↗</span>
              <h3>Ready when you are</h3>
              <p>Your after-tax, inflation-adjusted result will appear here.</p>
            </div>
          ) : (
            <div className="result-content">
              <div className="result-toolbar">
                <p className="result-title">{selected.title}</p>
                <div className="result-actions">
                  <button
                    className="text-button"
                    type="button"
                    onClick={() => printReport(selected)}
                  >
                    Print / Save PDF
                  </button>
                  <button
                    className="text-button"
                    type="button"
                    onClick={() => void download(selected)}
                  >
                    Download CSV
                  </button>
                </div>
              </div>
              <p className="print-metadata">
                Generated {new Date(selected.createdAt).toLocaleString()} ·{' '}
                {selected.sourceFormulaId} · Schema {selected.schemaVersion}
              </p>
              <p className="objective-summary">
                Objective: {objectiveLabels[selectedCase.objective] ?? selectedCase.objective}
              </p>
              <div className="hero-metric">
                <span>Real after-tax future value</span>
                <strong>
                  {selected.currency} {selectedCase.realAfterTaxFutureValue}
                </strong>
              </div>
              <div className="metric-grid">
                <div>
                  <span>After-tax value</span>
                  <strong>{selectedCase.afterTaxFutureValue}</strong>
                </div>
                <div>
                  <span>Estimated tax</span>
                  <strong>{selectedCase.estimatedTax}</strong>
                </div>
                <div>
                  <span>Prepay allocation</span>
                  <strong>
                    {selectedCase.selectedPrepaymentAllocationPercent}%
                  </strong>
                </div>
                <div>
                  <span>Tax changed choice</span>
                  <strong>{selectedCase.selectionChangedByTax ? 'Yes' : 'No'}</strong>
                </div>
              </div>
              <div className="scenario-section">
                <div className="scenario-heading">
                  <h3>Scenario comparison</h3>
                  <span>
                    Real-value range {selected.report.summary.selectedRealValueRange}
                  </span>
                </div>
                <div className="scenario-table-wrap">
                  <table className="scenario-table">
                    <thead>
                      <tr>
                        <th scope="col">Scenario</th>
                        <th scope="col">Prepay</th>
                        <th scope="col">Real value</th>
                        <th scope="col">Tax</th>
                      </tr>
                    </thead>
                    <tbody>
                      {selected.report.cases.map((reportCase) => (
                        <tr
                          key={reportCase.id}
                          className={reportCase.id === 'base' ? 'base-scenario' : undefined}
                        >
                          <th scope="row">{reportCase.label}</th>
                          <td>{reportCase.selectedPrepaymentAllocationPercent}%</td>
                          <td>{reportCase.realAfterTaxFutureValue}</td>
                          <td>{reportCase.estimatedTax}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
              {selected.report.warnings.length > 0 && (
                <details className="warnings">
                  <summary>{selected.report.warnings.length} calculation notes</summary>
                  <ul>
                    {selected.report.warnings.map((warning) => (
                      <li key={warning.code}>{warning.message}</li>
                    ))}
                  </ul>
                </details>
              )}
            </div>
          )}
        </section>
      </div>

      <section className="panel saved-reports">
        <div className="section-heading">
          <div>
            <p className="step">Your library</p>
            <h2>Saved reports</h2>
          </div>
          <button className="text-button" onClick={() => void refresh()}>
            Refresh
          </button>
        </div>
        {loading ? (
          <p className="muted">Loading reports…</p>
        ) : reports.length === 0 ? (
          <p className="muted">No reports yet. Your first calculation will be saved here.</p>
        ) : (
          <div className="report-list">
            {reports.map((report) => (
              <article key={report.id} className="report-row">
                <button className="report-open" onClick={() => void open(report.id)}>
                  <strong>{report.title}</strong>
                  <span>
                    {report.currency} · {new Date(report.createdAt).toLocaleString()}
                  </span>
                </button>
                <button
                  className="danger-button"
                  aria-label={`Delete ${report.title}`}
                  onClick={() => void remove(report.id)}
                >
                  Delete
                </button>
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
