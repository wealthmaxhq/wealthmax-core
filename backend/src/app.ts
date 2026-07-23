import express from 'express';
import authRouter from './routes/auth';
import goalsRouter from './routes/goals';
import recommendationsRouter from './routes/recommendations';

const app = express();
app.use(express.json());
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.use('/api/auth', authRouter);
app.use('/api/goals', goalsRouter);
app.use('/api/recommendations', recommendationsRouter);

export default app;
