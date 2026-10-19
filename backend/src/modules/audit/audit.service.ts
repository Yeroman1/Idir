import { Prisma } from '@prisma/client';
import { prisma } from '../../config/database.js';

export class AuditService {
  async listLogs(
    idirId: string,
    params: {
      page?: number;
      limit?: number;
      action?: string;
      entityType?: string;
      actorId?: string;
    }
  ) {
    const page = Number(params.page) || 1;
    const limit = Number(params.limit) || 20;
    const skip = (page - 1) * limit;

    const where: Prisma.AuditLogWhereInput = {
      idirId,
      ...(params.action && { action: params.action }),
      ...(params.entityType && { entityType: params.entityType }),
      ...(params.actorId && { actorId: params.actorId }),
    };

    const [total, logs] = await Promise.all([
      prisma.auditLog.count({ where }),
      prisma.auditLog.findMany({
        where,
        skip,
        take: limit,
        orderBy: { timestamp: 'desc' },
        include: {
          actor: {
            select: {
              id: true,
              fullName: true,
              phoneNumber: true,
            },
          },
        },
      }),
    ]);

    return {
      items: logs,
      meta: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}

export const auditService = new AuditService();
