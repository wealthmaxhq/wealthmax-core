import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import {
  calculateFinancialHealthScore,
  FinancialHealthBridgeError,
} from '../lib/financialHealthScore';

const router = Router();
router.use(authMiddleware);

router.post('/', async (req, res) => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return res.status(400).json({ error: 'Financial health input is required.' });
  }
  try {
    return res.json(await calculateFinancialHealthScore(req.body));
  } catch (error) {
    if (error instanceof FinancialHealthBridgeError) {
      return res.status(error.kind === 'invalid_request' ? 400 : 503).json({
        error: error.message,
      });
    }
    return res.status(503).json({ error: 'Financial health service unavailable.' });
  }
});

export default router;
