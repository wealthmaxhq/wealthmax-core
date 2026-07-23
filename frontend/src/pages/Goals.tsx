import React, { useEffect, useState } from 'react';
import { listGoals, createGoal } from '../api';

export default function Goals() {
  const [goals, setGoals] = useState<any[]>([]);
  const [title, setTitle] = useState('');
  const [targetAmount, setTargetAmount] = useState('');

  const fetchGoals = async () => {
    try {
      const res = await listGoals();
      setGoals(res.data.goals || []);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      // set default header if needed
    }
    fetchGoals();
  }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createGoal({ title, targetAmount: parseFloat(targetAmount) || 0 });
      setTitle(''); setTargetAmount('');
      fetchGoals();
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div>
      <h2>Your Goals</h2>
      <form onSubmit={submit}>
        <div>
          <label>Title</label>
          <input value={title} onChange={e => setTitle(e.target.value)} />
        </div>
        <div>
          <label>Target Amount</label>
          <input value={targetAmount} onChange={e => setTargetAmount(e.target.value)} />
        </div>
        <button type="submit">Create Goal</button>
      </form>

      <ul>
        {goals.map(g => (
          <li key={g.id}>{g.title} — {g.currentAmount}/{g.targetAmount}</li>
        ))}
      </ul>
    </div>
  );
}
