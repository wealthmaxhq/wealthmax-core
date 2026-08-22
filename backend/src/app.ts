import express from 'express';
import authRouter from './routes/auth';
import goalsRouter from './routes/goals';
import recommendationsRouter from './routes/recommendations';
import decisionReportsRouter from './routes/decisionReports';
import { openApiDocument } from './openapi';
import financialHealthRouter from './routes/financialHealth';
import { jsonParseErrorHandler, secureResponseHeaders } from './lib/httpSecurity';
import portfolioRouter from './routes/portfolio';
import db from './db';

const app = express();
app.disable('x-powered-by');
app.use(secureResponseHeaders);
app.use(express.json({ limit: 64 * 1024, strict: true }));
app.use(jsonParseErrorHandler);
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.get('/ready', (req, res) => {
  try {
    db.prepare('SELECT 1').get();
    return res.json({ status: 'ready', database: 'available' });
  } catch {
    return res.status(503).json({ status: 'unavailable', database: 'unavailable' });
  }
});
app.get('/openapi.json', (req, res) => res.json(openApiDocument));
app.use('/api/auth', authRouter);
app.use('/api/goals', goalsRouter);
app.use('/api/v1/recommendations', recommendationsRouter);
app.use('/api/v1/decision-reports', decisionReportsRouter);
app.use('/api/v1/financial-health-score', financialHealthRouter);
app.use('/api/v1/portfolio', portfolioRouter);

export default app;
