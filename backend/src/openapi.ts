const json = { 'application/json': {} };

const errorResponses = {
  400: { description: 'Invalid request', content: json },
  401: { description: 'Missing or invalid bearer token', content: json },
  404: { description: 'Resource not found', content: json },
  429: { description: 'Authentication rate limit exceeded', content: json },
};

const bearerSecurity = [{ bearerAuth: [] }];

export const openApiDocument = {
  openapi: '3.1.0',
  info: {
    title: 'WealthMax API',
    version: '1.0.0',
    description: 'Authenticated goals and financial decision-report API for WealthMax Pro.',
  },
  servers: [{ url: '/', description: 'Current server' }],
  tags: [
    { name: 'System' },
    { name: 'Authentication' },
    { name: 'Goals' },
    { name: 'Recommendations' },
    { name: 'Decision reports' },
    { name: 'Financial health' },
    { name: 'Portfolio' },
  ],
  paths: {
    '/openapi.json': {
      get: {
        tags: ['System'],
        summary: 'Get the OpenAPI contract',
        operationId: 'getOpenApiDocument',
        responses: { 200: { description: 'OpenAPI 3.1 document', content: json } },
      },
    },
    '/health': {
      get: {
        tags: ['System'],
        summary: 'Check service health',
        operationId: 'getHealth',
        responses: { 200: { description: 'Service is healthy', content: json } },
      },
    },
    '/ready': {
      get: {
        tags: ['System'],
        summary: 'Check service and database readiness',
        operationId: 'getReadiness',
        responses: {
          200: { description: 'Service is ready to receive traffic', content: json },
          503: { description: 'Required database is unavailable', content: json },
        },
      },
    },
    '/api/auth/register': {
      post: {
        tags: ['Authentication'],
        summary: 'Register an account',
        operationId: 'registerUser',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { $ref: '#/components/schemas/RegisterInput' } } },
        },
        responses: {
          200: { description: 'Account created', content: { 'application/json': { schema: { $ref: '#/components/schemas/AuthResponse' } } } },
          400: errorResponses[400],
          429: errorResponses[429],
        },
      },
    },
    '/api/auth/login': {
      post: {
        tags: ['Authentication'],
        summary: 'Sign in',
        operationId: 'loginUser',
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { $ref: '#/components/schemas/LoginInput' } } },
        },
        responses: {
          200: { description: 'Authenticated', content: { 'application/json': { schema: { $ref: '#/components/schemas/AuthResponse' } } } },
          400: errorResponses[400],
          429: errorResponses[429],
        },
      },
    },
    '/api/auth/me': {
      get: {
        tags: ['Authentication'], summary: 'Get the current account', operationId: 'getCurrentUser', security: bearerSecurity,
        responses: { 200: { description: 'Current account', content: json }, 401: errorResponses[401] },
      },
      patch: {
        tags: ['Authentication'], summary: 'Update the current account', operationId: 'updateCurrentUser', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['name'], properties: { name: { type: ['string', 'null'], maxLength: 100 } } } } } },
        responses: { 200: { description: 'Account updated', content: json }, ...errorResponses },
      },
      delete: {
        tags: ['Authentication'], summary: 'Permanently delete the current account and owned data', operationId: 'deleteCurrentUser', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/DeleteAccountInput' } } } },
        responses: { 204: { description: 'Account and owned data deleted' }, 400: errorResponses[400], 401: errorResponses[401], 404: errorResponses[404] },
      },
    },
    '/api/auth/change-password': {
      post: {
        tags: ['Authentication'], summary: 'Change the current password', operationId: 'changePassword', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/ChangePasswordInput' } } } },
        responses: { 200: { description: 'Password changed and replacement session issued', content: { 'application/json': { schema: { $ref: '#/components/schemas/AuthResponse' } } } }, 400: errorResponses[400], 401: errorResponses[401] },
      },
    },
    '/api/goals': {
      get: {
        tags: ['Goals'], summary: 'List goals', operationId: 'listGoals', security: bearerSecurity,
        responses: { 200: { description: 'Goal collection', content: json }, 401: errorResponses[401] },
      },
      post: {
        tags: ['Goals'], summary: 'Create a goal', operationId: 'createGoal', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/GoalInput' } } } },
        responses: { 201: { description: 'Goal created', content: json }, 400: errorResponses[400], 401: errorResponses[401] },
      },
    },
    '/api/goals/{id}': {
      parameters: [{ $ref: '#/components/parameters/ResourceId' }],
      get: {
        tags: ['Goals'], summary: 'Get a goal', operationId: 'getGoal', security: bearerSecurity,
        responses: { 200: { description: 'Goal', content: json }, 401: errorResponses[401], 404: errorResponses[404] },
      },
      put: {
        tags: ['Goals'], summary: 'Update a goal', operationId: 'updateGoal', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/GoalInput' } } } },
        responses: { 200: { description: 'Goal updated', content: json }, ...errorResponses },
      },
      delete: {
        tags: ['Goals'], summary: 'Delete a goal', operationId: 'deleteGoal', security: bearerSecurity,
        responses: { 204: { description: 'Goal deleted' }, 401: errorResponses[401], 404: errorResponses[404] },
      },
    },
    '/api/v1/decision-reports': {
      get: {
        tags: ['Decision reports'], summary: 'List decision reports', operationId: 'listDecisionReports', security: bearerSecurity,
        responses: { 200: { description: 'Report summaries', content: json }, 401: errorResponses[401] },
      },
      post: {
        tags: ['Decision reports'], summary: 'Calculate and store a decision report', operationId: 'createDecisionReport', security: bearerSecurity,
        description: 'Financial decimal values are JSON strings so precision is preserved across runtimes.',
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/DecisionReportInput' } } } },
        responses: { 201: { description: 'Report calculated and stored', content: json }, 400: errorResponses[400], 401: errorResponses[401], 503: { description: 'Calculation engine unavailable', content: json } },
      },
    },
    '/api/v1/recommendations': {
      get: {
        tags: ['Recommendations'], summary: 'Get goal-based savings and allocation guidance', operationId: 'getRecommendations', security: bearerSecurity,
        description: 'Returns a monthly savings target and a simple time-horizon allocation heuristic based only on the authenticated user goals.',
        responses: { 200: { description: 'Current planning recommendations', content: json }, 401: errorResponses[401] },
      },
    },
    '/api/v1/financial-health-score': {
      post: {
        tags: ['Financial health'], summary: 'Calculate a financial health score', operationId: 'calculateFinancialHealthScore', security: bearerSecurity,
        description: 'All monetary values are decimal strings in the declared currency.',
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/FinancialHealthScoreInput' } } } },
        responses: { 200: { description: 'Transparent 0-100 score and findings', content: json }, 400: errorResponses[400], 401: errorResponses[401], 503: { description: 'Calculation engine unavailable', content: json } },
      },
    },
    '/api/v1/financial-health-score/history': {
      get: {
        tags: ['Financial health'], summary: 'List financial health score history', operationId: 'listFinancialHealthScoreHistory', security: bearerSecurity,
        parameters: [{ name: 'limit', in: 'query', schema: { type: 'integer', minimum: 1, maximum: 100, default: 12 } }],
        responses: { 200: { description: 'Chronological financial health snapshots', content: json }, 400: errorResponses[400], 401: errorResponses[401] },
      },
    },
    '/api/v1/portfolio': {
      get: {
        tags: ['Portfolio'], summary: 'List portfolio entries and currency summaries', operationId: 'listPortfolio', security: bearerSecurity,
        responses: { 200: { description: 'Portfolio entries and per-currency net worth', content: json }, 401: errorResponses[401] },
      },
      post: {
        tags: ['Portfolio'], summary: 'Create a portfolio entry', operationId: 'createPortfolioEntry', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/PortfolioEntryInput' } } } },
        responses: { 201: { description: 'Portfolio entry created', content: json }, 400: errorResponses[400], 401: errorResponses[401] },
      },
    },
    '/api/v1/portfolio/{id}': {
      parameters: [{ $ref: '#/components/parameters/ResourceId' }],
      put: {
        tags: ['Portfolio'], summary: 'Replace a portfolio entry', operationId: 'updatePortfolioEntry', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { $ref: '#/components/schemas/PortfolioEntryInput' } } } },
        responses: { 200: { description: 'Portfolio entry updated', content: json }, ...errorResponses },
      },
      delete: {
        tags: ['Portfolio'], summary: 'Delete a portfolio entry', operationId: 'deletePortfolioEntry', security: bearerSecurity,
        responses: { 204: { description: 'Portfolio entry deleted' }, 401: errorResponses[401], 404: errorResponses[404] },
      },
    },
    '/api/v1/portfolio/history': {
      get: {
        tags: ['Portfolio'], summary: 'Get portfolio net-worth history', operationId: 'getPortfolioHistory', security: bearerSecurity,
        parameters: [{ name: 'currency', in: 'query', required: true, schema: { type: 'string', enum: ['INR', 'USD', 'EUR'] } }, { name: 'limit', in: 'query', schema: { type: 'integer', minimum: 1, maximum: 365, default: 90 } }],
        responses: { 200: { description: 'Chronological per-currency portfolio snapshots', content: json }, 400: errorResponses[400], 401: errorResponses[401] },
      },
    },
    '/api/v1/portfolio/export.csv': {
      get: {
        tags: ['Portfolio'], summary: 'Export portfolio entries as CSV', operationId: 'exportPortfolioCsv', security: bearerSecurity,
        responses: { 200: { description: 'Excel-compatible UTF-8 CSV', content: { 'text/csv': { schema: { type: 'string' } } } }, 401: errorResponses[401] },
      },
    },
    '/api/v1/decision-reports/{id}': {
      parameters: [{ $ref: '#/components/parameters/ResourceId' }],
      get: {
        tags: ['Decision reports'], summary: 'Get a decision report', operationId: 'getDecisionReport', security: bearerSecurity,
        responses: { 200: { description: 'Stored report snapshot', content: json }, 401: errorResponses[401], 404: errorResponses[404] },
      },
      delete: {
        tags: ['Decision reports'], summary: 'Delete a decision report', operationId: 'deleteDecisionReport', security: bearerSecurity,
        responses: { 204: { description: 'Report deleted' }, 401: errorResponses[401], 404: errorResponses[404] },
      },
    },
    '/api/v1/decision-reports/{id}/goal': {
      parameters: [{ $ref: '#/components/parameters/ResourceId' }],
      patch: {
        tags: ['Decision reports'], summary: 'Link or unlink a report goal', operationId: 'updateDecisionReportGoal', security: bearerSecurity,
        requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['goalId'], properties: { goalId: { type: ['string', 'null'] } } } } } },
        responses: { 200: { description: 'Report goal updated', content: json }, ...errorResponses },
      },
    },
    '/api/v1/decision-reports/{id}/export.csv': {
      parameters: [{ $ref: '#/components/parameters/ResourceId' }],
      get: {
        tags: ['Decision reports'], summary: 'Export a decision report as CSV', operationId: 'exportDecisionReportCsv', security: bearerSecurity,
        responses: { 200: { description: 'Excel-compatible UTF-8 CSV', content: { 'text/csv': { schema: { type: 'string' } } } }, 401: errorResponses[401], 404: errorResponses[404] },
      },
    },
  },
  components: {
    securitySchemes: {
      bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
    },
    parameters: {
      ResourceId: { name: 'id', in: 'path', required: true, schema: { type: 'string', format: 'uuid' } },
    },
    schemas: {
      RegisterInput: {
        type: 'object', required: ['email', 'password'], additionalProperties: false,
        properties: { email: { type: 'string', format: 'email' }, password: { type: 'string', minLength: 8, maxLength: 128 }, name: { type: 'string', maxLength: 100 } },
      },
      LoginInput: {
        type: 'object', required: ['email', 'password'], additionalProperties: false,
        properties: { email: { type: 'string', format: 'email' }, password: { type: 'string', minLength: 1, maxLength: 128 } },
      },
      ChangePasswordInput: {
        type: 'object', required: ['currentPassword', 'newPassword'], additionalProperties: false,
        properties: { currentPassword: { type: 'string', minLength: 1, maxLength: 128 }, newPassword: { type: 'string', minLength: 8, maxLength: 128 } },
      },
      DeleteAccountInput: {
        type: 'object', required: ['password', 'confirmation'], additionalProperties: false,
        properties: { password: { type: 'string', minLength: 1, maxLength: 128 }, confirmation: { type: 'string', const: 'DELETE' } },
      },
      User: {
        type: 'object', required: ['id', 'email'], properties: { id: { type: 'string', format: 'uuid' }, email: { type: 'string', format: 'email' }, name: { type: 'string' } },
      },
      AuthResponse: {
        type: 'object', required: ['token', 'user'], properties: { token: { type: 'string' }, user: { $ref: '#/components/schemas/User' } },
      },
      GoalInput: {
        type: 'object', additionalProperties: false,
        properties: { title: { type: 'string', minLength: 1, maxLength: 120 }, targetAmount: { type: 'number', minimum: 0 }, currentAmount: { type: 'number', minimum: 0 }, targetDate: { type: 'string', format: 'date' }, notes: { type: 'string', maxLength: 2000 } },
      },
      DecisionReportInput: {
        type: 'object', required: ['title', 'cases'],
        properties: { title: { type: 'string' }, goalId: { type: 'string', format: 'uuid' }, cases: { type: 'array', minItems: 1, items: { type: 'object', additionalProperties: true } } },
      },
      FinancialHealthScoreInput: {
        type: 'object', required: ['currency', 'liquidSavings', 'monthlyNetIncome', 'monthlyEssentialExpenses', 'monthlyDebtPayments', 'monthlySavings'], additionalProperties: false,
        properties: {
          currency: { type: 'string', enum: ['INR', 'USD', 'EUR'] },
          liquidSavings: { type: 'string', pattern: '^-?[0-9]+(?:\\.[0-9]+)?$' },
          monthlyNetIncome: { type: 'string', pattern: '^-?[0-9]+(?:\\.[0-9]+)?$' },
          monthlyEssentialExpenses: { type: 'string', pattern: '^-?[0-9]+(?:\\.[0-9]+)?$' },
          monthlyDebtPayments: { type: 'string', pattern: '^-?[0-9]+(?:\\.[0-9]+)?$' },
          monthlySavings: { type: 'string', pattern: '^-?[0-9]+(?:\\.[0-9]+)?$' },
        },
      },
      PortfolioEntryInput: {
        type: 'object', required: ['name', 'kind', 'category', 'currency', 'value'], additionalProperties: false,
        properties: { name: { type: 'string', minLength: 1, maxLength: 120 }, kind: { type: 'string', enum: ['asset', 'liability'] }, category: { type: 'string', minLength: 1, maxLength: 60 }, currency: { type: 'string', enum: ['INR', 'USD', 'EUR'] }, value: { type: 'number', minimum: 0, maximum: 1e15 } },
      },
    },
  },
} as const;
