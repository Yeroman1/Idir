import { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { AppError } from '../shared/errors/AppError.js';
import { logger } from '../shared/utils/logger.js';
import { env } from '../config/env.js';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): Response {
  let statusCode = 500;
  let code = 'INTERNAL_SERVER_ERROR';
  let message = 'An unexpected error occurred';
  let details: unknown = undefined;

  if (err instanceof AppError) {
    statusCode = err.statusCode;
    code = err.code;
    message = err.message;
    details = err.details;
  } else if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002': {
        statusCode = 409;
        code = 'CONFLICT';
        const target = (err.meta?.target as string[]) || [];
        message = `Unique constraint violation on field(s): ${target.join(', ')}`;
        break;
      }
      case 'P2025': {
        statusCode = 404;
        code = 'NOT_FOUND';
        message = 'The requested database record does not exist';
        break;
      }
      case 'P2003': {
        statusCode = 400;
        code = 'FOREIGN_KEY_VIOLATION';
        message = 'Foreign key constraint violation: Related entity does not exist';
        break;
      }
      default: {
        statusCode = 400;
        code = `DATABASE_${err.code}`;
        message = 'A database operation error occurred';
        break;
      }
    }
  } else if (err.name === 'SyntaxError') {
    statusCode = 400;
    code = 'INVALID_JSON';
    message = 'Malformed JSON payload';
  }

  // Structured logging
  if (statusCode >= 500) {
    logger.error(
      {
        err,
        method: req.method,
        url: req.originalUrl,
        ip: req.ip,
      },
      'Unhandled Server Exception'
    );
  } else {
    logger.warn(
      {
        statusCode,
        code,
        message,
        path: req.originalUrl,
      },
      'Client Operational Error'
    );
  }

  const responsePayload: {
    success: false;
    error: {
      code: string;
      message: string;
      details?: unknown;
      stack?: string;
    };
  } = {
    success: false,
    error: {
      code,
      message,
      ...(details !== undefined && { details }),
      ...(env.NODE_ENV !== 'production' && { stack: err.stack }),
    },
  };

  return res.status(statusCode).json(responsePayload);
}
