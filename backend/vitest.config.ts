import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 20000,
    hookTimeout: 20000,
    env: {
      NODE_ENV: 'test',
      DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/idir_test?schema=public',
      JWT_ACCESS_SECRET: 'test-jwt-access-secret-min-32-chars-super-secure-key',
      JWT_REFRESH_SECRET: 'test-jwt-refresh-secret-min-32-chars-super-secure-key',
    },
  },
});
