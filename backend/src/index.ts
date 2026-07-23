import express from 'express';
const app = express();
app.get('/health', (req, res) => res.json({status: 'ok'}));
app.get('/', (req, res) => res.send('Wealth Planner API'));
const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server listening on ${port}`));
