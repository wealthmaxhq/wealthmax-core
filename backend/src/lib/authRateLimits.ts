import { Request } from 'express';
import {
  ipKeyGenerator,
  MemoryStore,
  rateLimit,
} from 'express-rate-limit';

const loginWindowMilliseconds = 15 * 60 * 1000;
const registrationWindowMilliseconds = 60 * 60 * 1000;

const registrationStore = new MemoryStore();
const loginIpStore = new MemoryStore();
const loginAccountStore = new MemoryStore();

const publicMessage = {
  error: 'Too many authentication attempts. Please try again later.',
};

function clientKey(request: Request): string {
  return ipKeyGenerator(request.ip || 'unknown');
}

function accountKey(request: Request): string {
  const email = request.body?.email;
  if (typeof email === 'string') {
    const normalized = email.trim().toLowerCase();
    if (normalized && normalized.length <= 254) return `account:${normalized}`;
  }
  return `client:${clientKey(request)}`;
}

const sharedOptions = {
  standardHeaders: 'draft-7' as const,
  legacyHeaders: false,
  message: publicMessage,
  passOnStoreError: false,
};

export const registrationRateLimit = rateLimit({
  ...sharedOptions,
  identifier: 'registration',
  windowMs: registrationWindowMilliseconds,
  limit: 10,
  keyGenerator: clientKey,
  store: registrationStore,
});

export const loginIpRateLimit = rateLimit({
  ...sharedOptions,
  identifier: 'login-ip',
  windowMs: loginWindowMilliseconds,
  limit: 30,
  keyGenerator: clientKey,
  skipSuccessfulRequests: true,
  store: loginIpStore,
});

export const loginAccountRateLimit = rateLimit({
  ...sharedOptions,
  identifier: 'login-account',
  windowMs: loginWindowMilliseconds,
  limit: 10,
  keyGenerator: accountKey,
  skipSuccessfulRequests: true,
  store: loginAccountStore,
});

export async function resetAuthRateLimits(): Promise<void> {
  await Promise.all([
    registrationStore.resetAll(),
    loginIpStore.resetAll(),
    loginAccountStore.resetAll(),
  ]);
}
