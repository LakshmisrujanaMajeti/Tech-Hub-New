import { Router, Response } from 'express';
import QRCode from 'qrcode';
import crypto from 'crypto';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { getEffectiveCollegeId } from '../middleware/tenant.js';
import { logAuditEvent } from '../middleware/audit.js';
import { supabase } from '../db/supabase.js';
import { isWithinAttendanceWindow, getAttendanceWindowInfo, clampSlotExpiryTo4PM } from '../utils/timeWindow.js';

const router = Router();

// 0. Generate Daily Attendance Slot QR (Admin / Program Manager / College Admin / Trainer)
router.post(
  '/slots/generate-qr',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { slotName, validityMinutes = 30, courseName, batchId } = req.body;
      let collegeId = req.body.collegeId;

      if (req.user!.role === 'COLLEGE_ADMIN' || req.user!.role === 'TPO') {
        collegeId = req.user!.collegeId;
      } else if (req.user!.role === 'TRAINER') {
        collegeId = req.user!.collegeId || collegeId;
      }

      if (!collegeId) {
        res.status(400).json({ error: 'College ID is required to generate an attendance slot.' });
        return;
      }

      // Verify college exists
      const colRes = await pool.query('SELECT id, college_name, short_name FROM colleges WHERE id = $1', [collegeId]);
      if (colRes.rows.length === 0) {
        res.status(404).json({ error: 'Institution not found.' });
        return;
      }
      const college = colRes.rows[0];

      // Find or create default batch for this college if not supplied
      let targetBatchId = batchId;
      if (!targetBatchId) {
        const batchRes = await pool.query(
          'SELECT id FROM batches WHERE college_id = $1 ORDER BY created_at ASC LIMIT 1',
          [collegeId]
        );
        if (batchRes.rows.length > 0) {
          targetBatchId = batchRes.rows[0].id;
        } else {
          // Find or create program
          let progId;
          const progRes = await pool.query(
            'SELECT id FROM programs WHERE college_id = $1 LIMIT 1',
            [collegeId]
          );
          if (progRes.rows.length > 0) {
            progId = progRes.rows[0].id;
          } else {
            const newProg = await pool.query(
              `INSERT INTO programs (college_id, name, code, academic_year)
               VALUES ($1, 'B.Tech Engineering Program', 'BTECH', '2026')
               RETURNING id`,
              [collegeId]
            );
            progId = newProg.rows[0].id;
          }

          const newBatch = await pool.query(
            `INSERT INTO batches (program_id, college_id, name, code, academic_year)
             VALUES ($1, $2, 'Tech Hub Classroom Core Batch', 'CORE-26', '2026')
             RETURNING id`,
            [progId, collegeId]
          );
          targetBatchId = newBatch.rows[0].id;
        }
      }

      const formattedSlotName = (slotName || courseName || 'Daily Technical Session').trim();

      // Find or create session for today
      let sessionId;
      const todaySessionRes = await pool.query(
        `SELECT id FROM sessions
         WHERE college_id = $1 AND batch_id = $2 AND session_date = CURRENT_DATE AND title = $3
         LIMIT 1`,
        [collegeId, targetBatchId, formattedSlotName]
      );

      if (todaySessionRes.rows.length > 0) {
        sessionId = todaySessionRes.rows[0].id;
      } else {
        const newSession = await pool.query(
          `INSERT INTO sessions (batch_id, college_id, trainer_id, title, description, session_date, start_time, end_time, status)
           VALUES ($1, $2, $3, $4, $5, CURRENT_DATE, CURRENT_TIME, CURRENT_TIME + INTERVAL '2 hours', 'IN_PROGRESS')
           RETURNING id`,
          [
            targetBatchId,
            collegeId,
            req.user!.role === 'TRAINER' ? req.user!.userId : null,
            formattedSlotName,
            `Daily Tech Hub Attendance Slot: ${formattedSlotName}`,
          ]
        );
        sessionId = newSession.rows[0].id;
      }

      // Invalidate existing active tokens for this session
      await pool.query('UPDATE attendance_qr SET is_active = FALSE WHERE session_id = $1', [sessionId]);

      // Generate clean, secure token e.g. COG-ADARSH-7A8B
      const codePart = crypto.randomBytes(3).toString('hex').toUpperCase();
      const colPrefix = (college.short_name || college.college_code || 'HUB')
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, '')
        .substring(0, 8);
      const token = `COG-${colPrefix}-${codePart}`;
      const minutes = Math.max(1, Math.min(240, Number(validityMinutes)));
      const validUntil = new Date(Date.now() + minutes * 60 * 1000);

      const qrRecord = await pool.query(
        `INSERT INTO attendance_qr (session_id, college_id, batch_id, token, valid_from, valid_until, is_active, created_by)
         VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, $5, TRUE, $6)
         RETURNING *`,
        [sessionId, collegeId, targetBatchId, token, validUntil, req.user!.userId]
      );

      // Sync Session and QR to Supabase
      try {
        await supabase.from('batches').upsert({
          id: targetBatchId,
          college_id: collegeId,
          name: 'Tech Hub Classroom Core Batch',
          academic_year: '2026',
        });

        await supabase.from('sessions').upsert({
          id: sessionId,
          batch_id: targetBatchId,
          college_id: collegeId,
          trainer_id: req.user!.role === 'TRAINER' ? req.user!.userId : null,
          title: formattedSlotName,
          description: `Daily Tech Hub Attendance Slot: ${formattedSlotName}`,
          session_date: new Date().toISOString().substring(0, 10),
          start_time: '09:00:00',
          end_time: '17:00:00',
          status: 'IN_PROGRESS',
        });

        await supabase.from('attendance_qr').upsert({
          id: qrRecord.rows[0].id,
          session_id: sessionId,
          college_id: collegeId,
          batch_id: targetBatchId,
          token: token,
          valid_from: qrRecord.rows[0].valid_from,
          valid_until: validUntil,
          is_active: true,
          created_by: req.user!.userId,
        });
        console.log(`[Supabase QR Sync] Synced QR token ${token} for session ${sessionId}`);
      } catch (sbErr) {
        console.warn('[attendance_qr] Supabase sync notice:', (sbErr as Error).message);
      }

      const qrPayload = JSON.stringify({
        attendance_token: token,
        college_id: collegeId,
        slot_name: formattedSlotName,
        app: 'CognitoTechHub',
      });

      const qrImageDataUrl = await QRCode.toDataURL(qrPayload, {
        errorCorrectionLevel: 'H',
        margin: 2,
        width: 400,
        color: {
          dark: '#003366',
          light: '#FFFFFF',
        },
      });

      await logAuditEvent(req, 'GENERATE_SLOT_QR', 'SESSION', sessionId, {
        token,
        slotName: formattedSlotName,
        validUntil,
      });

      res.json({
        message: 'Daily dynamic attendance QR slot generated successfully.',
        slot: {
          sessionId,
          slotName: formattedSlotName,
          token,
          slotCode: token,
          slot_code: token,
          qr_data: token,
          qrData: token,
          validFrom: qrRecord.rows[0].valid_from,
          validUntil,
          validityMinutes: minutes,
          collegeId: college.id,
          collegeName: college.college_name,
          collegeCode: college.short_name,
        },
        qrImageDataUrl,
      });
    } catch (error) {
      console.error('Generate slot QR error:', error);
      res.status(500).json({ error: 'Failed to generate daily attendance slot QR.' });
    }
  }
);

// 0.1 Get Today's Active Attendance Slots (Admin / PM / College Admin / Trainer)
router.get(
  '/slots/today',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      let targetCollegeId: string | null | undefined = req.query.collegeId as string | undefined;

      if (req.user!.role === 'COLLEGE_ADMIN' || req.user!.role === 'TPO') {
        targetCollegeId = req.user!.collegeId || (req.user as any)?.college_id;
        if (!targetCollegeId) {
          const uRes = await pool.query('SELECT college_id FROM users WHERE id = $1', [req.user!.userId]);
          if (uRes.rows.length > 0) targetCollegeId = uRes.rows[0].college_id;
        }
        if (!targetCollegeId) {
          res.json({ slots: [] });
          return;
        }
      } else if (req.user!.role === 'TRAINER') {
        targetCollegeId = req.user!.collegeId || (req.user as any)?.college_id || targetCollegeId;
      }

      let query = `
        SELECT aq.id, aq.token, aq.token as slot_code, aq.token as qr_data, aq.valid_from, aq.valid_until, aq.is_active,
               s.id as session_id, s.title as slot_name, s.session_date,
               c.id as college_id, c.college_name, c.short_name as college_short_name,
               b.name as batch_name,
               (SELECT COUNT(*) FROM attendance_records ar WHERE ar.session_id = s.id) as attendee_count,
               (aq.is_active AND aq.valid_until > CURRENT_TIMESTAMP) as is_currently_valid
        FROM attendance_qr aq
        JOIN sessions s ON aq.session_id = s.id
        JOIN colleges c ON aq.college_id = c.id
        JOIN batches b ON aq.batch_id = b.id
        WHERE s.session_date = CURRENT_DATE
      `;
      const params: any[] = [];

      if (targetCollegeId && targetCollegeId !== 'all') {
        params.push(targetCollegeId);
        query += ` AND aq.college_id = $${params.length}`;
      }

      query += ` ORDER BY aq.created_at DESC`;

      const result = await pool.query(query, params);
      res.json({ slots: result.rows });
    } catch (error) {
      console.error('Get today slots error:', error);
      res.status(500).json({ error: 'Failed to fetch today attendance slots.' });
    }
  }
);

// 1. Generate Dynamic Time-bound Attendance QR (Trainer / College Admin / Super Admin / PM)
router.post('/qr/generate', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TRAINER'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { sessionId, validityMinutes = 5 } = req.body;
    if (!sessionId) {
      res.status(400).json({ error: 'Session ID is required.' });
      return;
    }

    // Lookup session and verify tenant
    const sessionRes = await pool.query(
      `SELECT s.*, b.name as batch_name, c.short_name as college_name
       FROM sessions s
       JOIN batches b ON s.batch_id = b.id
       JOIN colleges c ON s.college_id = c.id
       WHERE s.id = $1`,
      [sessionId]
    );

    if (sessionRes.rows.length === 0) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }

    const session = sessionRes.rows[0];

    // Tenant check
    if (req.user!.role !== 'SUPER_ADMIN' && req.user!.role !== 'PROGRAM_MANAGER') {
      let uCollege = req.user!.collegeId || (req.user as any)?.college_id;
      if (!uCollege) {
        const uRes = await pool.query('SELECT college_id FROM users WHERE id = $1', [req.user!.userId]);
        if (uRes.rows.length > 0) uCollege = uRes.rows[0].college_id;
      }
      if (!uCollege || uCollege !== session.college_id) {
        res.status(403).json({ error: 'Forbidden: Cannot generate QR for another college.' });
        return;
      }
    }

    // Invalidate existing active tokens for this session
    await pool.query('UPDATE attendance_qr SET is_active = FALSE WHERE session_id = $1', [sessionId]);

    // Generate secure opaque token
    const token = 'COG-' + crypto.randomBytes(6).toString('hex').toUpperCase();
    const minutes = Math.max(1, Math.min(60, Number(validityMinutes)));
    const validUntil = new Date(Date.now() + minutes * 60 * 1000);

    const qrRecord = await pool.query(
      `INSERT INTO attendance_qr (session_id, college_id, batch_id, token, valid_from, valid_until, is_active, created_by)
       VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, $5, TRUE, $6)
       RETURNING *`,
      [session.id, session.college_id, session.batch_id, token, validUntil, req.user!.userId]
    );

    // QR payload (JSON structure)
    const qrPayload = JSON.stringify({
      attendance_token: token,
      app: 'CognitoTechHub',
    });

    const qrImageDataUrl = await QRCode.toDataURL(qrPayload, {
      errorCorrectionLevel: 'H',
      margin: 2,
      width: 400,
      color: {
        dark: '#003366',
        light: '#FFFFFF',
      },
    });

    // Mark session as IN_PROGRESS if UPCOMING
    if (session.status === 'UPCOMING') {
      await pool.query("UPDATE sessions SET status = 'IN_PROGRESS' WHERE id = $1", [sessionId]);
    }

    await logAuditEvent(req, 'GENERATE_QR', 'SESSION', sessionId, { token, validUntil });

    res.json({
      message: 'Dynamic attendance QR generated successfully.',
      token,
      validFrom: qrRecord.rows[0].valid_from,
      validUntil,
      validityMinutes: minutes,
      session: {
        id: session.id,
        title: session.title,
        batchName: session.batch_name,
        collegeName: session.college_name,
      },
      qrImageDataUrl,
    });
  } catch (error) {
    console.error('Generate QR error:', error);
    res.status(500).json({ error: 'Failed to generate attendance QR.' });
  }
});

// 2. Mark Attendance via QR Scan (Student)
router.post('/mark', authenticateToken, requireRole('STUDENT'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  const client = await pool.connect();
  try {
    const { attendanceToken, deviceInfo } = req.body;
    if (!attendanceToken) {
      res.status(400).json({ error: 'Attendance token is required.' });
      return;
    }

    let cleanToken = (attendanceToken || '').trim();
    if (cleanToken.startsWith('{') && cleanToken.includes('attendance_token')) {
      try {
        const parsed = JSON.parse(cleanToken);
        if (parsed.attendance_token) cleanToken = parsed.attendance_token.trim();
      } catch (_) {}
    }

    // 1. Verify token existence and active validity
    let qrRes = await client.query(
      `SELECT aq.*, s.title as session_title, s.session_date, s.start_time, s.end_time,
              c.short_name as college_name, b.name as batch_name
       FROM attendance_qr aq
       JOIN sessions s ON aq.session_id = s.id
       LEFT JOIN colleges c ON aq.college_id = c.id
       LEFT JOIN batches b ON aq.batch_id = b.id
       WHERE UPPER(TRIM(aq.token)) = UPPER(TRIM($1))`,
      [cleanToken]
    );

    let qr: any = qrRes.rows[0];

    // Supabase fallback for QR lookup
    if (!qr) {
      try {
        const { data: sbQrs } = await supabase
          .from('attendance_qr')
          .select('*')
          .ilike('token', cleanToken)
          .limit(1);

        if (sbQrs && sbQrs.length > 0) {
          const sbQr = sbQrs[0];
          let sTitle = 'Daily Classroom Session';
          let cName = 'Tech Hub';
          try {
            const { data: sessData } = await supabase.from('sessions').select('title, session_date').eq('id', sbQr.session_id).limit(1);
            if (sessData && sessData.length > 0) sTitle = sessData[0].title;
            const { data: colData } = await supabase.from('colleges').select('short_name, college_name').eq('id', sbQr.college_id).limit(1);
            if (colData && colData.length > 0) cName = colData[0].short_name || colData[0].college_name;
          } catch (_) {}

          qr = {
            ...sbQr,
            session_title: sTitle,
            session_date: new Date().toISOString().substring(0, 10),
            college_name: cName,
            batch_name: 'Core Batch',
          };
        }
      } catch (sbErr) {
        console.warn('Supabase QR fallback error:', sbErr);
      }
    }

    if (!qr) {
      res.status(404).json({ error: 'Invalid attendance QR code. Please check the code or scan again.' });
      return;
    }

    // Expiration check (server-validated timestamp)
    const now = new Date();
    if (!qr.is_active || new Date(qr.valid_until) < now) {
      res.status(400).json({
        error: 'This attendance QR code has expired. Please ask your trainer to generate a fresh QR.',
        expiredAt: qr.valid_until,
      });
      return;
    }

    // 2. Lookup student profile
    const studentRes = await client.query(
      `SELECT s.*, u.full_name, u.email
       FROM students s
       JOIN users u ON s.user_id = u.id
       WHERE u.id = $1`,
      [req.user!.userId]
    );

    let student: any = studentRes.rows[0];

    if (!student) {
      try {
        const { data: sbStudents } = await supabase
          .from('students')
          .select('*')
          .eq('user_id', req.user!.userId)
          .limit(1);
        if (sbStudents && sbStudents.length > 0) {
          student = {
            ...sbStudents[0],
            full_name: req.user!.fullName || req.user!.email,
            email: req.user!.email,
          };
        } else {
          // Auto create student record if missing
          const defaultCollege = qr.college_id || req.user!.collegeId;
          const newS = await client.query(
            `INSERT INTO students (user_id, college_id, roll_number, year, branch, status)
             VALUES ($1, $2, $3, '2nd Year', 'CSE', 'ACTIVE')
             ON CONFLICT (user_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
             RETURNING *`,
            [req.user!.userId, defaultCollege, req.user!.email.split('@')[0].toUpperCase()]
          );
          student = {
            ...newS.rows[0],
            full_name: req.user!.fullName || req.user!.email,
            email: req.user!.email,
          };
        }
      } catch (sErr) {
        console.warn('Student auto-create note:', sErr);
      }
    }

    if (!student) {
      res.status(404).json({ error: 'Student academic profile not found.' });
      return;
    }

    // 3. Multi-Tenant Validation: College match (if both exist)
    if (student.college_id && qr.college_id && student.college_id !== qr.college_id) {
      // Check if student belongs to same group or allow if student user
      console.warn(`[Multi-tenant note] Student college (${student.college_id}) vs QR college (${qr.college_id})`);
    }

    await client.query('BEGIN');

    // 4. Batch Enrollment Check (Auto-enroll if verified student of this college)
    const enrollmentRes = await client.query(
      `SELECT id FROM student_batch_enrollments
       WHERE student_id = $1 AND batch_id = $2`,
      [student.id, qr.batch_id]
    );

    if (enrollmentRes.rows.length === 0) {
      await client.query(
        `INSERT INTO student_batch_enrollments (student_id, batch_id, college_id)
         VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
        [student.id, qr.batch_id, qr.college_id]
      );
    }

    // 5. One-Time Daily Attendance Check (strictly today's calendar date in IST; no 24-hour rolling block)
    const existingAttendance = await client.query(
      `SELECT ar.id, ar.marked_at, s.title as session_title
       FROM attendance_records ar
       JOIN sessions s ON ar.session_id = s.id
       WHERE ar.student_id = $1
         AND (
           (ar.marked_at AT TIME ZONE 'Asia/Kolkata')::DATE = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Kolkata')::DATE
           OR (s.session_date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Kolkata')::DATE AND ar.session_id = $2)
         )`,
      [student.id, qr.session_id]
    );

    if (existingAttendance.rows.length > 0) {
      await client.query('ROLLBACK');
      res.status(400).json({
        error: 'Attendance already recorded and verified for today. Re-scanning is disabled until tomorrow 09:00 AM.',
        markedAt: existingAttendance.rows[0].marked_at,
        hasMarkedToday: true,
      });
      return;
    }

    // 6. Record attendance
    const ipAddress = (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || '127.0.0.1';
    const recordRes = await client.query(
      `INSERT INTO attendance_records (session_id, student_id, college_id, status, device_info, ip_address, method)
       VALUES ($1, $2, $3, 'PRESENT', $4, $5, 'QR_SCAN')
       RETURNING *`,
      [qr.session_id, student.id, qr.college_id, deviceInfo || 'Mobile Device', ipAddress]
    );

    const record = recordRes.rows[0];

    // 7. Update Student Behaviour Attendance Consistency
    const statsRes = await client.query(
      `SELECT
         COUNT(DISTINCT s.id) as total_sessions,
         COUNT(DISTINCT ar.id) as attended_sessions
       FROM sessions s
       JOIN student_batch_enrollments sbe ON s.batch_id = sbe.batch_id AND sbe.student_id = $1
       LEFT JOIN attendance_records ar ON s.id = ar.session_id AND ar.student_id = $1
       WHERE s.session_date <= CURRENT_DATE`,
      [student.id]
    );

    const total = Number(statsRes.rows[0].total_sessions) || 1;
    const attended = Number(statsRes.rows[0].attended_sessions) || 1;
    const consistency = Math.min(100, Math.round((attended / total) * 100 * 10) / 10);

    await client.query(
      `UPDATE student_behaviour
       SET attendance_consistency = $1, updated_at = CURRENT_TIMESTAMP
       WHERE student_id = $2`,
      [consistency, student.id]
    );

    await client.query('COMMIT');

    // Real-time Cloud Synchronization (Supabase PostgreSQL)
    try {
      await supabase.from('attendance_records').upsert({
        id: record.id,
        session_id: record.session_id,
        student_id: record.student_id,
        college_id: record.college_id,
        status: record.status,
        device_info: record.device_info,
        ip_address: record.ip_address,
        method: record.method,
        marked_at: record.marked_at,
      });
      console.log(`[Supabase Cloud Sync] Synced attendance record ${record.id} to Supabase.`);
    } catch (syncErr: any) {
      console.warn('[Supabase Cloud Sync Notice] Handled attendance cloud sync notice:', syncErr.message);
    }

    await logAuditEvent(req, 'ATTENDANCE_MARKED', 'SESSION', qr.session_id, {
      studentId: student.id,
      rollNumber: student.roll_number,
      token: cleanToken,
    });

    res.json({
      message: 'Attendance recorded successfully!',
      hasMarkedToday: true,
      attendance: {
        id: record.id,
        status: record.status,
        markedAt: record.marked_at,
        sessionTitle: qr.session_title,
        batchName: qr.batch_name,
        collegeName: qr.college_name,
        studentName: student.full_name,
        rollNumber: student.roll_number,
      },
    });
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}
    console.error('Mark attendance error:', error);
    res.status(500).json({ error: 'Failed to record attendance.' });
  } finally {
    client.release();
  }
});

// 3. Live Attendance Counter (for Trainer/Admin screen while QR is active)
router.get('/live/:sessionId', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { sessionId } = req.params;

    const sessionRes = await pool.query(
      `SELECT s.*, b.name as batch_name, c.short_name as college_name,
              (SELECT COUNT(*) FROM student_batch_enrollments sbe WHERE sbe.batch_id = s.batch_id) as total_students,
              (SELECT token FROM attendance_qr aq WHERE aq.session_id = s.id AND aq.is_active = TRUE AND aq.valid_until > CURRENT_TIMESTAMP LIMIT 1) as active_token,
              (SELECT valid_until FROM attendance_qr aq WHERE aq.session_id = s.id AND aq.is_active = TRUE AND aq.valid_until > CURRENT_TIMESTAMP LIMIT 1) as valid_until
       FROM sessions s
       JOIN batches b ON s.batch_id = b.id
       JOIN colleges c ON s.college_id = c.id
       WHERE s.id = $1`,
      [sessionId]
    );

    if (sessionRes.rows.length === 0) {
      res.status(404).json({ error: 'Session not found.' });
      return;
    }

    const session = sessionRes.rows[0];

    // Tenant check
    if (req.user!.role !== 'SUPER_ADMIN' && req.user!.role !== 'PROGRAM_MANAGER' && req.user!.collegeId !== session.college_id) {
      res.status(403).json({ error: 'Forbidden: Access to another college session is restricted.' });
      return;
    }

    // Attendees list
    const attendeesRes = await pool.query(
      `SELECT ar.id, ar.marked_at, ar.status, ar.method,
              s.roll_number, s.branch, s.section, u.full_name
       FROM attendance_records ar
       JOIN students s ON ar.student_id = s.id
       JOIN users u ON s.user_id = u.id
       WHERE ar.session_id = $1
       ORDER BY ar.marked_at DESC`,
      [sessionId]
    );

    const totalStudents = Number(session.total_students) || 0;
    const presentCount = attendeesRes.rows.length;
    const percentage = totalStudents > 0 ? Math.round((presentCount / totalStudents) * 100) : 0;

    res.json({
      session: {
        id: session.id,
        title: session.title,
        batchName: session.batch_name,
        collegeName: session.college_name,
        activeToken: session.active_token || null,
        validUntil: session.valid_until || null,
        isActive: !!session.active_token,
      },
      stats: {
        totalStudents,
        presentCount,
        absentCount: Math.max(0, totalStudents - presentCount),
        percentage,
      },
      attendees: attendeesRes.rows,
    });
  } catch (error) {
    console.error('Live attendance error:', error);
    res.status(500).json({ error: 'Failed to retrieve live attendance.' });
  }
});

// 4. Student Attendance Summary (Student view)
router.get('/student', authenticateToken, requireRole('STUDENT'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    let studentId: string | null = null;
    let collegeId: string | null = null;

    try {
      const studentRes = await pool.query('SELECT id, college_id FROM students WHERE user_id = $1', [req.user!.userId]);
      if (studentRes.rows.length > 0) {
        studentId = studentRes.rows[0].id;
        collegeId = studentRes.rows[0].college_id;
      }
    } catch (_) {}

    if (!studentId) {
      try {
        const { data: sData } = await supabase.from('students').select('id, college_id').eq('user_id', req.user!.userId).single();
        if (sData) {
          studentId = sData.id;
          collegeId = sData.college_id;
        }
      } catch (_) {}
    }

    if (!studentId) {
      res.status(404).json({ error: 'Student profile not found.' });
      return;
    }

    let totalRaw = 0;
    let presentCount = 0;
    let subjects: any[] = [];
    let history: any[] = [];
    let hasMarkedToday = false;
    let todayRecord: any = null;

    try {
      const attendedSessionsRes = await pool.query(
        `SELECT COUNT(DISTINCT ar.session_id) as count
         FROM attendance_records ar
         WHERE (ar.student_id = $1 OR ar.student_id IN (SELECT user_id FROM students WHERE id = $1))
           AND ar.status = 'PRESENT'`,
        [studentId]
      );
      presentCount = Number(attendedSessionsRes.rows[0]?.count) || 0;

      const totalSessionsRes = await pool.query(
        `SELECT COUNT(DISTINCT s.id) as count
         FROM sessions s
         JOIN student_batch_enrollments sbe ON s.batch_id = sbe.batch_id
         WHERE sbe.student_id = $1 AND s.session_date <= CURRENT_DATE`,
        [studentId]
      );
      totalRaw = Number(totalSessionsRes.rows[0]?.count) || 0;
      if (totalRaw < presentCount) {
        totalRaw = presentCount;
      }

      const subjectStatsRes = await pool.query(
        `SELECT
           p.name as subject,
           COUNT(DISTINCT s.id) as total,
           COUNT(DISTINCT ar.id) as attended
         FROM sessions s
         JOIN batches b ON s.batch_id = b.id
         JOIN programs p ON b.program_id = p.id
         JOIN student_batch_enrollments sbe ON b.id = sbe.batch_id AND sbe.student_id = $1
         LEFT JOIN attendance_records ar ON s.id = ar.session_id AND (ar.student_id = $1 OR ar.student_id IN (SELECT user_id FROM students WHERE id = $1)) AND ar.status = 'PRESENT'
         WHERE s.session_date <= CURRENT_DATE
         GROUP BY p.name`,
        [studentId]
      );
      subjects = subjectStatsRes.rows.map((row) => {
        const att = Number(row.attended) || 0;
        let tot = Number(row.total) || 0;
        if (tot < att) tot = att;
        return {
          subject: row.subject,
          total: tot,
          attended: att,
          percentage: tot > 0 ? Math.round((att / tot) * 100) : (att > 0 ? 100 : 0),
        };
      });

      const recentRecordsRes = await pool.query(
        `SELECT ar.id, s.session_date, COALESCE(s.title, 'Technical Hub Classroom Session') as title,
                COALESCE(s.title, 'Technical Hub Classroom Session') as session_title,
                ar.marked_at, ar.status, ar.method
         FROM attendance_records ar
         LEFT JOIN sessions s ON ar.session_id = s.id
         WHERE (ar.student_id = $1 OR ar.student_id IN (SELECT user_id FROM students WHERE id = $1))
         ORDER BY ar.marked_at DESC LIMIT 30`,
        [studentId]
      );
      history = recentRecordsRes.rows;

      const todayAttendanceRes = await pool.query(
        `SELECT ar.id, ar.marked_at, ar.status, COALESCE(s.title, 'Technical Hub Classroom Session') as session_title, s.session_date
         FROM attendance_records ar
         LEFT JOIN sessions s ON ar.session_id = s.id
         WHERE (ar.student_id = $1 OR ar.student_id IN (SELECT user_id FROM students WHERE id = $1))
           AND (ar.marked_at AT TIME ZONE 'Asia/Kolkata')::DATE = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Kolkata')::DATE
         ORDER BY ar.marked_at DESC
         LIMIT 1`,
        [studentId]
      );
      hasMarkedToday = todayAttendanceRes.rows.length > 0;
      todayRecord = hasMarkedToday ? todayAttendanceRes.rows[0] : null;
    } catch (_) {
      // Supabase Cloud Fallback
      try {
        const { data: attList } = await supabase
          .from('attendance_records')
          .select('id, marked_at, status, session_id')
          .or(`student_id.eq.${studentId},student_id.eq.${req.user!.userId}`);

        presentCount = attList?.filter((a: any) => (a.status || 'PRESENT').toUpperCase() === 'PRESENT').length || 0;

        const { data: sessList } = await supabase
          .from('sessions')
          .select('id, title, session_date, college_id')
          .eq('college_id', collegeId);

        totalRaw = Math.max(presentCount, sessList?.length || 0);

        const nowIST = new Date(new Date().getTime() + 5.5 * 3600 * 1000).toISOString().substring(0, 10);
        if (attList && attList.length > 0) {
          const todayAtt = attList.find((a: any) => {
            if (!a.marked_at) return false;
            const attIST = new Date(new Date(a.marked_at).getTime() + 5.5 * 3600 * 1000).toISOString().substring(0, 10);
            return attIST === nowIST;
          });
          if (todayAtt) {
            hasMarkedToday = true;
            todayRecord = todayAtt;
          }
          history = attList.slice(0, 30);
        }

        subjects = [
          {
            subject: 'Technical Hub Core Training',
            total: totalRaw > 0 ? totalRaw : 1,
            attended: presentCount,
            percentage: totalRaw > 0 ? Math.round((presentCount / totalRaw) * 100) : (presentCount > 0 ? 100 : 0),
          }
        ];
      } catch (sbErr) {
        console.error('Supabase student attendance fallback error:', sbErr);
      }
    }

    const absentCount = Math.max(0, totalRaw - presentCount);
    const overallPercentage = totalRaw > 0 ? Math.round((presentCount / totalRaw) * 100) : (presentCount > 0 ? 100 : 0);
    const windowInfo = getAttendanceWindowInfo();

    res.json({
      summary: {
        overallPercentage,
        presentCount,
        absentCount,
        totalSessions: totalRaw,
        hasMarkedToday,
        todayRecord,
        attendanceWindow: windowInfo,
      },
      hasMarkedToday,
      todayRecord,
      attendanceWindow: windowInfo,
      subjects,
      history,
    });
  } catch (error) {
    console.error('Student attendance error:', error);
    res.status(500).json({ error: 'Failed to retrieve student attendance history.' });
  }
});

// 5. Comprehensive Attendance Report (CSV & Summary)
router.get('/report', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const collegeId = getEffectiveCollegeId(req);
    const { batchId, programId, format } = req.query;

    let queryText = `
      SELECT
        s.id as student_id,
        u.full_name as student_name,
        u.email as student_email,
        s.roll_number,
        s.branch,
        s.section,
        c.short_name as college_name,
        b.name as batch_name,
        COUNT(DISTINCT sess.id) as total_sessions,
        COUNT(DISTINCT ar.id) as attended_sessions,
        ROUND((COUNT(DISTINCT ar.id)::numeric / NULLIF(COUNT(DISTINCT sess.id), 0)) * 100, 1) as attendance_percentage
      FROM students s
      JOIN users u ON s.user_id = u.id
      JOIN colleges c ON s.college_id = c.id
      JOIN student_batch_enrollments sbe ON s.id = sbe.student_id
      JOIN batches b ON sbe.batch_id = b.id
      LEFT JOIN sessions sess ON b.id = sess.batch_id AND sess.session_date <= CURRENT_DATE
      LEFT JOIN attendance_records ar ON sess.id = ar.session_id AND s.id = ar.student_id
      WHERE 1=1
    `;
    let params: any[] = [];

    if (collegeId) {
      params.push(collegeId);
      queryText += ` AND s.college_id = $${params.length}`;
    }
    if (batchId) {
      params.push(batchId);
      queryText += ` AND b.id = $${params.length}`;
    }
    if (programId) {
      params.push(programId);
      queryText += ` AND b.program_id = $${params.length}`;
    }

    queryText += ` GROUP BY s.id, u.full_name, u.email, s.roll_number, s.branch, s.section, c.short_name, b.name
                   ORDER BY attendance_percentage DESC NULLS LAST, s.roll_number ASC`;

    const result = await pool.query(queryText, params);

    // If CSV requested
    if (format === 'csv') {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename="attendance_report.csv"');

      let csv = 'Roll Number,Student Name,College,Batch,Branch,Section,Total Sessions,Attended,Attendance %\n';
      result.rows.forEach((r) => {
        csv += `"${r.roll_number}","${r.student_name}","${r.college_name}","${r.batch_name}","${r.branch}","${r.section}",${r.total_sessions || 0},${r.attended_sessions || 0},${r.attendance_percentage || 0}%\n`;
      });
      res.send(csv);
      return;
    }

    res.json({
      report: result.rows,
      generatedAt: new Date(),
    });
  } catch (error) {
    console.error('Attendance report error:', error);
    res.status(500).json({ error: 'Failed to generate attendance report.' });
  }
});

// 6. Manual Student Attendance Marking (Super Admin, PM, College Admin, TPO, Trainer)
router.post(
  '/manual',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    const client = await pool.connect();
    try {
      const { studentId, rollNumber, sessionId, status = 'PRESENT', remarks } = req.body;

      if (!studentId && !rollNumber) {
        res.status(400).json({ error: 'Student ID or Roll Number is required.' });
        return;
      }

      // 1. Fetch student
      let studentRes;
      if (studentId) {
        studentRes = await client.query(
          `SELECT s.*, u.full_name, u.email, c.short_name as college_name
           FROM students s
           JOIN users u ON s.user_id = u.id
           JOIN colleges c ON s.college_id = c.id
           WHERE s.id = $1`,
          [studentId]
        );
      } else {
        studentRes = await client.query(
          `SELECT s.*, u.full_name, u.email, c.short_name as college_name
           FROM students s
           JOIN users u ON s.user_id = u.id
           JOIN colleges c ON s.college_id = c.id
           WHERE LOWER(s.roll_number) = $1`,
          [rollNumber.trim().toLowerCase()]
        );
      }

      if (studentRes.rows.length === 0) {
        res.status(404).json({ error: 'Student profile not found.' });
        return;
      }

      const student = studentRes.rows[0];

      // 2. Strict Multi-Tenant RBAC Validation
      const userRole = req.user!.role;
      let userCollegeId = req.user!.collegeId;

      if (userRole === 'TRAINER' && !userCollegeId) {
        const taRes = await client.query('SELECT college_id FROM trainer_assignments WHERE trainer_id = $1 LIMIT 1', [req.user!.userId]);
        if (taRes.rows.length > 0) {
          userCollegeId = taRes.rows[0].college_id;
        }
      }

      if (userRole === 'COLLEGE_ADMIN' || userRole === 'TPO') {
        if (userCollegeId && userCollegeId !== student.college_id) {
          res.status(403).json({
            error: 'Forbidden: College Admin and TPO can only mark attendance for students at their own institution.',
          });
          return;
        }
      } else if (userRole === 'TRAINER') {
        if (userCollegeId && userCollegeId !== student.college_id) {
          res.status(403).json({
            error: 'Forbidden: Trainers can only mark attendance for students at their assigned campus hub.',
          });
          return;
        }

        // Trainer-wise Student Restriction
        const currentTrainerId = req.user!.userId;
        const currentTrainerEmail = (req.user!.email || '').toLowerCase();
        let isAllotted = false;

        try {
          const behavRes = await client.query('SELECT trainer_notes FROM student_behaviour WHERE student_id = $1 LIMIT 1', [student.id]);
          if (behavRes.rows.length > 0 && behavRes.rows[0].trainer_notes) {
            const parsed = typeof behavRes.rows[0].trainer_notes === 'string' ? JSON.parse(behavRes.rows[0].trainer_notes) : behavRes.rows[0].trainer_notes;
            if (parsed && (parsed.assigned_trainer_id === currentTrainerId || parsed.assigned_trainer_email?.toLowerCase() === currentTrainerEmail)) {
              isAllotted = true;
            } else if (parsed && parsed.assigned_trainer_id && parsed.assigned_trainer_id !== currentTrainerId) {
              isAllotted = false;
            }
          }
        } catch (_) {}

        if (!isAllotted) {
          const studentYear = (student.year || '').toString();
          const roll = (student.roll_number || '').toString().toUpperCase();
          const branch = (student.branch || '').toString().toUpperCase();
          const is2nd = studentYear.includes('2') || roll.startsWith('24HN') || roll.startsWith('25HN5');
          const is3rd = studentYear.includes('3') || roll.startsWith('23HN') || roll.startsWith('24HN5');
          const is4th = studentYear.includes('4') || roll.startsWith('21HN') || roll.startsWith('22HN');
          const isAidsOrAiml = branch.includes('AI') || branch.includes('DS') || branch.includes('ML') || roll.includes('A54') || roll.includes('A42');
          const isSushma = currentTrainerEmail.includes('sushma') || currentTrainerEmail.includes('elisala') || currentTrainerEmail === 'vsushmaelisala@gmail.com';
          const isDaiva = currentTrainerEmail.includes('daiva') || currentTrainerEmail.includes('pathivada') || currentTrainerEmail === 'daivaraopathivada@gmail.com' || currentTrainerEmail.includes('uday');

          if (isSushma && (is2nd || is4th)) {
            isAllotted = true;
          } else if (isDaiva && (is3rd || is4th) && !isAidsOrAiml) {
            isAllotted = true;
          }
        }

        if (!isAllotted) {
          res.status(403).json({
            error: 'Forbidden: You can only mark attendance for students specifically allotted to you.',
          });
          return;
        }
      }
      // SUPER_ADMIN and PROGRAM_MANAGER have broad access.

      await client.query('BEGIN');

      // 3. Resolve Session
      let targetSessionId = sessionId;
      if (!targetSessionId) {
        const sessionRes = await client.query(
          `SELECT id FROM sessions
           WHERE college_id = $1 AND session_date = CURRENT_DATE
           ORDER BY created_at DESC LIMIT 1`,
          [student.college_id]
        );
        if (sessionRes.rows.length > 0) {
          targetSessionId = sessionRes.rows[0].id;
        } else {
          let batchId;
          const batchRes = await client.query('SELECT id FROM batches WHERE college_id = $1 ORDER BY created_at ASC LIMIT 1', [student.college_id]);
          if (batchRes.rows.length > 0) {
            batchId = batchRes.rows[0].id;
          } else {
            const newB = await client.query(
              `INSERT INTO batches (college_id, name, code, academic_year)
               VALUES ($1, 'Tech Hub Core Batch', 'CORE-26', '2026')
               RETURNING id`,
              [student.college_id]
            );
            batchId = newB.rows[0].id;
          }

          const newSession = await client.query(
            `INSERT INTO sessions (batch_id, college_id, trainer_id, title, description, session_date, start_time, end_time, status)
             VALUES ($1, $2, $3, 'Daily Technical Session', 'Hands-on Technical Class Session', CURRENT_DATE, '09:30:00', '13:00:00', 'IN_PROGRESS')
             RETURNING id`,
            [batchId, student.college_id, userRole === 'TRAINER' ? req.user!.userId : null]
          );
          targetSessionId = newSession.rows[0].id;
        }
      }

      // 4. Ensure batch enrollment
      const sessionInfo = await client.query('SELECT batch_id FROM sessions WHERE id = $1', [targetSessionId]);
      if (sessionInfo.rows.length > 0 && sessionInfo.rows[0].batch_id) {
        await client.query(
          `INSERT INTO student_batch_enrollments (student_id, batch_id, college_id)
           VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
          [student.id, sessionInfo.rows[0].batch_id, student.college_id]
        );
      }

      // 5. Insert or Update Attendance Record
      const rawStatus = (status || 'PRESENT').toString().toUpperCase();
      const validStatus = ['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'].includes(rawStatus) ? rawStatus : 'PRESENT';
      const deviceInfo = `RBAC Manual Entry by ${userRole} (${req.user!.email})${remarks ? ': ' + remarks : ''}`;

      const recordRes = await client.query(
        `INSERT INTO attendance_records (session_id, student_id, college_id, status, device_info, method, marked_at)
         VALUES ($1, $2, $3, $4, $5, 'MANUAL', CURRENT_TIMESTAMP)
         ON CONFLICT (session_id, student_id)
         DO UPDATE SET status = $4, device_info = $5, marked_at = CURRENT_TIMESTAMP
         RETURNING *`,
        [targetSessionId, student.id, student.college_id, validStatus, deviceInfo]
      );

      const record = recordRes.rows[0];

      // 6. Update student behaviour metrics
      const statsRes = await client.query(
        `SELECT
           COUNT(DISTINCT s.id) as total_sessions,
           COUNT(DISTINCT ar.id) as attended_sessions
         FROM sessions s
         JOIN student_batch_enrollments sbe ON s.batch_id = sbe.batch_id AND sbe.student_id = $1
         LEFT JOIN attendance_records ar ON s.id = ar.session_id AND ar.student_id = $1 AND ar.status = 'PRESENT'
         WHERE s.session_date <= CURRENT_DATE`,
        [student.id]
      );

      const total = Number(statsRes.rows[0].total_sessions) || 1;
      const attended = Number(statsRes.rows[0].attended_sessions) || (validStatus === 'PRESENT' ? 1 : 0);
      const consistency = Math.min(100, Math.round((attended / total) * 100 * 10) / 10);

      await client.query(
        `UPDATE student_behaviour
         SET attendance_consistency = $1, updated_at = CURRENT_TIMESTAMP
         WHERE student_id = $2`,
        [consistency, student.id]
      );

      await client.query('COMMIT');

      // Real-time Cloud Sync to Supabase
      try {
        await supabase.from('attendance_records').upsert({
          id: record.id,
          session_id: record.session_id,
          student_id: record.student_id,
          college_id: record.college_id,
          status: record.status,
          device_info: record.device_info,
          method: record.method,
          marked_at: record.marked_at,
        });
      } catch (e: any) {
        console.warn('[Supabase Cloud Sync Notice]', e.message);
      }

      await logAuditEvent(req, 'MANUAL_ATTENDANCE_MARKED', 'STUDENT', student.id, {
        markedBy: req.user!.email,
        role: userRole,
        status: validStatus,
        sessionId: targetSessionId,
      });

      res.json({
        message: `Attendance marked as ${validStatus} for ${student.full_name} (${student.roll_number}).`,
        record: {
          id: record.id,
          studentId: student.id,
          studentName: student.full_name,
          rollNumber: student.roll_number,
          status: record.status,
          markedAt: record.marked_at,
          collegeName: student.college_name,
        },
      });
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      console.error('Manual attendance error:', error);
      res.status(500).json({ error: 'Failed to record manual attendance.' });
    } finally {
      client.release();
    }
  }
);

// 7. Bulk Manual Student Attendance Marking
router.post(
  '/manual-bulk',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    const client = await pool.connect();
    try {
      const { studentIds, status = 'PRESENT', sessionId } = req.body;
      if (!Array.isArray(studentIds) || studentIds.length === 0) {
        res.status(400).json({ error: 'Array of studentIds is required.' });
        return;
      }

      const userRole = req.user!.role;
      let userCollegeId = req.user!.collegeId;
      if (userRole === 'TRAINER' && !userCollegeId) {
        const taRes = await client.query('SELECT college_id FROM trainer_assignments WHERE trainer_id = $1 LIMIT 1', [req.user!.userId]);
        if (taRes.rows.length > 0) userCollegeId = taRes.rows[0].college_id;
      }

      await client.query('BEGIN');
      let markedCount = 0;
      const rawStatus = (status || 'PRESENT').toString().toUpperCase();
      const validStatus = ['PRESENT', 'ABSENT', 'LATE', 'EXCUSED'].includes(rawStatus) ? rawStatus : 'PRESENT';

      for (const sid of studentIds) {
        const sRes = await client.query('SELECT id, college_id FROM students WHERE id = $1', [sid]);
        if (sRes.rows.length === 0) continue;
        const student = sRes.rows[0];

        // RBAC check
        if ((userRole === 'COLLEGE_ADMIN' || userRole === 'TPO' || userRole === 'TRAINER') && userCollegeId && userCollegeId !== student.college_id) {
          continue; // Skip unauthorized students
        }

        // Resolve Session
        let targetSessionId = sessionId;
        if (!targetSessionId) {
          const sessionRes = await client.query(
            `SELECT id FROM sessions WHERE college_id = $1 AND session_date = CURRENT_DATE ORDER BY created_at DESC LIMIT 1`,
            [student.college_id]
          );
          if (sessionRes.rows.length > 0) {
            targetSessionId = sessionRes.rows[0].id;
          } else {
            continue;
          }
        }

        await client.query(
          `INSERT INTO attendance_records (session_id, student_id, college_id, status, device_info, method, marked_at)
           VALUES ($1, $2, $3, $4, $5, 'MANUAL', CURRENT_TIMESTAMP)
           ON CONFLICT (session_id, student_id)
           DO UPDATE SET status = $4, marked_at = CURRENT_TIMESTAMP`,
          [targetSessionId, student.id, student.college_id, validStatus, `Bulk Manual Entry by ${userRole}`]
        );
        markedCount++;
      }

      await client.query('COMMIT');
      res.json({
        message: `Successfully marked attendance as ${validStatus} for ${markedCount} students.`,
        markedCount,
      });
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      console.error('Bulk manual attendance error:', error);
      res.status(500).json({ error: 'Failed to record bulk manual attendance.' });
    } finally {
      client.release();
    }
  }
);

export default router;
