import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import { listGoalsByUser, createGoal, getGoalById, updateGoal, deleteGoal } from '../lib/goals';

const router = Router();
router.use(authMiddleware);

type GoalInput = {
  title?: string;
  targetAmount?: number;
  currentAmount?: number;
  targetDate?: string;
  notes?: string;
};

function goalInput(value: unknown, partial = false): GoalInput {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Goal details are required.');
  }
  const body = value as Record<string, unknown>;
  const result: GoalInput = {};
  if (!partial || body.title !== undefined) {
    if (typeof body.title !== 'string' || !body.title.trim()) {
      throw new Error('Goal title is required.');
    }
    if (body.title.trim().length > 120) throw new Error('Goal title is too long.');
    result.title = body.title.trim();
  }
  for (const field of ['targetAmount', 'currentAmount'] as const) {
    if (body[field] === undefined) continue;
    if (typeof body[field] !== 'number' || !Number.isFinite(body[field]) || body[field] < 0) {
      throw new Error(`${field} must be a non-negative number.`);
    }
    result[field] = body[field];
  }
  if (body.targetDate !== undefined) {
    if (body.targetDate === '') {
      result.targetDate = '';
    } else {
      if (
        typeof body.targetDate !== 'string'
        || !/^\d{4}-\d{2}-\d{2}$/.test(body.targetDate)
        || Number.isNaN(Date.parse(`${body.targetDate}T00:00:00Z`))
        || new Date(`${body.targetDate}T00:00:00Z`).toISOString().slice(0, 10)
          !== body.targetDate
      ) throw new Error('targetDate must be a valid ISO date.');
      result.targetDate = body.targetDate;
    }
  }
  if (body.notes !== undefined) {
    if (typeof body.notes !== 'string' || body.notes.length > 2000) {
      throw new Error('Goal notes must be text up to 2000 characters.');
    }
    result.notes = body.notes.trim();
  }
  return result;
}

// List goals for current user
router.get('/', (req: any, res) => {
  const userId = req.user.id;
  const goals = listGoalsByUser(userId);
  res.json({ goals });
});

// Create goal
router.post('/', (req: any, res) => {
  const userId = req.user.id;
  try {
    const goal = createGoal(userId, goalInput(req.body));
    return res.status(201).json({ goal });
  } catch (error) {
    return res.status(400).json({ error: (error as Error).message });
  }
});

// Get single goal
router.get('/:id', (req: any, res) => {
  const userId = req.user.id;
  const id = req.params.id;
  const goal = getGoalById(id);
  if (!goal || goal.userId !== userId) return res.status(404).json({ error: 'Not found' });
  res.json({ goal });
});

// Update goal
router.put('/:id', (req: any, res) => {
  const userId = req.user.id;
  const id = req.params.id;
  try {
    const patched = updateGoal(id, userId, goalInput(req.body, true));
    if (!patched) return res.status(404).json({ error: 'Not found or not authorized' });
    return res.json({ goal: patched });
  } catch (error) {
    return res.status(400).json({ error: (error as Error).message });
  }
});

// Delete goal
router.delete('/:id', (req: any, res) => {
  const userId = req.user.id;
  const id = req.params.id;
  const ok = deleteGoal(id, userId);
  if (!ok) return res.status(404).json({ error: 'Not found or not authorized' });
  res.status(204).send();
});

export default router;
