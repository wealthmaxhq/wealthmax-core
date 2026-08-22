import { FormEvent, useEffect, useState } from 'react';
import {
  calculateFinancialHealth,
  FinancialHealthSnapshot,
  FinancialHealthInput,
  FinancialHealthResult,
  getFinancialHealthHistory,
} from '../api';

const initialInput: FinancialHealthInput = {
  currency: 'INR',
  liquidSavings: '',
  monthlyNetIncome: '',
  monthlyEssentialExpenses: '',
  monthlyDebtPayments: '',
  monthlySavings: '',
};

const labels: Record<keyof Omit<FinancialHealthInput, 'currency'>, string> = {
  liquidSavings: 'Liquid savings',
  monthlyNetIncome: 'Monthly net income',
  monthlyEssentialExpenses: 'Monthly essential expenses',
  monthlyDebtPayments: 'Monthly debt payments',
  monthlySavings: 'Monthly savings',
};

const findingText: Record<FinancialHealthResult['findings'][number], string> = {
  buildEmergencyFund: 'Build an emergency fund covering at least six months of essentials.',
  reduceDebtBurden: 'Reduce monthly debt payments relative to take-home income.',
  increaseSavingsRate: 'Increase the share of monthly income directed to savings.',
};

function errorMessage(error: unknown): string {
  const response = error as { response?: { data?: { error?: string } } };
  return response.response?.data?.error || 'Your score could not be calculated. Please try again.';
}

export default function FinancialHealth() {
  const [input, setInput] = useState(initialInput);
  const [result, setResult] = useState<FinancialHealthResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [history, setHistory] = useState<FinancialHealthSnapshot[]>([]);

  useEffect(() => {
    getFinancialHealthHistory()
      .then((response) => {
        setHistory(response.data.snapshots);
        const latest = response.data.snapshots[response.data.snapshots.length - 1];
        if (latest) setResult(latest.result);
      })
      .catch((requestError) => setError(errorMessage(requestError)));
  }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const response = await calculateFinancialHealth(input);
      setResult(response.data);
      const historyResponse = await getFinancialHealthHistory();
      setHistory(historyResponse.data.snapshots);
    } catch (requestError) {
      setError(errorMessage(requestError));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main>
      <header className="page-header">
        <div>
          <p className="eyebrow">Financial health</p>
          <h1>Know what to strengthen next.</h1>
          <p className="lede">Get a transparent score based on liquidity, debt burden, and savings rate.</p>
        </div>
      </header>
      {error && <div className="alert" role="alert">{error}</div>}
      <div className="workspace-grid">
        <section className="panel">
          <div className="section-heading"><div><p className="step">Your numbers</p><h2>Monthly financial snapshot</h2></div></div>
          <form className="report-form" onSubmit={submit}>
            <label>Currency
              <select value={input.currency} onChange={(event) => setInput({ ...input, currency: event.target.value as FinancialHealthInput['currency'] })}>
                <option value="INR">INR</option><option value="USD">USD</option><option value="EUR">EUR</option>
              </select>
            </label>
            {Object.entries(labels).map(([name, label]) => (
              <label key={name}>{label}
                <input required min="0" step="0.01" inputMode="decimal" type="number" value={input[name as keyof typeof labels]} onChange={(event) => setInput({ ...input, [name]: event.target.value })} />
              </label>
            ))}
            <button className="primary-button full-field" disabled={submitting} type="submit">{submitting ? 'Calculating…' : 'Calculate my score'}</button>
          </form>
        </section>
        <section className="panel result-panel" aria-live="polite">
          {!result ? <div className="empty-state"><div className="empty-icon">%</div><p>Enter your current numbers to see your score and priorities.</p></div> : (
            <div className="health-result">
              <p className="step">Your financial health score</p>
              <div className="health-score"><strong>{result.score}</strong><span>/ 100<br />{result.rating.replace(/([A-Z])/g, ' $1')}</span></div>
              <div className="health-components">
                <div><span>Emergency fund</span><strong>{result.componentScores.emergencyFund}</strong><small>{result.metrics.emergencyFundMonths} months</small></div>
                <div><span>Debt burden</span><strong>{result.componentScores.debtBurden}</strong><small>{result.metrics.debtToIncomePercent}% of income</small></div>
                <div><span>Savings rate</span><strong>{result.componentScores.savingsRate}</strong><small>{result.metrics.savingsRatePercent}% of income</small></div>
              </div>
              <div className="health-findings"><h3>{result.findings.length ? 'Priorities' : 'Strong foundations'}</h3>{result.findings.length ? <ul>{result.findings.map((finding) => <li key={finding}>{findingText[finding]}</li>)}</ul> : <p>Your liquidity, debt burden, and savings rate meet the scoring targets.</p>}</div>
            </div>
          )}
        </section>
      </div>
      {history.length > 0 && (
        <section className="panel health-history">
          <div className="section-heading">
            <div><p className="step">Progress</p><h2>Score history</h2></div>
            <span className="badge">{history.length} {history.length === 1 ? 'check-in' : 'check-ins'}</span>
          </div>
          <div className="health-history-chart" aria-label="Financial health score history">
            {history.map((snapshot) => (
              <div key={snapshot.id} className="health-history-point">
                <strong>{snapshot.score}</strong>
                <span style={{ height: `${Math.max(snapshot.score, 4)}%` }} />
                <small>{new Date(snapshot.recordedAt).toLocaleDateString()}</small>
              </div>
            ))}
          </div>
          {history.length > 1 && (
            <p className="muted health-trend">
              Your score has {history[history.length - 1].score >= history[0].score ? 'improved' : 'changed'} by{' '}
              <strong>{Math.abs(history[history.length - 1].score - history[0].score)} points</strong> across this period.
            </p>
          )}
        </section>
      )}
    </main>
  );
}
