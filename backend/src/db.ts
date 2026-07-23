import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';

const DB_PATH = path.join(__dirname, '..', '..', 'data', 'db.sqlite');
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
const db = new Database(DB_PATH);

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
`);

export default db;
