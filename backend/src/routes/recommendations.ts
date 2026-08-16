import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import { getRecommendations } from '../lib/recommendations';

const router = Router();
router.use(authMiddleware);

router.get('/', (req: any, res) => {
  res.json({ recommendations: getRecommendations(req.user.id) });
});

export default router;
