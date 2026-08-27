import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    // Process forks intermittently fail to start on constrained Windows hosts,
    // while concurrent jsdom workers make interaction tests miss their timeout.
    // One thread is deterministic locally and remains isolated from the app build.
    pool: 'threads',
    minWorkers: 1,
    maxWorkers: 1,
    setupFiles: ['./src/test/setup.ts'],
  },
});
