import express from 'express';
import authRouter from './routes/auth';
import goalsRouter from './routes/goals';
import decisionReportsRouter from './routes/decisionReports';
import { openApiDocument } from './openapi';
import financialHealthRouter from './routes/financialHealth';

const app = express();
app.use(express.json());
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.get('/openapi.json', (req, res) => res.json(openApiDocument));
app.use('/api/auth', authRouter);
app.use('/api/goals', goalsRouter);
app.use('/api/v1/decision-reports', decisionReportsRouter);
app.use('/api/v1/financial-health-score', financialHealthRouter);

export default app;
