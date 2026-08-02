import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import {
  createDecisionReport,
  DecisionReportBridgeError,
} from '../lib/decisionReports';

const router = Router();
router.use(authMiddleware);

router.post('/', async (req, res) => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return res.status(400).json({ error: 'A decision report object is required.' });
  }
  try {
    const report = await createDecisionReport(req.body);
    return res.status(201).json({ apiVersion: 'v1', report });
  } catch (error) {
    if (error instanceof DecisionReportBridgeError) {
      const status = error.kind === 'invalid_request' ? 400 : 503;
      return res.status(status).json({ error: error.message });
    }
    return res.status(503).json({ error: 'Decision report service unavailable.' });
  }
});

export default router;
