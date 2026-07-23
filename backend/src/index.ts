import express from 'express';
import authRouter from './routes/auth';
import goalsRouter from './routes/goals';

const app = express();
app.use(express.json());
app.get('/health', (req, res) => res.json({status: 'ok'}));
app.use('/api/auth', authRouter);
app.use('/api/goals', goalsRouter);
app.get('/', (req, res) => res.send('Wealth Planner API'));
const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server listening on ${port}`));
