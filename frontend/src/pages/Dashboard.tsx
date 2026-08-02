import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  DecisionReportSummary,
  Goal,
  listDecisionReports,
  listGoals,
} from '../api';
import { useAuth } from '../auth';

function message(error: unknown): string {
  const response = error as { response?: { data?: { error?: string } } };
  return response.response?.data?.error || 'Your dashboard could not be loaded.';
}

export default function Dashboard() {
  const { user } = useAuth();
  const [goals, setGoals] = useState<Goal[]>([]);
  const [reports, setReports] = useState<DecisionReportSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([listGoals(), listDecisionReports()])
      .then(([goalResponse, reportResponse]) => {
        setGoals(goalResponse.data.goals);
        setReports(reportResponse.data.reports);
      })
      .catch((requestError) => setError(message(requestError)))
      .finally(() => setLoading(false));
  }, []);

  const summary = useMemo(() => {
    const target = goals.reduce((total, goal) => total + goal.targetAmount, 0);
    const saved = goals.reduce((total, goal) => total + goal.currentAmount, 0);
    return {
      target,
      saved,
      progress: target ? Math.min(100, Math.round(saved / target * 100)) : 0,
      linkedReports: reports.filter((report) => report.goalId).length,
    };
  }, [goals, reports]);

  const goalName = (id?: string) => goals.find((goal) => goal.id === id)?.title;
  const nextGoal = [...goals]
    .filter((goal) => goal.targetDate)
    .sort((first, second) => first.targetDate!.localeCompare(second.targetDate!))[0];

  return (
    <main>
      <header className="dashboard-header">
        <div>
          <p className="eyebrow">Your planning overview</p>
          <h1>Welcome back{user?.name ? `, ${user.name}` : ''}.</h1>
          <p className="lede">See where your goals stand and continue your latest financial decisions.</p>
        </div>
        <Link className="primary-button inline-button" to="/reports">New decision report</Link>
      </header>

      {error && <div className="alert">{error}</div>}
      {loading ? <section className="panel"><p className="muted">Loading your plan…</p></section> : (
        <>
          <section className="dashboard-metrics">
            <Link to="/goals"><span>Goal progress</span><strong>{summary.progress}%</strong><small>{summary.saved.toLocaleString()} of {summary.target.toLocaleString()}</small></Link>
            <Link to="/goals"><span>Active goals</span><strong>{goals.length}</strong><small>{nextGoal ? `Next: ${nextGoal.title}` : 'Add a target date to plan ahead'}</small></Link>
            <Link to="/reports"><span>Decision reports</span><strong>{reports.length}</strong><small>{summary.linkedReports} linked to goals</small></Link>
          </section>

          <div className="dashboard-grid">
            <section className="panel">
              <div className="section-heading"><div><p className="step">Goals</p><h2>Progress at a glance</h2></div><Link className="text-link" to="/goals">View all</Link></div>
              {goals.length === 0 ? <div className="dashboard-empty"><p>No goals yet.</p><Link to="/goals">Create your first goal</Link></div> : (
                <div className="dashboard-goals">
                  {goals.slice(0, 4).map((goal) => {
                    const progress = goal.targetAmount ? Math.min(100, goal.currentAmount / goal.targetAmount * 100) : 0;
                    return <article key={goal.id}><div><strong>{goal.title}</strong><span>{Math.round(progress)}%</span></div><div className="progress-track"><span style={{ width: `${progress}%` }} /></div><small>{goal.currentAmount.toLocaleString()} of {goal.targetAmount.toLocaleString()}</small></article>;
                  })}
                </div>
              )}
            </section>

            <section className="panel">
              <div className="section-heading"><div><p className="step">Recent analysis</p><h2>Decision reports</h2></div><Link className="text-link" to="/reports">View all</Link></div>
              {reports.length === 0 ? <div className="dashboard-empty"><p>No reports yet.</p><Link to="/reports">Compare loan and investment paths</Link></div> : (
                <div className="dashboard-reports">
                  {reports.slice(0, 4).map((report) => <Link to={`/reports/${report.id}`} key={report.id}><div><strong>{report.title}</strong><span>{new Date(report.createdAt).toLocaleDateString()}</span></div><small>{report.currency}{report.goalId ? ` · ${goalName(report.goalId) ?? 'Linked goal'}` : ' · No linked goal'}</small></Link>)}
                </div>
              )}
            </section>
          </div>
        </>
      )}
    </main>
  );
}
