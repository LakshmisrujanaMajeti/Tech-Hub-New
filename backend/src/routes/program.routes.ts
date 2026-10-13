import { Router, Response } from 'express';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { getEffectiveCollegeId } from '../middleware/tenant.js';
import { logAuditEvent } from '../middleware/audit.js';

const router = Router();

// 1. Get Programs (Tenant-scoped)
router.get('/programs', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const collegeId = getEffectiveCollegeId(req);
    let queryText = `SELECT p.*, c.short_name as college_name FROM programs p JOIN colleges c ON p.college_id = c.id`;
    let params: any[] = [];

    if (collegeId) {
      queryText += ` WHERE p.college_id = $1`;
      params.push(collegeId);
    }
    queryText += ` ORDER BY p.name ASC`;

    const result = await pool.query(queryText, params);
    res.json({ programs: result.rows });
  } catch (error) {
    console.error('Fetch programs error:', error);
    res.status(500).json({ error: 'Failed to fetch programs.' });
  }
});

// 2. Get Batches (Tenant-scoped)
router.get('/batches', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const collegeId = getEffectiveCollegeId(req);
    const { program_id } = req.query;

    let queryText = `
      SELECT b.*, p.name as program_name, c.short_name as college_name,
             COUNT(DISTINCT sbe.student_id) as student_count
      FROM batches b
      JOIN programs p ON b.program_id = p.id
      JOIN colleges c ON b.college_id = c.id
      LEFT JOIN student_batch_enrollments sbe ON b.id = sbe.batch_id
      WHERE 1=1
    `;
    let params: any[] = [];

    if (collegeId) {
      params.push(collegeId);
      queryText += ` AND b.college_id = $${params.length}`;
    }
    if (program_id) {
      params.push(program_id);
      queryText += ` AND b.program_id = $${params.length}`;
    }

    queryText += ` GROUP BY b.id, p.name, c.short_name ORDER BY b.name ASC`;

    const result = await pool.query(queryText, params);
    res.json({ batches: result.rows });
  } catch (error) {
    console.error('Fetch batches error:', error);
    res.status(500).json({ error: 'Failed to fetch batches.' });
  }
});

// 3. Get Sessions (Tenant-scoped)
router.get('/sessions', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const collegeId = getEffectiveCollegeId(req);
    const { batch_id, date, status } = req.query;

    let queryText = `
      SELECT s.*, b.name as batch_name, p.name as program_name, c.short_name as college_name,
             u.full_name as trainer_name,
             (SELECT COUNT(*) FROM attendance_records ar WHERE ar.session_id = s.id) as present_count,
             (SELECT COUNT(*) FROM student_batch_enrollments sbe WHERE sbe.batch_id = s.batch_id) as total_students,
             (SELECT token FROM attendance_qr aq WHERE aq.session_id = s.id AND aq.is_active = TRUE AND aq.valid_until > CURRENT_TIMESTAMP LIMIT 1) as active_qr_token,
             (SELECT valid_until FROM attendance_qr aq WHERE aq.session_id = s.id AND aq.is_active = TRUE AND aq.valid_until > CURRENT_TIMESTAMP LIMIT 1) as qr_valid_until
      FROM sessions s
      JOIN batches b ON s.batch_id = b.id
      JOIN programs p ON b.program_id = p.id
      JOIN colleges c ON s.college_id = c.id
      LEFT JOIN users u ON s.trainer_id = u.id
      WHERE 1=1
    `;
    let params: any[] = [];

    if (collegeId) {
      params.push(collegeId);
      queryText += ` AND s.college_id = $${params.length}`;
    }
    if (batch_id) {
      params.push(batch_id);
      queryText += ` AND s.batch_id = $${params.length}`;
    }
    if (date === 'today') {
      queryText += ` AND s.session_date = CURRENT_DATE`;
    } else if (date) {
      params.push(date);
      queryText += ` AND s.session_date = $${params.length}`;
    }
    if (status) {
      params.push(status);
      queryText += ` AND s.status = $${params.length}`;
    }

    queryText += ` ORDER BY s.session_date DESC, s.start_time ASC`;

    const result = await pool.query(queryText, params);
    res.json({ sessions: result.rows });
  } catch (error) {
    console.error('Fetch sessions error:', error);
    res.status(500).json({ error: 'Failed to fetch sessions.' });
  }
});

// 4. Create Session (Trainer, College Admin, Super Admin, Program Manager)
router.post('/sessions', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TRAINER'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { batchId, title, description, sessionDate, startTime, endTime } = req.body;
    if (!batchId || !title || !startTime || !endTime) {
      res.status(400).json({ error: 'Batch ID, title, start time, and end time are required.' });
      return;
    }

    // Look up batch to get college_id
    const batchRes = await pool.query('SELECT * FROM batches WHERE id = $1', [batchId]);
    if (batchRes.rows.length === 0) {
      res.status(404).json({ error: 'Batch not found.' });
      return;
    }

    const batch = batchRes.rows[0];

    // Tenant check
    if (req.user!.role !== 'SUPER_ADMIN' && req.user!.collegeId !== batch.college_id) {
      res.status(403).json({ error: 'Forbidden: Cannot schedule session for another college.' });
      return;
    }

    const trainerId = req.user!.role === 'TRAINER' ? req.user!.userId : req.body.trainerId || null;

    const result = await pool.query(
      `INSERT INTO sessions (batch_id, college_id, trainer_id, title, description, session_date, start_time, end_time, status)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6, CURRENT_DATE), $7, $8, 'UPCOMING')
       RETURNING *`,
      [batchId, batch.college_id, trainerId, title, description || null, sessionDate || null, startTime, endTime]
    );

    const newSession = result.rows[0];
    await logAuditEvent(req, 'CREATE_SESSION', 'SESSION', newSession.id, { title: newSession.title });

    res.status(201).json({ message: 'Session created successfully', session: newSession });
  } catch (error) {
    console.error('Create session error:', error);
    res.status(500).json({ error: 'Failed to create session.' });
  }
});

export default router;
