import { listGoalsByUser } from './goals';
import { findUserById } from './users';

function monthsUntil(dateStr?: string) {
  if (!dateStr) return 60; // default 5 years
  const target = new Date(dateStr);
  const ms = target.getTime() - Date.now();
  const months = Math.max(1, Math.ceil(ms / (1000 * 60 * 60 * 24 * 30)));
  return months;
}

export function computeMonthlyNeededForGoals(userId: string) {
  const goals = listGoalsByUser(userId);
  let total = 0;
  const breakdown = goals.map(g => {
    const months = monthsUntil(g.targetDate);
    const remaining = Math.max(0, (g.targetAmount || 0) - (g.currentAmount || 0));
    const monthly = months > 0 ? remaining / months : remaining;
    total += monthly;
    return { id: g.id, title: g.title, remaining, months, monthly };
  });
  return { totalMonthlyRequired: Number(total.toFixed(2)), breakdown };
}

export function suggestAllocation(userId: string) {
  // Simple heuristic based on nearest goal
  const goals = listGoalsByUser(userId);
  const monthsList = goals.map(g => monthsUntil(g.targetDate));
  const nearest = monthsList.length ? Math.min(...monthsList) : 120;

  if (nearest <= 36) {
    return { profile: 'Conservative', allocation: { stocks: 0.55, bonds: 0.4, cash: 0.05 }, reason: 'Nearest goal within 3 years; preserve capital.' };
  }
  if (nearest <= 120) {
    return { profile: 'Balanced', allocation: { stocks: 0.7, bonds: 0.25, cash: 0.05 }, reason: 'Medium-term goals; balance growth and stability.' };
  }
  return { profile: 'Aggressive', allocation: { stocks: 0.85, bonds: 0.1, cash: 0.05 }, reason: 'Long-term goals; favor growth.' };
}

export function getRecommendations(userId: string) {
  const user = findUserById(userId);
  const savings = computeMonthlyNeededForGoals(userId);
  const allocation = suggestAllocation(userId);
  return {
    user: { id: user?.id, email: user?.email, name: user?.name },
    savings,
    allocation,
    generatedAt: new Date().toISOString(),
  };
}
