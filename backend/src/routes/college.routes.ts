import { Router, Response } from 'express';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { enforceTenantIsolation, getEffectiveCollegeId } from '../middleware/tenant.js';
import { logAuditEvent } from '../middleware/audit.js';

const router = Router();

// 1. Public list of colleges for Student Registration dropdown (Includes roll_code, clean logo_url, district)
router.get('/public', async (_req, res: Response): Promise<void> => {
  try {
    const result = await pool.query(`
      SELECT id, college_code, roll_code, college_name, short_name, district, logo_url, banner_url, primary_color, secondary_color, is_registered_hub
      FROM colleges
      WHERE student_registration_enabled = TRUE AND status = 'ACTIVE'
      ORDER BY college_name ASC
    `);
    res.json({ colleges: result.rows });
  } catch (error) {
    console.error('Fetch public colleges error:', error);
    res.status(500).json({ error: 'Failed to fetch colleges for registration.' });
  }
});

// 1b. Record student campus interest for Coming Soon non-registered colleges
router.post('/interest', async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { collegeId, email, fullName, mobile, rollNumber } = req.body;
    if (!collegeId || !email) {
      res.status(400).json({ error: 'College and email are required.' });
      return;
    }
    await pool.query(
      `INSERT INTO campus_interest_requests (college_id, email, full_name, mobile, roll_number)
       VALUES ($1, $2, $3, $4, $5)`,
      [collegeId, email.trim().toLowerCase(), fullName?.trim() || null, mobile?.trim() || null, rollNumber?.trim() || null]
    );
    res.json({
      success: true,
      message: 'Request accepted! We will update you soon once Cognito Tech Hub is officially launched at your college.'
    });
  } catch (error: any) {
    console.error('Campus interest submission error:', error);
    res.status(500).json({ error: 'Failed to record campus interest.' });
  }
});

// 2. Protected Colleges List (Role-aware & Tenant-isolated)
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const user = req.user!;
    let queryText = '';
    let queryParams: any[] = [];

    if (user.role === 'SUPER_ADMIN' || user.role === 'PROGRAM_MANAGER') {
      // Super Admin and Program Manager see all colleges with stats
      queryText = `
        SELECT c.*,
               COUNT(DISTINCT s.id) as student_count,
               COUNT(DISTINCT p.id) as program_count,
               COUNT(DISTINCT b.id) as batch_count
        FROM colleges c
        LEFT JOIN students s ON c.id = s.college_id
        LEFT JOIN programs p ON c.id = p.college_id
        LEFT JOIN batches b ON c.id = b.college_id
        GROUP BY c.id
        ORDER BY c.created_at ASC
      `;
    } else {
      // College Admin, TPO, Trainer, Student can ONLY see their assigned college
      queryText = `
        SELECT c.*,
               COUNT(DISTINCT s.id) as student_count,
               COUNT(DISTINCT p.id) as program_count,
               COUNT(DISTINCT b.id) as batch_count
        FROM colleges c
        LEFT JOIN students s ON c.id = s.college_id
        LEFT JOIN programs p ON c.id = p.college_id
        LEFT JOIN batches b ON c.id = b.college_id
        WHERE c.id = $1
        GROUP BY c.id
      `;
      queryParams = [user.collegeId];
    }

    const result = await pool.query(queryText, queryParams);
    res.json({ colleges: result.rows });
  } catch (error) {
    console.error('Fetch colleges error:', error);
    res.status(500).json({ error: 'Failed to fetch colleges.' });
  }
});

// 3. College Details by ID (Tenant-isolated)
router.get('/:id', authenticateToken, enforceTenantIsolation, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT c.*,
              COUNT(DISTINCT s.id) as student_count,
              COUNT(DISTINCT p.id) as program_count,
              COUNT(DISTINCT b.id) as batch_count
       FROM colleges c
       LEFT JOIN students s ON c.id = s.college_id
       LEFT JOIN programs p ON c.id = p.college_id
       LEFT JOIN batches b ON c.id = b.college_id
       WHERE c.id = $1
       GROUP BY c.id`,
      [id]
    );

    if (result.rows.length === 0) {
      res.status(404).json({ error: 'College not found.' });
      return;
    }

    res.json({ college: result.rows[0] });
  } catch (error) {
    console.error('Get college error:', error);
    res.status(500).json({ error: 'Failed to fetch college details.' });
  }
});

// 4. Create New College (SUPER_ADMIN only)
router.post('/', authenticateToken, requireRole('SUPER_ADMIN'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const {
      collegeCode,
      collegeName,
      shortName,
      address,
      district,
      state,
      logoUrl,
      bannerUrl,
      primaryColor,
      secondaryColor,
      studentRegistrationEnabled,
    } = req.body;

    if (!collegeCode || !collegeName || !shortName) {
      res.status(400).json({ error: 'College code, name, and short name are required.' });
      return;
    }

    const result = await pool.query(
      `INSERT INTO colleges (college_code, college_name, short_name, address, district, state, logo_url, banner_url, primary_color, secondary_color, student_registration_enabled, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'ACTIVE')
       RETURNING *`,
      [
        collegeCode.trim().toUpperCase(),
        collegeName.trim(),
        shortName.trim(),
        address || null,
        district || null,
        state || null,
        logoUrl || '/uploads/logo.webp',
        bannerUrl || null,
        primaryColor || '#0057B8',
        secondaryColor || '#003366',
        studentRegistrationEnabled !== false,
      ]
    );

    const newCollege = result.rows[0];
    await logAuditEvent(req, 'CREATE_COLLEGE', 'COLLEGE', newCollege.id, { code: newCollege.college_code });

    res.status(201).json({ message: 'College created successfully', college: newCollege });
  } catch (error: any) {
    console.error('Create college error:', error);
    if (error.code === '23505') {
      res.status(400).json({ error: 'A college with this code already exists.' });
      return;
    }
    res.status(500).json({ error: 'Failed to create college.' });
  }
});

// 5. Update College (SUPER_ADMIN or COLLEGE_ADMIN for own college)
router.put('/:id', authenticateToken, enforceTenantIsolation, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const {
      collegeName,
      shortName,
      address,
      district,
      state,
      logoUrl,
      bannerUrl,
      primaryColor,
      secondaryColor,
      studentRegistrationEnabled,
      status,
    } = req.body;

    const currentRes = await pool.query('SELECT * FROM colleges WHERE id = $1', [id]);
    if (currentRes.rows.length === 0) {
      res.status(404).json({ error: 'College not found.' });
      return;
    }

    const curr = currentRes.rows[0];

    const result = await pool.query(
      `UPDATE colleges SET
        college_name = COALESCE($1, college_name),
        short_name = COALESCE($2, short_name),
        address = COALESCE($3, address),
        district = COALESCE($4, district),
        state = COALESCE($5, state),
        logo_url = COALESCE($6, logo_url),
        banner_url = COALESCE($7, banner_url),
        primary_color = COALESCE($8, primary_color),
        secondary_color = COALESCE($9, secondary_color),
        student_registration_enabled = COALESCE($10, student_registration_enabled),
        status = COALESCE($11, status),
        updated_at = CURRENT_TIMESTAMP
       WHERE id = $12
       RETURNING *`,
      [
        collegeName,
        shortName,
        address,
        district,
        state,
        logoUrl,
        bannerUrl,
        primaryColor,
        secondaryColor,
        studentRegistrationEnabled,
        status,
        id,
      ]
    );

    const updatedCollege = result.rows[0];
    await logAuditEvent(req, 'UPDATE_COLLEGE', 'COLLEGE', id, { name: updatedCollege.college_name });

    res.json({ message: 'College updated successfully', college: updatedCollege });
  } catch (error) {
    console.error('Update college error:', error);
    res.status(500).json({ error: 'Failed to update college.' });
  }
});

export default router;
