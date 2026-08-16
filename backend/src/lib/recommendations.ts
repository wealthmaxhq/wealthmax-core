import { listGoalsByUser } from './goals';
const defaultHorizonMonths = 60;

function monthsUntil(dateStr: string | undefined, now: Date): number {
  if (!dateStr) return defaultHorizonMonths;
  const target = new Date(`${dateStr}T00:00:00Z`);
  const currentMonth = now.getUTCFullYear() * 12 + now.getUTCMonth();
  const targetMonth = target.getUTCFullYear() * 12 + target.getUTCMonth();
  return Math.max(1, targetMonth - currentMonth);
}

export function computeMonthlyNeededForGoals(userId: string, now = new Date()) {
  const goals = listGoalsByUser(userId);
  let total = 0;
  const breakdown = goals.map(g => {
    const months = monthsUntil(g.targetDate, now);
    const remaining = Math.max(0, g.targetAmount - g.currentAmount);
    const monthly = Number((remaining / months).toFixed(2));
    total += monthly;
    return { id: g.id, title: g.title, remaining, months, monthly };
  });
  return { totalMonthlyRequired: Number(total.toFixed(2)), breakdown };
}

export function suggestAllocation(userId: string, now = new Date()) {
  const goals = listGoalsByUser(userId);
  const monthsList = goals.map(g => monthsUntil(g.targetDate, now));
  const nearest = monthsList.length ? Math.min(...monthsList) : 120;

  if (nearest <= 36) {
    return { profile: 'Conservative', allocation: { stocks: 0.55, bonds: 0.4, cash: 0.05 }, reason: 'Nearest goal within 3 years; preserve capital.' };
  }
  if (nearest <= 120) {
    return { profile: 'Balanced', allocation: { stocks: 0.7, bonds: 0.25, cash: 0.05 }, reason: 'Medium-term goals; balance growth and stability.' };
  }
  return { profile: 'Aggressive', allocation: { stocks: 0.85, bonds: 0.1, cash: 0.05 }, reason: 'Long-term goals; favor growth.' };
}

export function getRecommendations(userId: string, now = new Date()) {
  const savings = computeMonthlyNeededForGoals(userId, now);
  const allocation = suggestAllocation(userId, now);
  return {
    apiVersion: 'v1' as const,
    savings,
    allocation,
    generatedAt: now.toISOString(),
  };
}
