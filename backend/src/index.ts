import { createApp } from './app';
import { prisma } from './config/prisma';
import { env } from './config/env';
import { logger } from './utils/logger';

async function bootstrap() {
  // Verify database connection
  try {
    await prisma.$connect();
    logger.info('✅  Database connected');
  } catch (err) {
    logger.error('❌  Database connection failed', { err });
    process.exit(1);
  }

  const app = createApp();

  const server = app.listen(env.PORT, () => {
    logger.info(`🚀  MyTransport API running on http://localhost:${env.PORT}${env.API_PREFIX}`);
    logger.info(`📦  Environment: ${env.NODE_ENV}`);
  });

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    logger.info(`${signal} received — shutting down gracefully`);
    server.close(async () => {
      await prisma.$disconnect();
      logger.info('Server closed');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

bootstrap().catch((err) => {
  console.error('Fatal error during startup', err);
  process.exit(1);
});
