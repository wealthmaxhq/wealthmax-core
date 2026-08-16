import { Router } from 'express';
import { authMiddleware } from '../lib/jwt';
import {
  createPortfolioEntry,
  deletePortfolioEntry,
  listPortfolioEntries,
  listPortfolioHistory,
  PortfolioInput,
  portfolioSummary,
  updatePortfolioEntry,
} from '../lib/portfolio';
import { portfolioCsv, portfolioCsvFilename } from '../lib/portfolioCsv';

const router = Router();
router.use(authMiddleware);

function input(value: unknown): PortfolioInput {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Portfolio entry details are required.');
  }
  const body = value as Record<string, unknown>;
  if (typeof body.name !== 'string' || !body.name.trim() || body.name.trim().length > 120) {
    throw new Error('Name must contain 1 to 120 characters.');
  }
  if (body.kind !== 'asset' && body.kind !== 'liability') {
    throw new Error('Kind must be asset or liability.');
  }
  if (typeof body.category !== 'string' || !body.category.trim() || body.category.trim().length > 60) {
    throw new Error('Category must contain 1 to 60 characters.');
  }
  if (!['INR', 'USD', 'EUR'].includes(body.currency as string)) {
    throw new Error('Currency must be INR, USD, or EUR.');
  }
  if (typeof body.value !== 'number' || !Number.isFinite(body.value) || body.value < 0 || body.value > 1e15) {
    throw new Error('Value must be a non-negative number no greater than 1e15.');
  }
  return {
    name: body.name.trim(),
    kind: body.kind,
    category: body.category.trim(),
    currency: body.currency as PortfolioInput['currency'],
    value: body.value,
  };
}

router.get('/', (req: any, res) => {
  const entries = listPortfolioEntries(req.user.id);
  res.json({ apiVersion: 'v1', entries, summaries: portfolioSummary(entries) });
});

router.get('/history', (req: any, res) => {
  const currency = req.query.currency;
  const requestedLimit = req.query.limit === undefined ? 90 : Number(req.query.limit);
  if (!['INR', 'USD', 'EUR'].includes(currency as string)) {
    return res.status(400).json({ error: 'Currency must be INR, USD, or EUR.' });
  }
  if (!Number.isInteger(requestedLimit) || requestedLimit < 1 || requestedLimit > 365) {
    return res.status(400).json({ error: 'Limit must be an integer from 1 to 365.' });
  }
  return res.json({
    apiVersion: 'v1',
    currency,
    snapshots: listPortfolioHistory(req.user.id, currency, requestedLimit).reverse(),
  });
});

router.get('/export.csv', (req: any, res) => {
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${portfolioCsvFilename}"`);
  return res.send(portfolioCsv(listPortfolioEntries(req.user.id)));
});

router.post('/', (req: any, res) => {
  try {
    return res.status(201).json({ entry: createPortfolioEntry(req.user.id, input(req.body)) });
  } catch (error) {
    return res.status(400).json({ error: (error as Error).message });
  }
});

router.put('/:id', (req: any, res) => {
  try {
    const entry = updatePortfolioEntry(req.params.id, req.user.id, input(req.body));
    return entry ? res.json({ entry }) : res.status(404).json({ error: 'Not found' });
  } catch (error) {
    return res.status(400).json({ error: (error as Error).message });
  }
});

router.delete('/:id', (req: any, res) => {
  return deletePortfolioEntry(req.params.id, req.user.id)
    ? res.status(204).send()
    : res.status(404).json({ error: 'Not found' });
});

export default router;
