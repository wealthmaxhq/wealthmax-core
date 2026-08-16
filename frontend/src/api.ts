import axios from 'axios';

const api = axios.create({ baseURL: import.meta.env.VITE_API_BASE_URL || '' });

export const AUTH_EXPIRED_EVENT = 'wealthmax:auth-expired';

export interface User {
  id: string;
  email: string;
  name?: string;
}

export interface Goal {
  id: string;
  title: string;
  targetAmount: number;
  currentAmount: number;
  targetDate?: string;
  notes?: string;
  createdAt: string;
  updatedAt?: string;
}

export type GoalInput = Pick<Goal, 'title' | 'targetAmount' | 'currentAmount'>
  & Partial<Pick<Goal, 'targetDate' | 'notes'>>;

export interface AuthResponse {
  token: string;
  user: User;
}

export interface DecisionReportSummary {
  id: string;
  title: string;
  currency: string;
  schemaVersion: number;
  sourceFormulaId: string;
  createdAt: string;
  goalId?: string;
}

export interface DecisionReportSnapshot {
  schemaVersion: number;
  sourceReport: {
    formulaId: string;
    title: string;
    currency: string;
  };
  summary: {
    minimumSelectedValueCaseId: string;
    maximumSelectedValueCaseId: string;
    selectedRealValueRange: string;
    taxChangedSelectionCount: number;
    criticalWarningCaseCount: number;
  };
  cases: Array<{
    id: string;
    label: string;
    objective: string;
    selectedPrepaymentAllocationPercent: string;
    afterTaxFutureValue: string;
    realAfterTaxFutureValue: string;
    estimatedTax: string;
    selectionChangedByTax: boolean;
  }>;
  warnings: Array<{ code: string; message: string; severity: string }>;
}

export interface StoredDecisionReport extends DecisionReportSummary {
  report: DecisionReportSnapshot;
}

export interface FinancialHealthInput {
  currency: 'INR' | 'USD' | 'EUR';
  liquidSavings: string;
  monthlyNetIncome: string;
  monthlyEssentialExpenses: string;
  monthlyDebtPayments: string;
  monthlySavings: string;
}

export interface FinancialHealthResult {
  apiVersion: 'v1';
  score: number;
  rating: 'needsAttention' | 'fair' | 'good' | 'excellent';
  componentScores: {
    emergencyFund: number;
    debtBurden: number;
    savingsRate: number;
  };
  metrics: {
    emergencyFundMonths: string;
    debtToIncomePercent: string;
    savingsRatePercent: string;
  };
  findings: Array<'buildEmergencyFund' | 'reduceDebtBurden' | 'increaseSavingsRate'>;
}

export interface Recommendations {
  apiVersion: 'v1';
  savings: {
    totalMonthlyRequired: number;
    breakdown: Array<{ id: string; title: string; remaining: number; months: number; monthly: number }>;
  };
  allocation: {
    profile: 'Conservative' | 'Balanced' | 'Aggressive';
    allocation: { stocks: number; bonds: number; cash: number };
    reason: string;
  };
  generatedAt: string;
}

export interface PortfolioEntry {
  id: string;
  name: string;
  kind: 'asset' | 'liability';
  category: string;
  currency: 'INR' | 'USD' | 'EUR';
  value: number;
  createdAt: string;
  updatedAt: string;
}

export type PortfolioEntryInput = Pick<PortfolioEntry, 'name' | 'kind' | 'category' | 'currency' | 'value'>;

export interface PortfolioSummary {
  currency: PortfolioEntry['currency'];
  assets: number;
  liabilities: number;
  netWorth: number;
}

const savedToken = localStorage.getItem('token');
if (savedToken) setAuthToken(savedToken);

export function setAuthToken(token: string | null) {
  if (token) api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  else delete api.defaults.headers.common['Authorization'];
}

export function register(data: { email: string; password: string; name?: string }) {
  return api.post<AuthResponse>('/api/auth/register', data);
}

export function login(data: { email: string; password: string }) {
  return api.post<AuthResponse>('/api/auth/login', data);
}

export function getCurrentUser() {
  return api.get<{ user: User }>('/api/auth/me');
}

export function updateCurrentUser(name: string | null) {
  return api.patch<{ user: User }>('/api/auth/me', { name });
}

export function changePassword(data: { currentPassword: string; newPassword: string }) {
  return api.post<AuthResponse>('/api/auth/change-password', data);
}

export function deleteCurrentUser(password: string, confirmation: string) {
  return api.delete<void>('/api/auth/me', { data: { password, confirmation } });
}

export function listGoals() {
  return api.get<{ goals: Goal[] }>('/api/goals');
}

export function getRecommendations() {
  return api.get<{ recommendations: Recommendations }>('/api/v1/recommendations');
}

export function listPortfolio() {
  return api.get<{ apiVersion: 'v1'; entries: PortfolioEntry[]; summaries: PortfolioSummary[] }>('/api/v1/portfolio');
}

export function createPortfolioEntry(payload: PortfolioEntryInput) {
  return api.post<{ entry: PortfolioEntry }>('/api/v1/portfolio', payload);
}

export function updatePortfolioEntry(id: string, payload: PortfolioEntryInput) {
  return api.put<{ entry: PortfolioEntry }>(`/api/v1/portfolio/${id}`, payload);
}

export function deletePortfolioEntry(id: string) {
  return api.delete(`/api/v1/portfolio/${id}`);
}

export function createGoal(payload: GoalInput) {
  return api.post<{ goal: Goal }>('/api/goals', payload);
}

export function updateGoal(id: string, payload: Partial<GoalInput>) {
  return api.put<{ goal: Goal }>(`/api/goals/${id}`, payload);
}

export function deleteGoal(id: string) {
  return api.delete(`/api/goals/${id}`);
}

export function listDecisionReports() {
  return api.get<{ apiVersion: string; reports: DecisionReportSummary[] }>(
    '/api/v1/decision-reports',
  );
}

export function getDecisionReport(id: string) {
  return api.get<StoredDecisionReport & { apiVersion: string }>(
    `/api/v1/decision-reports/${id}`,
  );
}

export function createDecisionReport(payload: unknown) {
  return api.post<StoredDecisionReport & { apiVersion: string }>(
    '/api/v1/decision-reports',
    payload,
  );
}

export function deleteDecisionReport(id: string) {
  return api.delete(`/api/v1/decision-reports/${id}`);
}

export function updateDecisionReportGoal(id: string, goalId: string | null) {
  return api.patch<StoredDecisionReport & { apiVersion: string }>(
    `/api/v1/decision-reports/${id}/goal`,
    { goalId },
  );
}

export function exportDecisionReportCsv(id: string) {
  return api.get<Blob>(`/api/v1/decision-reports/${id}/export.csv`, {
    responseType: 'blob',
  });
}

export function calculateFinancialHealth(payload: FinancialHealthInput) {
  return api.post<FinancialHealthResult>('/api/v1/financial-health-score', payload);
}

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && localStorage.getItem('token')) {
      localStorage.removeItem('token');
      setAuthToken(null);
      window.dispatchEvent(new Event(AUTH_EXPIRED_EVENT));
    }
    return Promise.reject(error);
  },
);
