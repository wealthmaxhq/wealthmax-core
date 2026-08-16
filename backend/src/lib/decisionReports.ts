import { spawn } from 'child_process';
import path from 'path';

const maximumOutputBytes = 2 * 1024 * 1024;
const bridgeTimeoutMilliseconds = 60_000;

export class DecisionReportBridgeError extends Error {
  constructor(
    message: string,
    readonly kind: 'invalid_request' | 'unavailable',
  ) {
    super(message);
  }
}

export function createDecisionReport(report: unknown): Promise<unknown> {
  const repositoryRoot = path.resolve(__dirname, '..', '..', '..');
  const configuredExecutable = process.env.DART_EXECUTABLE;
  if (process.platform === 'win32' && !configuredExecutable) {
    return Promise.reject(
      new DecisionReportBridgeError(
        'DART_EXECUTABLE must point to dart.exe on Windows.',
        'unavailable',
      ),
    );
  }
  const dartExecutable = configuredExecutable || 'dart';
  const child = spawn(
    dartExecutable,
    ['run', 'bin/decision_report_bridge.dart'],
    {
      cwd: repositoryRoot,
      stdio: ['pipe', 'pipe', 'pipe'],
    },
  );
  const request = JSON.stringify({
    calculatedAt: new Date().toISOString(),
    report,
  });

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
      finish(() =>
        reject(
          new DecisionReportBridgeError(
            'Decision report calculation timed out.',
            'unavailable',
          ),
        ),
      );
    }, bridgeTimeoutMilliseconds);

    child.stdout.on('data', (chunk: Buffer) => {
      outputBytes += chunk.length;
      if (outputBytes > maximumOutputBytes) {
        child.kill();
        finish(() =>
          reject(
            new DecisionReportBridgeError(
              'Decision report output exceeded the service limit.',
              'unavailable',
            ),
          ),
        );
        return;
      }
      stdout += chunk.toString('utf8');
    });
    child.stderr.on('data', (chunk: Buffer) => {
      stderr += chunk.toString('utf8');
    });
    child.on('error', (error) => {
      finish(() =>
        reject(
          new DecisionReportBridgeError(
            `Decision report engine could not start: ${error.message}`,
            'unavailable',
          ),
        ),
      );
    });
    child.on('close', (code) => {
      finish(() => {
        if (code !== 0) {
          let message = 'Decision report input was invalid.';
          try {
            const failure = JSON.parse(stderr) as { message?: unknown };
            if (typeof failure.message === 'string') message = failure.message;
          } catch {
            // Keep the stable public error when the bridge emits no JSON.
          }
          reject(new DecisionReportBridgeError(message, 'invalid_request'));
          return;
        }
        try {
          resolve(JSON.parse(stdout));
        } catch {
          reject(
            new DecisionReportBridgeError(
              'Decision report engine returned an invalid response.',
              'unavailable',
            ),
          );
        }
      });
    });

    child.stdin.end(request);
  });
}
