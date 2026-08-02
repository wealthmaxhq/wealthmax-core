import express from 'express';
import authRouter from './routes/auth';
import goalsRouter from './routes/goals';
import decisionReportsRouter from './routes/decisionReports';

const app = express();
app.use(express.json());
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.use('/api/auth', authRouter);
app.use('/api/goals', goalsRouter);
app.use('/api/v1/decision-reports', decisionReportsRouter);

export default app;
