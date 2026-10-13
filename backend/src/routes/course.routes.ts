import { Router, Response } from 'express';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { logAuditEvent } from '../middleware/audit.js';

const router = Router();

// 1. Get All Courses
router.get('/', async (_req, res: Response): Promise<void> => {
  try {
    const result = await pool.query(`
      SELECT id, name, code, description, category, created_at
      FROM courses
      ORDER BY name ASC
    `);
    res.json({ courses: result.rows });
  } catch (error) {
    console.error('Fetch courses error:', error);
    res.status(500).json({ error: 'Failed to fetch courses.' });
  }
});

// 2. Add New Course (SUPER_ADMIN and PROGRAM_MANAGER)
router.post(
  '/',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { name, code, description, category } = req.body;

      if (!name || !name.trim()) {
        res.status(400).json({ error: 'Course name is required.' });
        return;
      }

      const trimmedName = name.trim();
      const existing = await pool.query('SELECT id FROM courses WHERE LOWER(name) = LOWER($1)', [trimmedName]);
      if (existing.rows.length > 0) {
        res.status(400).json({ error: 'A course track with this name already exists.' });
        return;
      }

      const courseCode = code?.trim() || trimmedName.toUpperCase().replace(/[^A-Z0-9]/g, '_').substring(0, 20);

      const result = await pool.query(
        `INSERT INTO courses (name, code, description, category)
         VALUES ($1, $2, $3, $4)
         RETURNING *`,
        [trimmedName, courseCode, description?.trim() || null, category?.trim() || 'TECHNICAL']
      );

      const newCourse = result.rows[0];
      await logAuditEvent(req, 'CREATE_COURSE', 'COURSE', newCourse.id, {
        createdBy: req.user!.email,
        courseName: trimmedName,
      });

      res.status(201).json({
        message: 'Course track created successfully.',
        course: newCourse,
      });
    } catch (error) {
      console.error('Create course error:', error);
      res.status(500).json({ error: 'Failed to create course track.' });
    }
  }
);

export default router;
