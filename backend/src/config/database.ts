import { PrismaClient } from '@prisma/client';
import { logger } from '../shared/utils/logger.js';
import { env } from './env.js';

declare global {
  // eslint-disable-next-line no-var
  var prismaGlobal: PrismaClient | undefined;
}

export const prisma =
  globalThis.prismaGlobal ??
  new PrismaClient({
    log:
      env.NODE_ENV === 'development'
        ? [
            { emit: 'event', level: 'query' },
            { emit: 'event', level: 'error' },
            { emit: 'event', level: 'info' },
            { emit: 'event', level: 'warn' },
          ]
        : [{ emit: 'event', level: 'error' }],
  });

if (env.NODE_ENV === 'development') {
  // @ts-expect-error Prisma query event typing
  prisma.$on('query', (e: { query: string; params: string; duration: number }) => {
    logger.debug({ query: e.query, duration: `${e.duration}ms` }, 'Prisma Query');
  });

  // @ts-expect-error Prisma error event typing
  prisma.$on('error', (e: { message: string }) => {
    logger.error({ error: e.message }, 'Prisma Database Error');
  });
}

if (env.NODE_ENV !== 'production') {
  globalThis.prismaGlobal = prisma;
}
