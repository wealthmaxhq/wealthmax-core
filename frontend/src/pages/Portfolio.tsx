import { FormEvent, useEffect, useState } from 'react';
import {
  createPortfolioEntry,
  deletePortfolioEntry,
  exportPortfolioCsv,
  getPortfolioHistory,
  listPortfolio,
  PortfolioEntry,
  PortfolioEntryInput,
  PortfolioSummary,
  PortfolioSnapshot,
  updatePortfolioEntry,
} from '../api';

const emptyForm = { name: '', kind: 'asset', category: '', currency: 'INR', value: '' };
type PortfolioForm = typeof emptyForm;

function message(error: unknown) {
  return (error as { response?: { data?: { error?: string } } }).response?.data?.error
    || 'Your portfolio could not be updated.';
}

export default function Portfolio() {
  const [entries, setEntries] = useState<PortfolioEntry[]>([]);
  const [summaries, setSummaries] = useState<PortfolioSummary[]>([]);
  const [history, setHistory] = useState<PortfolioSnapshot[]>([]);
  const [historyCurrency, setHistoryCurrency] = useState<PortfolioEntry['currency']>('INR');
  const [form, setForm] = useState<PortfolioForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = async () => {
    setLoading(true);
    try {
      const response = await listPortfolio();
      setEntries(response.data.entries);
      setSummaries(response.data.summaries);
      const currency = response.data.summaries.some((item) => item.currency === historyCurrency)
        ? historyCurrency : response.data.summaries[0]?.currency || 'INR';
      setHistoryCurrency(currency);
      setHistory((await getPortfolioHistory(currency)).data.snapshots);
    } catch (requestError) { setError(message(requestError)); }
    finally { setLoading(false); }
  };

  useEffect(() => { void refresh(); }, []);
  const reset = () => { setEditingId(null); setForm(emptyForm); };
  const edit = (entry: PortfolioEntry) => {
    setEditingId(entry.id);
    setForm({ name: entry.name, kind: entry.kind, category: entry.category, currency: entry.currency, value: String(entry.value) });
  };
  const payload = (): PortfolioEntryInput => ({
    name: form.name.trim(), kind: form.kind as PortfolioEntry['kind'], category: form.category.trim(),
    currency: form.currency as PortfolioEntry['currency'], value: Number(form.value),
  });
  const save = async (event: FormEvent) => {
    event.preventDefault(); setSaving(true); setError(null);
    try {
      if (editingId) await updatePortfolioEntry(editingId, payload());
      else await createPortfolioEntry(payload());
      reset(); await refresh();
    } catch (requestError) { setError(message(requestError)); }
    finally { setSaving(false); }
  };
  const remove = async (entry: PortfolioEntry) => {
    if (!window.confirm(`Delete “${entry.name}” permanently?`)) return;
    try { await deletePortfolioEntry(entry.id); if (editingId === entry.id) reset(); await refresh(); }
    catch (requestError) { setError(message(requestError)); }
  };

  const selectHistoryCurrency = async (currency: PortfolioEntry['currency']) => {
    setHistoryCurrency(currency);
    try { setHistory((await getPortfolioHistory(currency)).data.snapshots); }
    catch (requestError) { setError(message(requestError)); }
  };
  const download = async () => {
    setExporting(true); setError(null);
    try {
      const response = await exportPortfolioCsv();
      const disposition = response.headers['content-disposition'] as string | undefined;
      const filename = disposition?.match(/filename="([^"]+)"/)?.[1] ?? 'wealthmax-portfolio.csv';
      const url = URL.createObjectURL(response.data);
      const anchor = document.createElement('a');
      anchor.href = url; anchor.download = filename;
      document.body.appendChild(anchor); anchor.click(); anchor.remove(); URL.revokeObjectURL(url);
    } catch (requestError) { setError(message(requestError)); }
    finally { setExporting(false); }
  };
  const values = history.map((snapshot) => snapshot.netWorth);
  const minimum = values.length ? Math.min(...values) : 0;
  const maximum = values.length ? Math.max(...values) : 0;
  const span = maximum - minimum || 1;
  const points = history.map((snapshot, index) => {
    const x = history.length === 1 ? 50 : index / (history.length - 1) * 100;
    const y = 92 - (snapshot.netWorth - minimum) / span * 84;
    return `${x},${y}`;
  }).join(' ');
  const latestSnapshot = history[history.length - 1];

  return <main>
    <header className="page-header"><div><p className="eyebrow">Net worth</p><h1>Your portfolio</h1><p className="lede">Track assets and liabilities without combining unlike currencies.</p></div><button className="primary-button header-action" disabled={loading || entries.length === 0 || exporting} onClick={() => void download()}>{exporting ? 'Exporting…' : 'Export CSV'}</button></header>
    {error && <div className="alert">{error}</div>}
    <section className="portfolio-summaries">
      {summaries.length ? summaries.map((summary) => <article key={summary.currency}>
        <span>{summary.currency} net worth</span><strong>{summary.netWorth.toLocaleString()}</strong>
        <small>{summary.assets.toLocaleString()} assets · {summary.liabilities.toLocaleString()} liabilities</small>
      </article>) : <article><span>Net worth</span><strong>—</strong><small>Add your first asset or liability</small></article>}
    </section>
    {summaries.length > 0 && <section className="panel portfolio-history">
      <div className="section-heading"><div><p className="step">History</p><h2>Net-worth movement</h2></div><select aria-label="History currency" value={historyCurrency} onChange={(event) => void selectHistoryCurrency(event.target.value as PortfolioEntry['currency'])}>{summaries.map((summary) => <option key={summary.currency}>{summary.currency}</option>)}</select></div>
      {history.length ? <><svg aria-label={`${historyCurrency} net-worth history`} preserveAspectRatio="none" role="img" viewBox="0 0 100 100"><polyline fill="none" points={points} vectorEffect="non-scaling-stroke" /></svg><div className="history-range"><span>{new Date(history[0].recordedAt).toLocaleDateString()}</span><strong>{historyCurrency} {latestSnapshot.netWorth.toLocaleString()}</strong><span>{new Date(latestSnapshot.recordedAt).toLocaleDateString()}</span></div></> : <p className="muted">Changes will appear after you update your portfolio.</p>}
    </section>}
    <div className="portfolio-layout">
      <section className="panel goal-editor">
        <div className="section-heading"><div><p className="step">{editingId ? 'Editing' : 'New entry'}</p><h2>{editingId ? 'Update entry' : 'Add asset or liability'}</h2></div>{editingId && <button className="text-button" onClick={reset}>Cancel</button>}</div>
        <form className="goal-form" onSubmit={save}>
          <label>Name<input required maxLength={120} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} /></label>
          <div className="goal-form-grid"><label>Type<select value={form.kind} onChange={(event) => setForm({ ...form, kind: event.target.value })}><option value="asset">Asset</option><option value="liability">Liability</option></select></label><label>Currency<select value={form.currency} onChange={(event) => setForm({ ...form, currency: event.target.value })}><option>INR</option><option>USD</option><option>EUR</option></select></label></div>
          <label>Category<input required maxLength={60} placeholder="Cash, investments, mortgage…" value={form.category} onChange={(event) => setForm({ ...form, category: event.target.value })} /></label>
          <label>Current value<input required min="0" max="1000000000000000" step="0.01" type="number" value={form.value} onChange={(event) => setForm({ ...form, value: event.target.value })} /></label>
          <button className="primary-button" disabled={saving}>{saving ? 'Saving…' : editingId ? 'Save changes' : 'Add entry'}</button>
        </form>
      </section>
      <section className="portfolio-list" aria-live="polite">
        {loading ? <div className="panel"><p className="muted">Loading portfolio…</p></div> : entries.length === 0 ? <div className="panel dashboard-empty"><p>No portfolio entries yet.</p></div> : entries.map((entry) => <article className="panel portfolio-card" key={entry.id}>
          <div><div><span className={`portfolio-kind ${entry.kind}`}>{entry.kind}</span><h2>{entry.name}</h2><small>{entry.category}</small></div><strong>{entry.currency} {entry.value.toLocaleString()}</strong></div>
          <div className="goal-actions"><button className="text-button" onClick={() => edit(entry)}>Edit</button><button className="danger-button" onClick={() => void remove(entry)}>Delete</button></div>
        </article>)}
      </section>
    </div>
  </main>;
}
