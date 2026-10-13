import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../types/index.js';

/**
 * Enforces college-level tenant isolation.
 * SUPER_ADMIN and PROGRAM_MANAGER can access any college or filter across colleges.
 * COLLEGE_ADMIN, TPO, TRAINER, and STUDENT can ONLY access their assigned college.
 */
export function enforceTenantIsolation(req: AuthenticatedRequest, res: Response, next: NextFunction): void {
  if (!req.user) {
    res.status(401).json({ error: 'Authentication required for tenant verification.' });
    return;
  }

  // Cognito management roles have global/cross-college authorized visibility
  if (req.user.role === 'SUPER_ADMIN' || req.user.role === 'PROGRAM_MANAGER') {
    next();
    return;
  }

  const userCollegeId = req.user.collegeId || (req.user as any)?.college_id;
  if (!userCollegeId) {
    res.status(403).json({ error: 'User is not associated with any college tenant.' });
    return;
  }

  // Check query, params, or body for requested college_id
  const targetCollegeId =
    req.params.collegeId ||
    req.params.id || // when route is /colleges/:id
    (req.query.college_id as string) ||
    (req.query.collegeId as string) ||
    req.body.college_id ||
    req.body.collegeId;

  // If a specific college was requested in the URL or payload, verify it matches
  if (targetCollegeId && targetCollegeId !== 'all' && targetCollegeId !== userCollegeId) {
    res.status(403).json({
      error: 'Cross-tenant access forbidden. You cannot access or modify resources belonging to another college.',
      tenant: {
        userCollege: userCollegeId,
        requestedCollege: targetCollegeId,
      },
    });
    return;
  }

  next();
}

/**
 * Returns the effective college_id for queries.
 * Non-superadmin users are always restricted to their user.collegeId.
 */
export function getEffectiveCollegeId(req: AuthenticatedRequest): string | undefined {
  if (!req.user) return undefined;
  if (req.user.role === 'SUPER_ADMIN' || req.user.role === 'PROGRAM_MANAGER') {
    const raw = (req.query.college_id as string) || (req.query.collegeId as string) || (req.body.college_id as string) || (req.body.collegeId as string);
    return (raw && raw !== 'all') ? raw : undefined;
  }
  return req.user.collegeId || (req.user as any)?.college_id || undefined;
}

