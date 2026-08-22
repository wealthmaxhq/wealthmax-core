import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import {
  calculateFinancialHealthScore,
  FinancialHealthBridgeError,
} from '../lib/financialHealthScore';
import { listFinancialHealthSnapshots, saveFinancialHealthSnapshot } from '../lib/financialHealthHistory';

const router = Router();
router.use(authMiddleware);

router.get('/history', (req: any, res) => {
  const requestedLimit = req.query.limit === undefined ? 12 : Number(req.query.limit);
  if (!Number.isInteger(requestedLimit) || requestedLimit < 1 || requestedLimit > 100) {
    return res.status(400).json({ error: 'Limit must be an integer from 1 to 100.' });
  }
  return res.json({
    apiVersion: 'v1',
    snapshots: listFinancialHealthSnapshots(req.user.id, requestedLimit),
  });
});

router.post('/', async (req: any, res) => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return res.status(400).json({ error: 'Financial health input is required.' });
  }
  try {
    const result = await calculateFinancialHealthScore(req.body) as { score: number; rating: string };
    saveFinancialHealthSnapshot(req.user.id, req.body.currency, result);
    return res.json(result);
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
