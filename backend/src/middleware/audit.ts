import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';

export async function logAuditEvent(
  req: AuthenticatedRequest,
  action: string,
  entityType: string,
  entityId?: string,
  metadata?: Record<string, any>
): Promise<void> {
  try {
    const actorId = req.user?.userId || null;
    const actorRole = req.user?.role || 'SYSTEM';
    const collegeId = req.user?.collegeId || null;
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '127.0.0.1';

    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_role, college_id, action, entity_type, entity_id, metadata, ip_address)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [actorId, actorRole, collegeId, action, entityType, entityId || null, metadata ? JSON.stringify(metadata) : null, ipAddress]
    );
  } catch (error) {
    console.error('Failed to write audit log:', error);
  }
}
