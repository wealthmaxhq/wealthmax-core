import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';

const DB_PATH = path.join(__dirname, '..', '..', 'data', 'db.sqlite');
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
const db = new Database(DB_PATH);
db.pragma('foreign_keys = ON');

// Users table
db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  passwordHash TEXT NOT NULL,
  name TEXT,
  createdAt TEXT NOT NULL
);
`);

// Goals table
db.exec(`
CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY,
  userId TEXT NOT NULL,
  title TEXT NOT NULL,
  targetAmount REAL DEFAULT 0,
  currentAmount REAL DEFAULT 0,
  targetDate TEXT,
  notes TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT
);

CREATE TABLE IF NOT EXISTS decision_reports (
  id TEXT PRIMARY KEY,
  userId TEXT NOT NULL,
  goalId TEXT,
  title TEXT NOT NULL,
  currency TEXT NOT NULL,
  schemaVersion INTEGER NOT NULL,
  sourceFormulaId TEXT NOT NULL,
  snapshotJson TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
);
`);

const decisionReportColumns = db.pragma(
  'table_info(decision_reports)',
) as Array<{ name: string }>;
if (!decisionReportColumns.some((column) => column.name === 'goalId')) {
  db.exec('ALTER TABLE decision_reports ADD COLUMN goalId TEXT');
}

db.exec(`
CREATE INDEX IF NOT EXISTS idx_decision_reports_user_created
ON decision_reports (userId, createdAt DESC);
CREATE INDEX IF NOT EXISTS idx_decision_reports_goal
ON decision_reports (userId, goalId, createdAt DESC);
`);

export default db;
