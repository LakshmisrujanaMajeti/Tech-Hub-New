import { Router, Response } from 'express';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { getEffectiveCollegeId } from '../middleware/tenant.js';

const router = Router();

// Immutable Audit Log Access
router.get('/', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const collegeId = getEffectiveCollegeId(req);
    const { action, limit = '100' } = req.query;

    let queryText = `
      SELECT al.*, u.full_name as actor_name, u.email as actor_email, c.short_name as college_name
      FROM audit_logs al
      LEFT JOIN users u ON al.actor_id = u.id
      LEFT JOIN colleges c ON al.college_id = c.id
      WHERE 1=1
    `;
    let params: any[] = [];

    if (collegeId) {
      params.push(collegeId);
      queryText += ` AND al.college_id = $${params.length}`;
    }
    if (action) {
      params.push(action);
      queryText += ` AND al.action = $${params.length}`;
    }

    const limitNum = Math.min(200, Math.max(1, parseInt(limit as string)));
    queryText += ` ORDER BY al.created_at DESC LIMIT ${limitNum}`;

    const result = await pool.query(queryText, params);
    res.json({ auditLogs: result.rows });
  } catch (error) {
    console.error('Fetch audit logs error:', error);
    res.status(500).json({ error: 'Failed to retrieve audit trail.' });
  }
});

export default router;
