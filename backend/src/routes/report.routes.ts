import { Router, Response } from 'express';
import { pool } from '../db/pool.js';
import { supabase } from '../db/supabase.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';

const router = Router();

// Utility function to convert array of objects to RFC 4180 CSV
function jsonToCsv(rows: Record<string, any>[], headers: { key: string; label: string }[]): string {
  if (rows.length === 0) {
    return headers.map(h => `"${h.label.replace(/"/g, '""')}"`).join(',') + '\n';
  }

  const headerLine = headers.map(h => `"${h.label.replace(/"/g, '""')}"`).join(',');
  const dataLines = rows.map(row => {
    return headers
      .map(h => {
        let val = row[h.key];
        if (val === null || val === undefined) return '""';
        if (Array.isArray(val)) val = val.join('; ');
        if (typeof val === 'object') val = JSON.stringify(val);
        const str = String(val).replace(/"/g, '""');
        return `"${str}"`;
      })
      .join(',');
  });

  return [headerLine, ...dataLines].join('\n');
}

// 1. Export Student Nominal Roll Data (CSV / JSON)
router.get(
  '/students',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { collegeId, year, branch, format = 'json' } = req.query;

      let effectiveCollegeId: string | null | undefined = collegeId as string | undefined;
      // Strict multi-tenant isolation: College Admin & TPO can only export their own college
      if (req.user!.role === 'COLLEGE_ADMIN' || req.user!.role === 'TPO') {
        effectiveCollegeId = req.user!.collegeId || (req.user as any)?.college_id;
        if (!effectiveCollegeId) {
          const { data: uData } = await supabase.from('users').select('college_id').eq('id', req.user!.userId).single();
          if (uData) effectiveCollegeId = uData.college_id;
        }
        if (!effectiveCollegeId) {
          res.status(403).json({ error: 'Access denied: No college associated with your account.' });
          return;
        }
      }

      let rows: any[] = [];

      try {
        let query = `
          SELECT s.id as id, s.id as student_id, s.college_id, s.roll_number, u.full_name, u.email, u.mobile,
                 c.college_name, c.short_name as college_name, c.short_name as college_short_name,
                 s.branch, s.year, s.section, s.gender,
                 u.status as enrollment_status,
                 TO_CHAR(s.created_at, 'YYYY-MM-DD HH24:MI:SS') as registered_at
          FROM students s
          JOIN users u ON s.user_id = u.id
          JOIN colleges c ON s.college_id = c.id
          WHERE 1=1
        `;
        const params: any[] = [];

        if (effectiveCollegeId && effectiveCollegeId !== 'all') {
          params.push(effectiveCollegeId);
          query += ` AND s.college_id = $${params.length}`;
        }
        if (year && year !== 'all') {
          params.push(year);
          query += ` AND s.year = $${params.length}`;
        }
        if (branch && branch !== 'all') {
          params.push(branch);
          query += ` AND s.branch = $${params.length}`;
        }

        query += ` ORDER BY c.short_name ASC, s.branch ASC, s.roll_number ASC`;
        const result = await pool.query(query, params);
        rows = result.rows;
      } catch (poolErr) {
        // Supabase fallback
        let sbQuery = supabase
          .from('students')
          .select('id, roll_number, branch, year, section, gender, created_at, college_id, users(full_name, email, mobile, status), colleges(college_name, short_name)');

        if (effectiveCollegeId && effectiveCollegeId !== 'all') {
          sbQuery = sbQuery.eq('college_id', effectiveCollegeId);
        }
        if (year && year !== 'all') {
          sbQuery = sbQuery.eq('year', year);
        }
        if (branch && branch !== 'all') {
          sbQuery = sbQuery.eq('branch', branch);
        }

        const { data: sbData, error } = await sbQuery.order('roll_number', { ascending: true });
        if (error) throw error;

        rows = (sbData || []).map((s: any) => ({
          id: s.id,
          student_id: s.id,
          college_id: s.college_id,
          roll_number: s.roll_number,
          full_name: s.users?.full_name || s.roll_number,
          email: s.users?.email || '',
          mobile: s.users?.mobile || '',
          college_name: s.colleges?.college_name || 'Campus Tech Hub',
          college_short_name: s.colleges?.short_name || 'Tech Hub',
          branch: s.branch,
          year: s.year,
          section: s.section,
          gender: s.gender,
          enrollment_status: s.users?.status || 'ACTIVE',
          registered_at: s.created_at,
        }));
      }

      // If Trainer, enforce trainer-wise student isolation in export
      if (req.user!.role === 'TRAINER') {
        const currentTrainerEmail = (req.user!.email || '').toLowerCase();
        rows = rows.filter(s => {
          const studentYear = (s.year || '').toString();
          const roll = (s.roll_number || '').toString().toUpperCase();
          const branch = (s.branch || '').toString().toUpperCase();
          const is2nd = studentYear.includes('2') || roll.startsWith('24HN') || roll.startsWith('25HN5');
          const is3rd = studentYear.includes('3') || roll.startsWith('23HN') || roll.startsWith('24HN5');
          const is4th = studentYear.includes('4') || roll.startsWith('21HN') || roll.startsWith('22HN');
          const isAidsOrAiml = branch.includes('AI') || branch.includes('DS') || branch.includes('ML') || roll.includes('A54') || roll.includes('A42');

          if (currentTrainerEmail.includes('sushma') || currentTrainerEmail.includes('elisala') || currentTrainerEmail === 'vsushmaelisala@gmail.com') return is2nd || is4th;
          if (currentTrainerEmail.includes('daiva') || currentTrainerEmail.includes('pathivada') || currentTrainerEmail === 'daivaraopathivada@gmail.com' || currentTrainerEmail.includes('uday')) return (is3rd || is4th) && !isAidsOrAiml;
          return true;
        });
      }

      if (format === 'csv') {
        const headers = [
          { key: 'roll_number', label: 'Roll Number' },
          { key: 'full_name', label: 'Student Full Name' },
          { key: 'email', label: 'Email Address' },
          { key: 'mobile', label: 'Contact Mobile' },
          { key: 'college_name', label: 'College Name' },
          { key: 'college_short_name', label: 'College Code' },
          { key: 'branch', label: 'Branch' },
          { key: 'year', label: 'Year' },
          { key: 'section', label: 'Section' },
          { key: 'gender', label: 'Gender' },
          { key: 'enrollment_status', label: 'Status' },
          { key: 'registered_at', label: 'Registration Date' },
        ];

        const csvContent = jsonToCsv(rows, headers);
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', `attachment; filename="student_nominal_roll_${Date.now()}.csv"`);
        res.status(200).send(csvContent);
        return;
      }

      res.json({ students: rows, totalCount: rows.length });
    } catch (error) {
      console.error('Export students error:', error);
      res.status(500).json({ error: 'Failed to export student nominal data.' });
    }
  }
);

// 2. Export Student Attendance Data (CSV / JSON)
router.get(
  '/attendance',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { collegeId, startDate, endDate, sessionId, format = 'json' } = req.query;

      let effectiveCollegeId: string | null | undefined = collegeId as string | undefined;
      // Strict multi-tenant isolation
      if (req.user!.role === 'COLLEGE_ADMIN' || req.user!.role === 'TPO') {
        effectiveCollegeId = req.user!.collegeId || (req.user as any)?.college_id;
        if (!effectiveCollegeId) {
          const uRes = await pool.query('SELECT college_id FROM users WHERE id = $1', [req.user!.userId]);
          if (uRes.rows.length > 0) effectiveCollegeId = uRes.rows[0].college_id;
        }
        if (!effectiveCollegeId) {
          res.status(403).json({ error: 'Access denied: No college associated with your account.' });
          return;
        }
      }

      let query = `
        SELECT TO_CHAR(ar.marked_at, 'YYYY-MM-DD') as attendance_date,
               TO_CHAR(ar.marked_at, 'HH24:MI:SS') as checkin_time,
               s.title as session_title,
               st.roll_number, u.full_name as student_name,
               c.college_name, c.short_name as college_short_name,
               st.branch, st.year, st.section,
               ar.status as attendance_status,
               ar.method as verification_method,
               ar.device_info, ar.ip_address
        FROM attendance_records ar
        JOIN sessions s ON ar.session_id = s.id
        JOIN students st ON ar.student_id = st.id
        JOIN users u ON st.user_id = u.id
        JOIN colleges c ON ar.college_id = c.id
        WHERE 1=1
      `;
      const params: any[] = [];

      if (effectiveCollegeId && effectiveCollegeId !== 'all') {
        params.push(effectiveCollegeId);
        query += ` AND ar.college_id = $${params.length}`;
      }

      // If Trainer, only allow attendance for sessions assigned to this trainer
      if (req.user!.role === 'TRAINER') {
        params.push(req.user!.userId);
        query += ` AND (s.trainer_id = $${params.length} OR s.college_id = (SELECT college_id FROM users WHERE id = $${params.length}))`;
      }

      if (sessionId) {
        params.push(sessionId);
        query += ` AND ar.session_id = $${params.length}`;
      }
      if (startDate) {
        params.push(startDate);
        query += ` AND ar.marked_at >= $${params.length}::date`;
      }
      if (endDate) {
        params.push(endDate);
        query += ` AND ar.marked_at <= ($${params.length}::date + INTERVAL '1 day')`;
      }

      query += ` ORDER BY ar.marked_at DESC`;

      const result = await pool.query(query, params);

      if (format === 'csv') {
        const headers = [
          { key: 'attendance_date', label: 'Date' },
          { key: 'checkin_time', label: 'Check-in Time' },
          { key: 'session_title', label: 'Slot / Session' },
          { key: 'roll_number', label: 'Student Roll No' },
          { key: 'student_name', label: 'Student Name' },
          { key: 'college_name', label: 'College' },
          { key: 'college_short_name', label: 'College Code' },
          { key: 'branch', label: 'Branch' },
          { key: 'year', label: 'Year' },
          { key: 'section', label: 'Section' },
          { key: 'attendance_status', label: 'Status' },
          { key: 'verification_method', label: 'Method' },
          { key: 'device_info', label: 'Device Info' },
          { key: 'ip_address', label: 'IP Address' },
        ];

        const csvContent = jsonToCsv(result.rows, headers);
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', `attachment; filename="attendance_report_${Date.now()}.csv"`);
        res.status(200).send(csvContent);
        return;
      }

      res.json({ records: result.rows, totalCount: result.rows.length });
    } catch (error) {
      console.error('Export attendance error:', error);
      res.status(500).json({ error: 'Failed to export attendance data.' });
    }
  }
);

// 3. Export Faculty & Specialized Trainers Data (CSV / JSON)
router.get(
  '/trainers',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { collegeId, format = 'json' } = req.query;

      let effectiveCollegeId: string | null | undefined = collegeId as string | undefined;
      if (req.user!.role === 'COLLEGE_ADMIN') {
        effectiveCollegeId = req.user!.collegeId;
      }

      let query = `
        SELECT u.id, u.full_name as trainer_name, u.email, u.mobile,
               c.college_name, c.short_name as college_short_name,
               ta.course_name, ta.target_years, ta.target_branches,
               u.status,
               TO_CHAR(u.created_at, 'YYYY-MM-DD') as onboarded_date
        FROM users u
        LEFT JOIN trainer_assignments ta ON u.id = ta.trainer_id
        LEFT JOIN colleges c ON ta.college_id = c.id
        WHERE u.role = 'TRAINER'
      `;
      const params: any[] = [];

      if (effectiveCollegeId && effectiveCollegeId !== 'all') {
        params.push(effectiveCollegeId);
        query += ` AND ta.college_id = $${params.length}`;
      }

      query += ` ORDER BY c.short_name ASC, u.full_name ASC`;

      const result = await pool.query(query, params);

      if (format === 'csv') {
        const headers = [
          { key: 'trainer_name', label: 'Trainer Name' },
          { key: 'email', label: 'Email' },
          { key: 'mobile', label: 'Mobile' },
          { key: 'college_name', label: 'Assigned College' },
          { key: 'college_short_name', label: 'College Code' },
          { key: 'course_name', label: 'Course Track' },
          { key: 'target_years', label: 'Target Years' },
          { key: 'target_branches', label: 'Target Branches' },
          { key: 'status', label: 'Account Status' },
          { key: 'onboarded_date', label: 'Onboarded Date' },
        ];

        const csvContent = jsonToCsv(result.rows, headers);
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', `attachment; filename="trainers_roster_${Date.now()}.csv"`);
        res.status(200).send(csvContent);
        return;
      }

      res.json({ trainers: result.rows, totalCount: result.rows.length });
    } catch (error) {
      console.error('Export trainers error:', error);
      res.status(500).json({ error: 'Failed to export trainers data.' });
    }
  }
);

// 4. Export College Admins and TPO Directory (CSV / JSON)
router.get(
  '/staff',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { collegeId, format = 'json' } = req.query;

      let effectiveCollegeId: string | null | undefined = collegeId as string | undefined;
      if (req.user!.role === 'COLLEGE_ADMIN' || req.user!.role === 'TPO') {
        effectiveCollegeId = req.user!.collegeId;
      }

      let query = `
        SELECT u.full_name as staff_name, u.email, u.mobile,
               u.role as staff_role,
               c.college_name, c.short_name as college_short_name,
               u.status,
               TO_CHAR(u.created_at, 'YYYY-MM-DD') as created_at
        FROM users u
        JOIN colleges c ON u.college_id = c.id
        WHERE u.role IN ('COLLEGE_ADMIN', 'TPO')
      `;
      const params: any[] = [];

      if (effectiveCollegeId && effectiveCollegeId !== 'all') {
        params.push(effectiveCollegeId);
        query += ` AND u.college_id = $${params.length}`;
      }

      query += ` ORDER BY c.short_name ASC, u.role ASC, u.full_name ASC`;

      const result = await pool.query(query, params);

      if (format === 'csv') {
        const headers = [
          { key: 'staff_name', label: 'Staff Name' },
          { key: 'email', label: 'Email' },
          { key: 'mobile', label: 'Mobile' },
          { key: 'staff_role', label: 'Designation / Role' },
          { key: 'college_name', label: 'College' },
          { key: 'college_short_name', label: 'College Code' },
          { key: 'status', label: 'Status' },
          { key: 'created_at', label: 'Assigned Date' },
        ];

        const csvContent = jsonToCsv(result.rows, headers);
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', `attachment; filename="college_staff_roster_${Date.now()}.csv"`);
        res.status(200).send(csvContent);
        return;
      }

      res.json({ staff: result.rows, totalCount: result.rows.length });
    } catch (error) {
      console.error('Export staff error:', error);
      res.status(500).json({ error: 'Failed to export college staff data.' });
    }
  }
);

export default router;
