import { Router, Response } from 'express';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { getEffectiveCollegeId } from '../middleware/tenant.js';
import { logAuditEvent } from '../middleware/audit.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = Router();

// Configure multer storage
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, path.join(__dirname, '../../uploads'));
  },
  filename: (_req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `doc-${uniqueSuffix}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
  fileFilter: (_req, file, cb) => {
    const allowed = ['.pdf', '.doc', '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.png', '.jpg', '.jpeg', '.webp', '.zip', '.txt'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Disallowed file format. Only educational documents, presentations, and images are permitted.'));
    }
  },
});

// 1. List Materials (Tenant & Class-Year-Branch Scoped)
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const collegeId = getEffectiveCollegeId(req);
    const { batchId, programId, subject, topic, year, branch } = req.query;

    let queryText = `
      SELECT m.*, c.short_name as college_name, p.name as program_name, b.name as batch_name,
             u.full_name as uploader_name
      FROM materials m
      JOIN colleges c ON m.college_id = c.id
      LEFT JOIN programs p ON m.program_id = p.id
      LEFT JOIN batches b ON m.batch_id = b.id
      LEFT JOIN users u ON m.uploaded_by = u.id
      WHERE 1=1
    `;
    let params: any[] = [];

    // If requester is a Student, enforce strict college, year, and branch scoping
    if (req.user!.role === 'STUDENT') {
      const studentRes = await pool.query(
        'SELECT college_id, year, branch FROM students WHERE user_id = $1',
        [req.user!.userId]
      );
      if (studentRes.rows.length > 0) {
        const student = studentRes.rows[0];
        params.push(student.college_id);
        queryText += ` AND m.college_id = $${params.length}`;

        params.push(student.year);
        queryText += ` AND (m.target_year IS NULL OR m.target_year = '' OR m.target_year = $${params.length})`;

        params.push(student.branch);
        queryText += ` AND (m.target_branch IS NULL OR m.target_branch = '' OR m.target_branch = $${params.length} OR (m.target_branches IS NOT NULL AND $${params.length} = ANY(m.target_branches)))`;
      }
    } else {
      if (collegeId) {
        params.push(collegeId);
        queryText += ` AND m.college_id = $${params.length}`;
      }
      if (year) {
        params.push(year);
        queryText += ` AND (m.target_year = $${params.length} OR m.target_year IS NULL)`;
      }
      if (branch) {
        params.push(branch);
        queryText += ` AND (m.target_branch = $${params.length} OR $${params.length} = ANY(m.target_branches))`;
      }
    }

    if (batchId) {
      params.push(batchId);
      queryText += ` AND (m.batch_id = $${params.length} OR m.batch_id IS NULL)`;
    }
    if (programId) {
      params.push(programId);
      queryText += ` AND (m.program_id = $${params.length} OR m.program_id IS NULL)`;
    }
    if (subject) {
      params.push(subject);
      queryText += ` AND LOWER(m.subject) = LOWER($${params.length})`;
    }
    if (topic) {
      params.push(topic);
      queryText += ` AND LOWER(m.topic) = LOWER($${params.length})`;
    }

    queryText += ` ORDER BY m.created_at DESC`;

    const result = await pool.query(queryText, params);
    res.json({ materials: result.rows });
  } catch (error) {
    console.error('Fetch materials error:', error);
    res.status(500).json({ error: 'Failed to fetch study materials.' });
  }
});

// 2. Upload Material / Add Note (Trainer / Program Manager / Super Admin)
router.post(
  '/',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TRAINER'),
  upload.single('file'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const {
        programId,
        batchId,
        subject,
        topic,
        title,
        description,
        linkUrl,
        targetYear,
        targetBranch,
        targetBranches,
        courseName,
      } = req.body;
      let collegeId = req.user!.collegeId;

      if (!collegeId && req.user!.role === 'TRAINER') {
        const trAssign = await pool.query('SELECT college_id FROM trainer_assignments WHERE trainer_id = $1 LIMIT 1', [req.user!.userId]);
        if (trAssign.rows.length > 0) collegeId = trAssign.rows[0].college_id;
      }

      if (req.user!.role === 'SUPER_ADMIN' || req.user!.role === 'PROGRAM_MANAGER') {
        collegeId = req.body.collegeId || collegeId;
      }

      if (!collegeId || !title) {
        res.status(400).json({ error: 'College ID and Title are required.' });
        return;
      }

      let fileUrl = linkUrl;
      let fileType = 'LINK';
      let fileSize = '0 KB';

      if (req.file) {
        fileUrl = `/uploads/${req.file.filename}`;
        const ext = path.extname(req.file.originalname).toUpperCase().replace('.', '');
        fileType = ext;
        fileSize = `${(req.file.size / (1024 * 1024)).toFixed(2)} MB`;
      }

      if (!fileUrl) {
        res.status(400).json({ error: 'Either an uploaded document file or an external URL is required.' });
        return;
      }

      // Parse target branches array if string passed
      let parsedBranches: string[] | null = null;
      if (Array.isArray(targetBranches)) {
        parsedBranches = targetBranches;
      } else if (typeof targetBranches === 'string' && targetBranches.trim()) {
        parsedBranches = targetBranches.split(',').map(s => s.trim());
      } else if (targetBranch) {
        parsedBranches = [targetBranch.trim()];
      }

      const result = await pool.query(
        `INSERT INTO materials (
           college_id, program_id, batch_id, subject, topic, title, description,
           file_url, file_type, file_size, uploaded_by,
           target_year, target_branch, target_branches, course_name
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         RETURNING *`,
        [
          collegeId,
          programId || null,
          batchId || null,
          (subject || courseName || 'Technical Session').trim(),
          (topic || title).trim(),
          title.trim(),
          description || null,
          fileUrl,
          fileType,
          fileSize,
          req.user!.userId,
          targetYear || null,
          targetBranch || null,
          parsedBranches,
          courseName || subject || null,
        ]
      );

      const material = result.rows[0];
      await logAuditEvent(req, 'UPLOAD_MATERIAL', 'MATERIAL', material.id, { title: material.title });

      res.status(201).json({ message: 'Study material uploaded successfully.', material });
    } catch (error) {
      console.error('Upload material error:', error);
      res.status(500).json({ error: 'Failed to upload material.' });
    }
  }
);

export default router;
