import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import { listGoalsByUser, createGoal, getGoalById, updateGoal, deleteGoal } from '../lib/goals';

const router = Router();
router.use(authMiddleware);

// List goals for current user
router.get('/', (req: any, res) => {
  const userId = req.user.id;
  const goals = listGoalsByUser(userId);
  res.json({ goals });
});

// Create goal
router.post('/', (req: any, res) => {
  const userId = req.user.id;
  const { title, targetAmount, currentAmount, targetDate, notes } = req.body;
  if (!title) return res.status(400).json({ error: 'title required' });
  const goal = createGoal(userId, { title, targetAmount, currentAmount, targetDate, notes });
  res.status(201).json({ goal });
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
  const patched = updateGoal(id, userId, req.body);
  if (!patched) return res.status(404).json({ error: 'Not found or not authorized' });
  res.json({ goal: patched });
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
