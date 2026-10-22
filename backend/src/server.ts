import { app } from './app.js';
import { env } from './config/env.js';
import { logger } from './shared/utils/logger.js';
import { prisma } from './config/database.js';

const server = app.listen(env.PORT, '0.0.0.0', () => {
  logger.info(
    {
      port: env.PORT,
      host: '0.0.0.0',
      env: env.NODE_ENV,
      apiPrefix: env.API_PREFIX,
      docsUrl: `http://localhost:${env.PORT}/api/docs`,
    },
    'Idir Connect REST API server started successfully'
  );
});

// Graceful shutdown handling
const handleShutdown = async (signal: string) => {
  logger.info({ signal }, 'Shutdown signal received. Closing HTTP server and database connections...');
  server.close(async () => {
    logger.info('HTTP server closed');
    await prisma.$disconnect();
    logger.info('Database disconnected cleanly');
    process.exit(0);
  });

  setTimeout(() => {
    logger.error('Forced shutdown due to timeout');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));
