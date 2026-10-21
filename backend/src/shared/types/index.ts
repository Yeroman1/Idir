import { Request } from 'express';
import { MembershipRole } from '@prisma/client';

export interface AuthUser {
  id: string;
  phoneNumber: string;
  fullName: string;
  email?: string | null;
  faydaId?: string | null;
  isPlatformAdmin: boolean;
  preferredLanguage: string;
}

export interface ActiveMembership {
  id: string;
  idirId: string;
  role: MembershipRole;
  memberNumber: string;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
  membership?: ActiveMembership;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
  search?: string;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}
