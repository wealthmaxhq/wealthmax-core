import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  createGoal,
  deleteGoal,
  Goal,
  GoalInput,
  listGoals,
  updateGoal,
} from '../api';

const emptyForm = {
  title: '',
  targetAmount: '',
  currentAmount: '0',
  targetDate: '',
  notes: '',
};

type GoalForm = typeof emptyForm;

function message(error: unknown): string {
  const response = error as { response?: { data?: { error?: string } } };
  return response.response?.data?.error || 'Something went wrong. Please try again.';
}

function payload(form: GoalForm): GoalInput {
  return {
    title: form.title.trim(),
    targetAmount: Number(form.targetAmount),
    currentAmount: Number(form.currentAmount),
    targetDate: form.targetDate,
    notes: form.notes.trim(),
  };
}

function formFor(goal: Goal): GoalForm {
  return {
    title: goal.title,
    targetAmount: String(goal.targetAmount),
    currentAmount: String(goal.currentAmount),
    targetDate: goal.targetDate || '',
    notes: goal.notes || '',
  };
}

export default function Goals() {
  const [goals, setGoals] = useState<Goal[]>([]);
  const [form, setForm] = useState<GoalForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = async () => {
    setLoading(true);
    try {
      const response = await listGoals();
      setGoals(response.data.goals);
    } catch (requestError) {
      setError(message(requestError));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void refresh(); }, []);

  const totals = useMemo(() => goals.reduce(
    (sum, goal) => ({
      target: sum.target + goal.targetAmount,
      current: sum.current + goal.currentAmount,
    }),
    { target: 0, current: 0 },
  ), [goals]);

  const update = (field: keyof GoalForm, value: string) => {
    setForm((current) => ({ ...current, [field]: value }));
  };

  const reset = () => {
    setEditingId(null);
    setForm(emptyForm);
  };

  const save = async (event: FormEvent) => {
    event.preventDefault();
    setSaving(true);
    setError(null);
    try {
      if (editingId) await updateGoal(editingId, payload(form));
      else await createGoal(payload(form));
      reset();
      await refresh();
    } catch (requestError) {
      setError(message(requestError));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (goal: Goal) => {
    if (!window.confirm(`Delete “${goal.title}” permanently?`)) return;
    setError(null);
    try {
      await deleteGoal(goal.id);
      if (editingId === goal.id) reset();
      await refresh();
    } catch (requestError) {
      setError(message(requestError));
    }
  };

  return (
    <main>
      <header className="page-header">
        <div>
          <p className="eyebrow">Financial planning</p>
          <h1>Your goals</h1>
          <p className="lede">Track the destinations your decisions are meant to fund.</p>
        </div>
      </header>

      {error && <div className="alert">{error}</div>}

      <section className="goal-summary">
        <div><span>Goals</span><strong>{goals.length}</strong></div>
        <div><span>Total saved</span><strong>{totals.current.toLocaleString()}</strong></div>
        <div><span>Total target</span><strong>{totals.target.toLocaleString()}</strong></div>
        <div><span>Overall progress</span><strong>{totals.target ? Math.min(100, Math.round(totals.current / totals.target * 100)) : 0}%</strong></div>
      </section>

      <div className="goals-layout">
        <section className="panel goal-editor">
          <div className="section-heading">
            <div><p className="step">{editingId ? 'Editing' : 'New goal'}</p><h2>{editingId ? 'Update goal' : 'Add a goal'}</h2></div>
            {editingId && <button className="text-button" type="button" onClick={reset}>Cancel</button>}
          </div>
          <form className="goal-form" onSubmit={save}>
            <label>Goal name<input required maxLength={120} value={form.title} onChange={(event) => update('title', event.target.value)} /></label>
            <div className="goal-form-grid">
              <label>Target amount<input required min="0" step="0.01" type="number" value={form.targetAmount} onChange={(event) => update('targetAmount', event.target.value)} /></label>
              <label>Amount saved<input required min="0" step="0.01" type="number" value={form.currentAmount} onChange={(event) => update('currentAmount', event.target.value)} /></label>
            </div>
            <label>Target date (optional)<input type="date" value={form.targetDate} onChange={(event) => update('targetDate', event.target.value)} /></label>
            <label>Notes (optional)<textarea maxLength={2000} rows={4} value={form.notes} onChange={(event) => update('notes', event.target.value)} /></label>
            <button className="primary-button" disabled={saving}>{saving ? 'Saving…' : editingId ? 'Save changes' : 'Create goal'}</button>
          </form>
        </section>

        <section className="goal-list" aria-live="polite">
          {loading ? <div className="panel"><p className="muted">Loading goals…</p></div> : goals.length === 0 ? (
            <div className="panel empty-state"><span className="empty-icon">◎</span><h3>No goals yet</h3><p>Create one to start measuring your progress.</p></div>
          ) : goals.map((goal) => {
            const progress = goal.targetAmount > 0 ? Math.min(100, goal.currentAmount / goal.targetAmount * 100) : 0;
            return (
              <article className="panel goal-card" key={goal.id}>
                <div className="goal-card-header"><div><h2>{goal.title}</h2>{goal.targetDate && <span>Target {new Date(`${goal.targetDate}T00:00:00`).toLocaleDateString()}</span>}</div><strong>{Math.round(progress)}%</strong></div>
                <div className="progress-track"><span style={{ width: `${progress}%` }} /></div>
                <p className="goal-amount"><strong>{goal.currentAmount.toLocaleString()}</strong> of {goal.targetAmount.toLocaleString()}</p>
                {goal.notes && <p className="goal-notes">{goal.notes}</p>}
                <div className="goal-actions"><button className="text-button" onClick={() => { setEditingId(goal.id); setForm(formFor(goal)); }}>Edit</button><button className="danger-button" onClick={() => void remove(goal)}>Delete</button></div>
              </article>
            );
          })}
        </section>
      </div>
    </main>
  );
}
