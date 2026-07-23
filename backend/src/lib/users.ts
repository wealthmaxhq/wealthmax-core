import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

const DATA_FILE = path.join(__dirname, '..', '..', 'data', 'users.json');

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  name?: string;
  createdAt: string;
}

function readUsers(): User[] {
  try {
    const raw = fs.readFileSync(DATA_FILE, 'utf-8');
    return JSON.parse(raw) as User[];
  } catch (e) {
    return [];
  }
}

function writeUsers(users: User[]) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(users, null, 2));
}

export function findUserByEmail(email: string): User | undefined {
  const users = readUsers();
  return users.find(u => u.email.toLowerCase() === email.toLowerCase());
}

export function findUserById(id: string): User | undefined {
  const users = readUsers();
  return users.find(u => u.id === id);
}

export function createUser(email: string, passwordHash: string, name?: string): User {
  const users = readUsers();
  const user: User = { id: uuidv4(), email, passwordHash, name, createdAt: new Date().toISOString() };
  users.push(user);
  writeUsers(users);
  return user;
}
