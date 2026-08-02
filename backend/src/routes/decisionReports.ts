import { Request, Router } from 'express';
import { authMiddleware, AuthenticatedRequest } from '../lib/jwt';
import {
  createDecisionReport,
  DecisionReportBridgeError,
} from '../lib/decisionReports';
import {
  deleteDecisionReport,
  getDecisionReport,
  listDecisionReports,
  storeDecisionReport,
} from '../lib/storedDecisionReports';
import {
  decisionReportCsv,
  decisionReportCsvFilename,
} from '../lib/decisionReportCsv';
import { getGoalById } from '../lib/goals';

const router = Router();
router.use(authMiddleware);

function userId(req: Request): string {
  return (req as AuthenticatedRequest).user!.id;
}

router.get('/', (req, res) => {
  return res.json({
    apiVersion: 'v1',
    reports: listDecisionReports(userId(req)),
  });
});

router.post('/', async (req, res) => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return res.status(400).json({ error: 'A decision report object is required.' });
  }
  const requestedGoalId = (req.body as Record<string, unknown>).goalId;
  if (requestedGoalId !== undefined) {
    if (typeof requestedGoalId !== 'string' || !requestedGoalId.trim()) {
      return res.status(400).json({ error: 'goalId must be a non-empty string.' });
    }
    const goal = getGoalById(requestedGoalId);
    if (!goal || goal.userId !== userId(req)) {
      return res.status(400).json({ error: 'Linked goal was not found.' });
    }
  }
  try {
    const report = await createDecisionReport(req.body);
    const stored = storeDecisionReport(
      userId(req),
      report,
      typeof requestedGoalId === 'string' ? requestedGoalId : undefined,
    );
    return res.status(201).json({ apiVersion: 'v1', ...stored });
  } catch (error) {
    if (error instanceof DecisionReportBridgeError) {
      const status = error.kind === 'invalid_request' ? 400 : 503;
      return res.status(status).json({ error: error.message });
    }
    return res.status(503).json({ error: 'Decision report service unavailable.' });
  }
});

router.get('/:id/export.csv', (req, res) => {
  const stored = getDecisionReport(req.params.id, userId(req));
  if (!stored) return res.status(404).json({ error: 'Not found' });
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${decisionReportCsvFilename(stored.title)}"`,
  );
  return res.send(decisionReportCsv(stored));
});

router.get('/:id', (req, res) => {
  const stored = getDecisionReport(req.params.id, userId(req));
  if (!stored) return res.status(404).json({ error: 'Not found' });
  return res.json({ apiVersion: 'v1', ...stored });
});

router.delete('/:id', (req, res) => {
  if (!deleteDecisionReport(req.params.id, userId(req))) {
    return res.status(404).json({ error: 'Not found' });
  }
  return res.status(204).send();
});

export default router;
