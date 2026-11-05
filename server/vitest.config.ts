import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Integration tests share one real PostgreSQL + Redis; run files serially.
    fileParallelism: false,
    testTimeout: 20000,
    hookTimeout: 30000,
  },
});
