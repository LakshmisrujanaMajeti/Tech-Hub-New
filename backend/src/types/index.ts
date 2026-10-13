import { Request } from 'express';

export type UserRole = 'SUPER_ADMIN' | 'PROGRAM_MANAGER' | 'COLLEGE_ADMIN' | 'TPO' | 'TRAINER' | 'STUDENT';

export interface AuthUser {
  userId: string;
  email: string;
  role: UserRole;
  fullName: string;
  collegeId?: string | null;
  studentId?: string | null;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}
