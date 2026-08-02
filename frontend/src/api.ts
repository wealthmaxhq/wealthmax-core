import axios from 'axios';

const api = axios.create({ baseURL: import.meta.env.VITE_API_BASE_URL || '' });

export interface DecisionReportSummary {
  id: string;
  title: string;
  currency: string;
  schemaVersion: number;
  sourceFormulaId: string;
  createdAt: string;
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

const savedToken = localStorage.getItem('token');
if (savedToken) setAuthToken(savedToken);

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
