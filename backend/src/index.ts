import app from './app';
import db from './db';

const port = process.env.PORT || 3000;
const server = app.listen(port, () => console.log(`Server listening on ${port}`));

let shuttingDown = false;
function shutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`${signal} received; shutting down.`);
  const forcedExit = setTimeout(() => process.exit(1), 10_000);
  forcedExit.unref();
  server.close(() => {
    clearTimeout(forcedExit);
    db.close();
    process.exit(0);
  });
}

process.once('SIGTERM', () => shutdown('SIGTERM'));
process.once('SIGINT', () => shutdown('SIGINT'));
