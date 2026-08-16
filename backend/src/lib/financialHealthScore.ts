import { spawn } from 'child_process';
import path from 'path';

const maximumOutputBytes = 64 * 1024;
const bridgeTimeoutMilliseconds = 10_000;

export class FinancialHealthBridgeError extends Error {
  constructor(
    message: string,
    readonly kind: 'invalid_request' | 'unavailable',
  ) {
    super(message);
  }
}
export function calculateFinancialHealthScore(input: unknown): Promise<unknown> {
  const repositoryRoot = path.resolve(__dirname, '..', '..', '..');
  const configuredExecutable = process.env.DART_EXECUTABLE;
  if (process.platform === 'win32' && !configuredExecutable) {
    return Promise.reject(new FinancialHealthBridgeError(
      'DART_EXECUTABLE must point to dart.exe on Windows.',
      'unavailable',
    ));
  }
  const child = spawn(configuredExecutable || 'dart', [
    'run',
    'bin/financial_health_score_bridge.dart',
  ], { cwd: repositoryRoot, stdio: ['pipe', 'pipe', 'pipe'] });

  return new Promise((resolve, reject) => {
    let stdout = '';
    let stderr = '';
    let outputBytes = 0;
    let settled = false;
    const finish = (callback: () => void) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      callback();
    };
    const timeout = setTimeout(() => {
      child.kill();
      finish(() => reject(new FinancialHealthBridgeError(
        'Financial health calculation timed out.',
        'unavailable',
      )));
    }, bridgeTimeoutMilliseconds);
    child.stdout.on('data', (chunk: Buffer) => {
      outputBytes += chunk.length;
      if (outputBytes > maximumOutputBytes) {
        child.kill();
        finish(() => reject(new FinancialHealthBridgeError(
          'Financial health output exceeded the service limit.',
          'unavailable',
        )));
        return;
      }
      stdout += chunk.toString('utf8');
    });
    child.stderr.on('data', (chunk: Buffer) => { stderr += chunk.toString('utf8'); });
    child.on('error', (error) => finish(() => reject(
      new FinancialHealthBridgeError(
        `Financial health engine could not start: ${error.message}`,
        'unavailable',
      ),
    )));
    child.on('close', (code) => finish(() => {
      if (code !== 0) {
        let message = 'Financial health input was invalid.';
        try {
          const failure = JSON.parse(stderr) as { message?: unknown };
          if (typeof failure.message === 'string') message = failure.message;
        } catch { /* Keep the stable public error. */ }
        reject(new FinancialHealthBridgeError(message, 'invalid_request'));
        return;
      }
      try {
        resolve(JSON.parse(stdout));
      } catch {
        reject(new FinancialHealthBridgeError(
          'Financial health engine returned an invalid response.',
          'unavailable',
        ));
      }
    }));
    child.stdin.end(JSON.stringify(input));
  });
}
