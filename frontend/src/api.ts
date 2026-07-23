import axios from 'axios';

const api = axios.create({ baseURL: import.meta.env.VITE_API_BASE_URL || '' });

export function setAuthToken(token: string | null) {
  if (token) api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  else delete api.defaults.headers.common['Authorization'];
}

export function register(data: { email: string; password: string; name?: string }) {
  return api.post('/api/auth/register', data);
}

export function login(data: { email: string; password: string }) {
  return api.post('/api/auth/login', data);
}

export function listGoals() {
  return api.get('/api/goals');
}

export function createGoal(payload: any) {
  return api.post('/api/goals', payload);
}
