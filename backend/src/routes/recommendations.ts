import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import { getRecommendations } from '../lib/recommendations';

const router = Router();
router.use(authMiddleware);

router.get('/', (req: any, res) => {
  try {
    const rec = getRecommendations(req.user.id);
    res.json({ recommendations: rec });
  } catch (err) {
    res.status(500).json({ error: 'Failed to compute recommendations' });
  }
});

export default router;
