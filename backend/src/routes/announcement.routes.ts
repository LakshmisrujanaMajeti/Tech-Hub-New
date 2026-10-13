import { Router, Response } from 'express';
import { pool } from '../db/pool.js';
import { supabase } from '../db/supabase.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { getEffectiveCollegeId } from '../middleware/tenant.js';
import { logAuditEvent } from '../middleware/audit.js';

const router = Router();

// 1. Get Announcements (Tenant-scoped / Role-aware)
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const userRole = req.user!.role;
    const isExecutive = userRole === 'SUPER_ADMIN' || userRole === 'PROGRAM_MANAGER';
    const queryCollegeId = req.query.collegeId as string | undefined;

    let queryText = '';
    let queryParams: any[] = [];

    if (isExecutive) {
      if (queryCollegeId && queryCollegeId !== 'ALL' && queryCollegeId !== 'null' && queryCollegeId !== '') {
        queryText = `
          SELECT a.*, c.short_name as college_name, c.college_name as college_full_name,
                 u.full_name as author_name, u.role as author_role
          FROM announcements a
          LEFT JOIN colleges c ON a.college_id = c.id
          LEFT JOIN users u ON a.created_by = u.id
          WHERE (a.college_id IS NULL OR a.college_id = $1)
          ORDER BY a.created_at DESC
        `;
        queryParams = [queryCollegeId];
      } else {
        queryText = `
          SELECT a.*, c.short_name as college_name, c.college_name as college_full_name,
                 u.full_name as author_name, u.role as author_role
          FROM announcements a
          LEFT JOIN colleges c ON a.college_id = c.id
          LEFT JOIN users u ON a.created_by = u.id
          ORDER BY a.created_at DESC
        `;
      }
    } else {
      const collegeId = getEffectiveCollegeId(req);
      queryText = `
        SELECT a.*, c.short_name as college_name, c.college_name as college_full_name,
               u.full_name as author_name, u.role as author_role
        FROM announcements a
        LEFT JOIN colleges c ON a.college_id = c.id
        LEFT JOIN users u ON a.created_by = u.id
        WHERE (a.college_id IS NULL OR a.college_id = $1)
          AND (a.target_role = 'ALL' OR a.target_role = $2 OR a.target_role IS NULL)
        ORDER BY a.created_at DESC
      `;
      queryParams = [collegeId || null, userRole];
    }

    const result = await pool.query(queryText, queryParams);
    res.json({ announcements: result.rows });
  } catch (error) {
    console.error('Fetch announcements error:', error);
    res.status(500).json({ error: 'Failed to fetch announcements.' });
  }
});

// 2. Post Announcement (Super Admin, Program Manager, College Admin, TPO, Trainer)
router.post('/', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { title, message, priority = 'MEDIUM', targetRole = 'ALL', collegeId: overrideCollegeId } = req.body;
    if (!title || !message) {
      res.status(400).json({ error: 'Title and message are required.' });
      return;
    }

    const isExecutive = req.user!.role === 'SUPER_ADMIN' || req.user!.role === 'PROGRAM_MANAGER';
    let targetCollegeId: string | null = null;

    if (isExecutive) {
      targetCollegeId = overrideCollegeId && overrideCollegeId !== 'ALL' && overrideCollegeId !== 'null' ? overrideCollegeId : null;
    } else {
      targetCollegeId = req.user!.collegeId || null;
    }

    const result = await pool.query(
      `INSERT INTO announcements (college_id, title, message, priority, target_role, created_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [targetCollegeId, title.trim(), message.trim(), priority, targetRole, req.user!.userId]
    );

    const announcement = result.rows[0];

    // Real-time Cloud Synchronization (Supabase PostgreSQL)
    try {
      const noticePayload: any = {
        id: announcement.id,
        college_id: announcement.college_id,
        title: announcement.title,
        message: announcement.message,
        priority: announcement.priority,
        target_role: announcement.target_role,
        created_by: announcement.created_by,
        created_at: announcement.created_at,
      };

      const { error: syncErr } = await supabase.from('announcements').upsert(noticePayload);
      if (syncErr) {
        console.warn('[Supabase Sync Notice] Retrying without strict FK:', syncErr.message);
        delete noticePayload.created_by;
        delete noticePayload.college_id;
        const { error: fallbackErr } = await supabase.from('announcements').upsert(noticePayload);
        if (fallbackErr) {
          console.warn('[Supabase Sync Warning]:', fallbackErr.message);
        } else {
          console.log(`[Supabase Cloud Sync] Notice successfully synced to Supabase: "${announcement.title}"`);
        }
      } else {
        console.log(`[Supabase Cloud Sync] Notice synced with full tenant relation: "${announcement.title}"`);
      }
    } catch (err: any) {
      console.warn('[Supabase Cloud Sync Exception]:', err.message);
    }

    await logAuditEvent(req, 'CREATE_ANNOUNCEMENT', 'ANNOUNCEMENT', announcement.id, {
      title: announcement.title,
      collegeId: targetCollegeId,
      targetRole,
      priority,
    });

    res.status(201).json({ message: 'Notice published successfully.', announcement });
  } catch (error) {
    console.error('Post announcement error:', error);
    res.status(500).json({ error: 'Failed to publish announcement.' });
  }
});

// 3. Delete Announcement (Super Admin, Program Manager, or Notice Author)
router.delete('/:id', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const isExecutive = req.user!.role === 'SUPER_ADMIN' || req.user!.role === 'PROGRAM_MANAGER';

    const checkRes = await pool.query('SELECT * FROM announcements WHERE id = $1', [id]);
    if (checkRes.rows.length === 0) {
      res.status(404).json({ error: 'Notice not found.' });
      return;
    }

    const notice = checkRes.rows[0];
    if (!isExecutive && notice.created_by !== req.user!.userId && notice.college_id !== req.user!.collegeId) {
      res.status(403).json({ error: 'You are not authorized to delete this notice.' });
      return;
    }

    await pool.query('DELETE FROM announcements WHERE id = $1', [id]);

    // Supabase Cloud Sync delete
    try {
      await supabase.from('announcements').delete().eq('id', id);
      console.log(`[Supabase Cloud Sync] Deleted announcement notice ${id} from Supabase.`);
    } catch (syncErr: any) {
      console.warn('[Supabase Cloud Sync Notice] Handled delete sync notice:', syncErr.message);
    }

    await logAuditEvent(req, 'DELETE_ANNOUNCEMENT', 'ANNOUNCEMENT', id, { title: notice.title });
    res.json({ message: 'Notice deleted successfully.' });
  } catch (error) {
    console.error('Delete announcement error:', error);
    res.status(500).json({ error: 'Failed to delete notice.' });
  }
});

export default router;
