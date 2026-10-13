import { Router, Response } from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db/pool.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { getEffectiveCollegeId } from '../middleware/tenant.js';
import { logAuditEvent } from '../middleware/audit.js';
import { supabase } from '../db/supabase.js';

const router = Router();

// List Students (Authoritative cross-role nominal roster)
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const user = req.user!;
    let effectiveCollegeId: string | undefined = undefined;

    // RBAC Resolution
    if (user.role === 'SUPER_ADMIN' || user.role === 'PROGRAM_MANAGER') {
      const rawCol = (req.query.college_id as string) || (req.query.collegeId as string);
      if (rawCol && rawCol !== 'all') {
        effectiveCollegeId = rawCol;
      }
    } else if (user.role === 'COLLEGE_ADMIN' || user.role === 'TPO') {
      effectiveCollegeId = user.collegeId || (user as any)?.college_id || undefined;
      if (!effectiveCollegeId) {
        try {
          const uRes = await pool.query('SELECT college_id FROM users WHERE id = $1', [user.userId]);
          if (uRes.rows.length > 0) effectiveCollegeId = uRes.rows[0].college_id;
        } catch (_) {}
      }
      if (!effectiveCollegeId) {
        try {
          const { data: uSb } = await supabase.from('users').select('college_id').eq('id', user.userId).limit(1);
          if (uSb && uSb.length > 0 && uSb[0].college_id) effectiveCollegeId = uSb[0].college_id;
        } catch (_) {}
      }
      if (!effectiveCollegeId) {
        res.status(403).json({ success: false, error: 'Access denied: No college associated with your account.', students: [], total: 0 });
        return;
      }
    } else if (user.role === 'TRAINER') {
      effectiveCollegeId = user.collegeId || (user as any)?.college_id || undefined;
      const rawCol = (req.query.college_id as string) || (req.query.collegeId as string);
      if (rawCol && rawCol !== 'all') {
        effectiveCollegeId = rawCol;
      }
    } else if (user.role === 'STUDENT') {
      try {
        const sRes = await pool.query('SELECT id FROM students WHERE user_id = $1', [user.userId]);
        if (sRes.rows.length === 0) {
          // Check supabase
          const { data: sSb } = await supabase.from('students').select('id').eq('user_id', user.userId).limit(1);
          if (!sSb || sSb.length === 0) {
            res.json({ success: true, students: [], total: 0, presentCount: 0, absentCount: 0, pendingCount: 0, attendanceRate: 0, page: 1, limit: 50 });
            return;
          }
        }
      } catch (_) {}
    }

    const { branch, year, section, search, batch_id, attendance_status, page = '1', limit = '100' } = req.query;

    let queryText = `
      SELECT s.id, s.id as student_id, s.user_id, s.college_id, s.roll_number, s.registration_number,
             s.branch, s.year, s.section, s.gender, s.date_of_birth, s.aadhar_id, s.address, s.profile_photo,
             TO_CHAR(s.created_at, 'YYYY-MM-DD HH24:MI:SS') as registered_at,
             u.full_name, u.email, u.mobile, u.status as enrollment_status,
             c.short_name as college_name, c.college_name as full_college_name, c.logo_url as college_logo,
             COALESCE(sb.attendance_consistency, 90.0) as attendance_consistency,
             COALESCE(sb.participation, 85.0) as participation,
             COALESCE(sb.assignment_completion, 88.0) as assignment_completion,
             COALESCE(sb.assessment_performance, 82.0) as assessment_performance,
             COALESCE(sb.punctuality, 92.0) as punctuality,
             sb.trainer_notes,
             COALESCE(today_att.status, 'PENDING') as today_status,
             TO_CHAR(today_att.marked_at, 'HH24:MI:SS') as today_marked_time,
             today_att.method as today_method
      FROM students s
      JOIN users u ON s.user_id = u.id
      JOIN colleges c ON s.college_id = c.id
      LEFT JOIN student_behaviour sb ON s.id = sb.student_id
      LEFT JOIN LATERAL (
        SELECT ar.status, ar.marked_at, ar.method
        FROM attendance_records ar
        JOIN sessions sess ON ar.session_id = sess.id
        WHERE ar.student_id = s.id AND sess.session_date = CURRENT_DATE
        ORDER BY ar.marked_at DESC
        LIMIT 1
      ) today_att ON true
      WHERE 1=1
    `;
    let params: any[] = [];

    if (user.role === 'STUDENT') {
      params.push(user.userId);
      queryText += ` AND s.user_id = $${params.length}`;
    } else if (user.role === 'COLLEGE_ADMIN' || user.role === 'TPO') {
      // Must strictly filter to their own institutional college
      params.push(effectiveCollegeId);
      queryText += ` AND s.college_id = $${params.length}`;
    } else if (effectiveCollegeId && effectiveCollegeId !== 'all') {
      params.push(effectiveCollegeId);
      queryText += ` AND s.college_id = $${params.length}`;
    }

    if (branch && branch !== 'all') {
      params.push(branch);
      queryText += ` AND LOWER(s.branch) = LOWER($${params.length})`;
    }
    if (year && year !== 'all') {
      params.push(year);
      queryText += ` AND LOWER(s.year) = LOWER($${params.length})`;
    }
    if (section && section !== 'all') {
      params.push(section);
      queryText += ` AND LOWER(s.section) = LOWER($${params.length})`;
    }
    if (search && (search as string).trim()) {
      params.push(`%${(search as string).trim().toLowerCase()}%`);
      queryText += ` AND (
        LOWER(u.full_name) LIKE $${params.length} OR
        LOWER(s.roll_number) LIKE $${params.length} OR
        LOWER(u.email) LIKE $${params.length} OR
        LOWER(COALESCE(u.mobile, '')) LIKE $${params.length}
      )`;
    }
    if (attendance_status && attendance_status !== 'all') {
      params.push(attendance_status.toString().toUpperCase());
      queryText += ` AND COALESCE(today_att.status, 'PENDING') = $${params.length}`;
    }

    let allStudents: any[] = [];
    try {
      const allMatchedRes = await pool.query(queryText, params);
      allStudents = allMatchedRes.rows;
    } catch (dbErr) {
      console.warn('[STUDENTS-LIST] Local PG failed, falling back to Supabase:', (dbErr as Error).message);
      try {
        let sbQuery = supabase
          .from('students')
          .select('*, users!inner(full_name, email, mobile, status), colleges(short_name, college_name, logo_url), student_behaviour(attendance_consistency, participation, assignment_completion, assessment_performance, punctuality, trainer_notes)');

        if (user.role === 'STUDENT') {
          sbQuery = sbQuery.eq('user_id', user.userId);
        } else if (effectiveCollegeId && effectiveCollegeId !== 'all') {
          sbQuery = sbQuery.eq('college_id', effectiveCollegeId);
        }

        const { data: sbRows, error: sbErr } = await sbQuery.order('roll_number', { ascending: true }).limit(500);
        if (!sbErr && sbRows) {
          // Fetch today's attendance records to accurately reflect who is PRESENT today
          const nowIST = new Date(new Date().getTime() + 5.5 * 3600 * 1000).toISOString().substring(0, 10);
          const { data: todayAtts } = await supabase
            .from('attendance_records')
            .select('student_id, status, marked_at, method');

          const todayAttMap = new Map<string, any>();
          if (todayAtts) {
            for (const att of todayAtts) {
              if (att.marked_at) {
                const attIST = new Date(new Date(att.marked_at).getTime() + 5.5 * 3600 * 1000).toISOString().substring(0, 10);
                if (attIST === nowIST) {
                  todayAttMap.set(att.student_id, att);
                }
              }
            }
          }

          allStudents = sbRows.map(s => {
            const bh = (Array.isArray(s.student_behaviour) && s.student_behaviour.length > 0)
              ? s.student_behaviour[0]
              : (s.student_behaviour || {});
            const todayRecord = todayAttMap.get(s.id);

            return {
              id: s.id,
              student_id: s.id,
              user_id: s.user_id,
              college_id: s.college_id,
              roll_number: s.roll_number,
              registration_number: s.registration_number,
              branch: s.branch,
              year: s.year,
              section: s.section,
              gender: s.gender,
              date_of_birth: s.date_of_birth,
              aadhar_id: s.aadhar_id,
              address: s.address,
              profile_photo: s.profile_photo,
              registered_at: s.created_at,
              full_name: s.users?.full_name || s.roll_number,
              email: s.users?.email || '',
              mobile: s.users?.mobile || '',
              enrollment_status: s.users?.status || 'ACTIVE',
              college_name: s.colleges?.short_name || 'Tech Hub Campus',
              full_college_name: s.colleges?.college_name || 'Tech Hub Campus',
              college_logo: s.colleges?.logo_url,
              attendance_consistency: Number(bh.attendance_consistency) || 0.0,
              participation: Number(bh.participation) || 0.0,
              assignment_completion: Number(bh.assignment_completion) || 0.0,
              assessment_performance: Number(bh.assessment_performance) || 0.0,
              punctuality: Number(bh.punctuality) || 0.0,
              trainer_notes: bh.trainer_notes,
              today_status: todayRecord ? todayRecord.status : 'PENDING',
              today_marked_time: todayRecord ? todayRecord.marked_at : null,
              today_method: todayRecord ? todayRecord.method : null,
            };
          });
        }
      } catch (sbEx) {
        console.warn('[STUDENTS-LIST] Supabase query error:', sbEx);
      }
    }

    // Attach assigned trainer to every student
    const sushmaTrainer = {
      id: '48632025-1678-4014-925a-86391063614b',
      full_name: 'Sushma Elisala',
      name: 'Sushma Elisala',
      email: 'vsushmaelisala@gmail.com',
      course_name: 'Python Full stack',
      mobile: '+91 98888 33333',
    };
    const daivaTrainer = {
      id: '0ed2be5c-fce6-4e4f-83eb-96be2b162746',
      full_name: 'Pathivada Daiva Rao',
      name: 'Pathivada Daiva Rao',
      email: 'daivaraopathivada@gmail.com',
      course_name: 'Java full stack',
      mobile: '+91 98888 44444',
    };

    let enrichedStudents = allStudents.map(s => {
      let assignedTrainer = null;
      if (s.trainer_notes) {
        try {
          const parsed = typeof s.trainer_notes === 'string' ? JSON.parse(s.trainer_notes) : s.trainer_notes;
          if (parsed && (parsed.assigned_trainer_name || parsed.assigned_trainer_id)) {
            assignedTrainer = {
              id: parsed.assigned_trainer_id,
              full_name: parsed.assigned_trainer_name,
              name: parsed.assigned_trainer_name,
              email: parsed.assigned_trainer_email || '',
              course_name: parsed.course_name || 'Python Full stack',
            };
          }
        } catch (_) {}
      }

      if (!assignedTrainer) {
        const studentYear = (s.year || '').toString();
        const roll = (s.roll_number || '').toString().toUpperCase();
        const branch = (s.branch || '').toString().toUpperCase();
        const is2nd = studentYear.includes('2') || roll.startsWith('24HN') || roll.startsWith('25HN5');
        const is4th = studentYear.includes('4') || roll.startsWith('21HN') || roll.startsWith('22HN');
        const isAidsOrAiml = branch.includes('AI') || branch.includes('DS') || branch.includes('ML') || roll.includes('A54') || roll.includes('A42');

        if (is2nd || (is4th && isAidsOrAiml)) {
          assignedTrainer = sushmaTrainer;
        } else {
          assignedTrainer = daivaTrainer;
        }
      }

      return {
        ...s,
        assignedTrainer,
        assigned_trainer: assignedTrainer,
      };
    });

    // 3. Trainer-wise Student Restriction:
    // If request is made by a TRAINER, strictly restrict the roster to ONLY their allotted students!
    if (req.user!.role === 'TRAINER') {
      const currentTrainerId = req.user!.userId;
      const currentTrainerEmail = (req.user!.email || '').toLowerCase();

      enrichedStudents = enrichedStudents.filter(s => {
        const at = s.assignedTrainer;
        if (!at) return false;
        if (at.id && at.id === currentTrainerId) return true;
        if (at.email && at.email.toLowerCase() === currentTrainerEmail) return true;
        if ((currentTrainerEmail.includes('sushma') || currentTrainerEmail.includes('elisala') || currentTrainerEmail === 'vsushmaelisala@gmail.com') && (at.email?.includes('sushma') || at.name?.includes('Sushma') || at.name?.includes('Elisala') || at.email?.includes('elisala'))) return true;
        if ((currentTrainerEmail.includes('daiva') || currentTrainerEmail.includes('pathivada') || currentTrainerEmail === 'daivaraopathivada@gmail.com' || currentTrainerEmail.includes('uday')) && (at.email?.includes('daiva') || at.name?.includes('Daiva') || at.name?.includes('Pathivada'))) return true;
        return false;
      });
    }

    // Overall metrics for the current campus / portal scope
    const totalRegistered = enrichedStudents.length;
    const presentCount = enrichedStudents.filter(s => s.today_status === 'PRESENT').length;
    const absentCount = enrichedStudents.filter(s => s.today_status === 'ABSENT').length;
    const pendingCount = enrichedStudents.filter(s => s.today_status === 'PENDING').length;
    const attendanceRate = totalRegistered > 0 ? Math.round((presentCount / totalRegistered) * 100) : 0;

    // Apply filters (branch, year, section, search, attendance_status) for the table/list
    let filteredStudents = enrichedStudents;
    if (branch && branch !== 'all') {
      filteredStudents = filteredStudents.filter(s => (s.branch || '').toLowerCase() === (branch as string).toLowerCase());
    }
    if (year && year !== 'all') {
      filteredStudents = filteredStudents.filter(s => (s.year || '').toLowerCase() === (year as string).toLowerCase());
    }
    if (section && section !== 'all') {
      filteredStudents = filteredStudents.filter(s => (s.section || '').toLowerCase() === (section as string).toLowerCase());
    }
    if (search && (search as string).trim()) {
      const q = (search as string).trim().toLowerCase();
      filteredStudents = filteredStudents.filter(s =>
        (s.full_name || '').toLowerCase().includes(q) ||
        (s.roll_number || '').toLowerCase().includes(q) ||
        (s.email || '').toLowerCase().includes(q) ||
        (s.mobile || '').toLowerCase().includes(q)
      );
    }
    if (attendance_status && attendance_status !== 'all') {
      const statusUpper = attendance_status.toString().toUpperCase();
      if (statusUpper === 'PRESENT') {
        filteredStudents = filteredStudents.filter(s => s.today_status === 'PRESENT');
      } else if (statusUpper === 'ABSENT') {
        filteredStudents = filteredStudents.filter(s => s.today_status === 'ABSENT' || s.today_status === 'PENDING');
      } else if (statusUpper === 'PENDING') {
        filteredStudents = filteredStudents.filter(s => s.today_status === 'PENDING');
      }
    }

    const pageNum = Math.max(1, parseInt(page as string) || 1);
    const limitNum = Math.min(500, Math.max(1, parseInt(limit as string) || 100));
    const offset = (pageNum - 1) * limitNum;
    const paginatedStudents = filteredStudents.slice(offset, offset + limitNum);

    res.json({
      success: true,
      students: paginatedStudents,
      total: totalRegistered,
      filteredCount: filteredStudents.length,
      presentCount,
      absentCount,
      pendingCount,
      attendanceRate,
      page: pageNum,
      limit: limitNum,
    });
  } catch (error) {
    console.error('Fetch students error:', error);
    res.status(500).json({ error: 'Failed to fetch students list.' });
  }
});

// Get Student by ID (Full Profile & Attendance History)
router.get('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    let student: any = null;
    let history: any[] = [];
    let totalSessions = 0;
    let presentCount = 0;
    let absentCount = 0;
    let lateCount = 0;
    let attendancePercentage = 90;

    try {
      const result = await pool.query(
        `SELECT s.*, s.id as student_id, u.full_name, u.email, u.mobile, u.status as user_status,
                c.short_name as college_name, c.college_name as full_college_name, c.logo_url as college_logo,
                b.id as batch_id, b.name as batch_name, p.name as program_name,
                COALESCE(sb.attendance_consistency, 90.0) as attendance_consistency,
                COALESCE(sb.participation, 85.0) as participation,
                COALESCE(sb.assignment_completion, 88.0) as assignment_completion,
                COALESCE(sb.assessment_performance, 82.0) as assessment_performance,
                COALESCE(sb.punctuality, 92.0) as punctuality,
                sb.trainer_notes
         FROM students s
         JOIN users u ON s.user_id = u.id
         JOIN colleges c ON s.college_id = c.id
         LEFT JOIN student_batch_enrollments sbe ON s.id = sbe.student_id
         LEFT JOIN batches b ON sbe.batch_id = b.id
         LEFT JOIN programs p ON b.program_id = p.id
         LEFT JOIN student_behaviour sb ON s.id = sb.student_id
         WHERE s.id = $1`,
        [id]
      );

      if (result.rows.length > 0) {
        student = result.rows[0];
      }
    } catch (_) {}

    if (!student) {
      // Supabase fallback
      try {
        const { data: sData, error: sErr } = await supabase
          .from('students')
          .select('*, users!inner(full_name, email, mobile, status), colleges(short_name, college_name, logo_url), student_behaviour(attendance_consistency, participation, assignment_completion, assessment_performance, punctuality, trainer_notes)')
          .eq('id', id)
          .limit(1);

        if (!sErr && sData && sData.length > 0) {
          const s = sData[0];
          const bh = (Array.isArray(s.student_behaviour) && s.student_behaviour.length > 0)
            ? s.student_behaviour[0]
            : (s.student_behaviour || {});
          student = {
            id: s.id,
            student_id: s.id,
            user_id: s.user_id,
            college_id: s.college_id,
            roll_number: s.roll_number,
            registration_number: s.registration_number,
            branch: s.branch,
            year: s.year,
            section: s.section,
            gender: s.gender,
            date_of_birth: s.date_of_birth,
            aadhar_id: s.aadhar_id,
            address: s.address,
            profile_photo: s.profile_photo,
            full_name: s.users?.full_name || s.roll_number,
            email: s.users?.email || '',
            mobile: s.users?.mobile || '',
            user_status: s.users?.status || 'ACTIVE',
            college_name: s.colleges?.short_name || 'Tech Hub Campus',
            full_college_name: s.colleges?.college_name || 'Tech Hub Campus',
            college_logo: s.colleges?.logo_url,
            attendance_consistency: bh.attendance_consistency ?? 90.0,
            participation: bh.participation ?? 85.0,
            assignment_completion: bh.assignment_completion ?? 88.0,
            assessment_performance: bh.assessment_performance ?? 82.0,
            punctuality: bh.punctuality ?? 92.0,
            trainer_notes: bh.trainer_notes,
          };
        }
      } catch (_) {}
    }

    if (!student) {
      res.status(404).json({ error: 'Student not found.' });
      return;
    }

    // Strict Multi-Tenant RBAC Enforcement
    if (req.user!.role !== 'SUPER_ADMIN' && req.user!.role !== 'PROGRAM_MANAGER') {
      if (req.user!.role === 'STUDENT') {
        if (req.user!.userId !== student.user_id) {
          res.status(403).json({ error: 'Forbidden: You can only view your own profile.' });
          return;
        }
      } else if (req.user!.role === 'COLLEGE_ADMIN' || req.user!.role === 'TPO') {
        let userCollege = req.user!.collegeId || (req.user as any)?.college_id;
        if (!userCollege || userCollege !== student.college_id) {
          res.status(403).json({ error: 'Forbidden: Cannot access student records from another college.' });
          return;
        }
      } else if (req.user!.role === 'TRAINER') {
        const currentTrainerId = req.user!.userId;
        const currentTrainerEmail = (req.user!.email || '').toLowerCase();
        let isAllotted = false;

        if (student.trainer_notes) {
          try {
            const parsed = typeof student.trainer_notes === 'string' ? JSON.parse(student.trainer_notes) : student.trainer_notes;
            if (parsed && (parsed.assigned_trainer_id === currentTrainerId || parsed.assigned_trainer_email?.toLowerCase() === currentTrainerEmail)) {
              isAllotted = true;
            } else if (parsed && parsed.assigned_trainer_id && parsed.assigned_trainer_id !== currentTrainerId) {
              isAllotted = false;
            }
          } catch (_) {}
        }

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
          res.status(403).json({ error: 'Forbidden: You only have access to students specifically allotted to you.' });
          return;
        }
      }
    }

    try {
      // Fetch Lifetime Attendance Metrics
      const attStats = await pool.query(
        `SELECT
           COUNT(id) as total_marked,
           COUNT(id) FILTER (WHERE status = 'PRESENT') as present_count,
           COUNT(id) FILTER (WHERE status = 'ABSENT') as absent_count,
           COUNT(id) FILTER (WHERE status = 'LATE') as late_count
         FROM attendance_records
         WHERE student_id = $1`,
        [id]
      );

      const historyRes = await pool.query(
        `SELECT ar.id, ar.status, ar.method,
                TO_CHAR(ar.marked_at, 'YYYY-MM-DD HH24:MI:SS') as marked_at,
                s.title as session_title,
                TO_CHAR(s.session_date, 'YYYY-MM-DD') as session_date,
                TO_CHAR(s.start_time, 'HH24:MI') as start_time,
                TO_CHAR(s.end_time, 'HH24:MI') as end_time,
                u.full_name as trainer_name
         FROM attendance_records ar
         JOIN sessions s ON ar.session_id = s.id
         LEFT JOIN users u ON s.trainer_id = u.id
         WHERE ar.student_id = $1
         ORDER BY s.session_date DESC, ar.marked_at DESC
         LIMIT 20`,
        [id]
      );

      const stats = attStats.rows[0];
      totalSessions = parseInt(stats?.total_marked) || 0;
      presentCount = parseInt(stats?.present_count) || 0;
      absentCount = parseInt(stats?.absent_count) || 0;
      lateCount = parseInt(stats?.late_count) || 0;
      attendancePercentage = totalSessions > 0 ? Math.round((presentCount / totalSessions) * 100) : Number(student.attendance_consistency) || 90;
      history = historyRes.rows;
    } catch (_) {}

    res.json({
      success: true,
      student,
      attendance: {
        totalSessions,
        presentCount,
        absentCount,
        lateCount,
        attendancePercentage,
        history,
      },
    });
  } catch (error) {
    console.error('Get student details error:', error);
    res.status(500).json({ error: 'Failed to fetch student details.' });
  }
});

// Create Student Directly (Without OTP verification - SUPER_ADMIN, PROGRAM_MANAGER, COLLEGE_ADMIN)
router.post('/', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  const client = await pool.connect();
  try {
    const {
      fullName,
      email,
      mobile,
      password,
      collegeId: rawCollegeId,
      rollNumber,
      registrationNumber,
      branch,
      year,
      section,
      gender,
      dob,
      dateOfBirth,
      aadharId,
      address,
    } = req.body;

    // College admin can only create students in their own college
    let targetCollegeId = rawCollegeId;
    if (req.user!.role === 'COLLEGE_ADMIN') {
      targetCollegeId = req.user!.collegeId;
    }

    if (!fullName || !email || !rollNumber || !targetCollegeId || !branch || !year || !section) {
      res.status(400).json({ error: 'Full name, email, roll number, college, branch, year, and section are required.' });
      return;
    }

    const normalizedEmail = email.trim().toLowerCase();
    const cleanRoll = rollNumber.trim().toUpperCase();

    // Check college existence
    const collegeCheck = await client.query('SELECT id, short_name FROM colleges WHERE id = $1', [targetCollegeId]);
    if (collegeCheck.rows.length === 0) {
      res.status(404).json({ error: 'Selected college does not exist.' });
      return;
    }

    // Check duplicate email
    const emailCheck = await client.query('SELECT id FROM users WHERE LOWER(email) = $1', [normalizedEmail]);
    if (emailCheck.rows.length > 0) {
      res.status(400).json({ error: 'A user account with this email address already exists.' });
      return;
    }

    // Check duplicate roll number in college
    const rollCheck = await client.query('SELECT id FROM students WHERE college_id = $1 AND UPPER(roll_number) = $2', [targetCollegeId, cleanRoll]);
    if (rollCheck.rows.length > 0) {
      res.status(400).json({ error: `Roll number ${cleanRoll} is already registered in ${collegeCheck.rows[0].short_name}.` });
      return;
    }

    await client.query('BEGIN');

    const defaultPassword = password?.trim() || 'Student@123';
    const passwordHash = await bcrypt.hash(defaultPassword, 10);

    // 1. Create User
    const userRes = await client.query(
      `INSERT INTO users (email, password_hash, role, full_name, mobile, college_id, status)
       VALUES ($1, $2, 'STUDENT', $3, $4, $5, 'ACTIVE')
       RETURNING id, email, full_name, mobile, role, college_id, status, created_at`,
      [normalizedEmail, passwordHash, fullName.trim(), mobile?.trim() || null, targetCollegeId]
    );
    const newUser = userRes.rows[0];

    // 2. Create Student Record
    const studentDob = dob || dateOfBirth || null;
    const studentRes = await client.query(
      `INSERT INTO students (user_id, college_id, roll_number, registration_number, branch, year, section, gender, date_of_birth, aadhar_id, address)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        newUser.id,
        targetCollegeId,
        cleanRoll,
        registrationNumber?.trim() || null,
        branch.trim(),
        year.toString().trim(),
        section.trim().toUpperCase(),
        gender?.trim() || null,
        studentDob,
        aadharId?.trim() || null,
        address?.trim() || null,
      ]
    );
    const newStudent = studentRes.rows[0];

    // 3. Initialize default behaviour scores
    await client.query(
      `INSERT INTO student_behaviour (student_id, college_id, attendance_consistency, participation, assignment_completion, assessment_performance, punctuality)
       VALUES ($1, $2, 95.0, 90.0, 88.0, 85.0, 95.0)
       ON CONFLICT (student_id) DO NOTHING`,
      [newStudent.id, targetCollegeId]
    );

    await client.query('COMMIT');

    // Real-time Cloud Synchronization (Supabase PostgreSQL)
    try {
      await supabase.from('users').upsert({
        id: newUser.id,
        email: normalizedEmail,
        password_hash: passwordHash,
        role: 'STUDENT',
        full_name: fullName.trim(),
        mobile: mobile?.trim() || null,
        college_id: targetCollegeId,
        status: 'ACTIVE',
      });

      const studentSupabaseData: any = {
        id: newStudent.id,
        user_id: newUser.id,
        college_id: targetCollegeId,
        roll_number: cleanRoll,
        registration_number: registrationNumber?.trim() || null,
        branch: branch.trim(),
        year: year.toString().trim(),
        section: section.trim().toUpperCase(),
        gender: gender?.trim() || null,
        date_of_birth: studentDob,
      };
      if (aadharId?.trim()) studentSupabaseData.aadhar_id = aadharId.trim();
      if (address?.trim()) studentSupabaseData.address = address.trim();

      const { error: studentSyncErr } = await supabase.from('students').upsert(studentSupabaseData);
      if (studentSyncErr) {
        delete studentSupabaseData.aadhar_id;
        delete studentSupabaseData.address;
        await supabase.from('students').upsert(studentSupabaseData);
      }
      console.log(`[Supabase Cloud Sync] Direct student creation synced to Supabase: ${cleanRoll}`);
    } catch (syncErr: any) {
      console.warn('[Supabase Cloud Sync Notice] Handled direct student creation notice:', syncErr.message);
    }

    await logAuditEvent(req, 'DIRECT_STUDENT_CREATION', 'STUDENT', newStudent.id, {
      createdById: req.user!.userId,
      createdByEmail: req.user!.email,
      createdRole: req.user!.role,
      studentEmail: normalizedEmail,
      rollNumber: cleanRoll,
      collegeId: targetCollegeId,
      bypassedOtp: true,
    });

    res.status(201).json({
      message: 'Student account successfully created without OTP verification.',
      student: {
        ...newStudent,
        full_name: newUser.full_name,
        email: newUser.email,
        mobile: newUser.mobile,
        college_name: collegeCheck.rows[0].short_name,
      },
      user: newUser,
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Direct student creation error:', error);
    res.status(500).json({ error: error.message || 'Failed to create student account.' });
  } finally {
    client.release();
  }
});

// Delete Student
router.delete('/:id', authenticateToken, requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN'), async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const studentCheck = await pool.query('SELECT s.id, s.user_id, s.college_id, s.roll_number, u.email FROM students s JOIN users u ON s.user_id = u.id WHERE s.id = $1', [id]);
    if (studentCheck.rows.length === 0) {
      res.status(404).json({ error: 'Student not found.' });
      return;
    }

    const student = studentCheck.rows[0];
    if (req.user!.role === 'COLLEGE_ADMIN' && req.user!.collegeId !== student.college_id) {
      res.status(403).json({ error: 'Forbidden: Cannot delete student from another college.' });
      return;
    }

    // Delete user which cascades to student, behaviour, etc.
    await pool.query('DELETE FROM users WHERE id = $1', [student.user_id]);

    // Real-time Cloud Synchronization (Supabase PostgreSQL)
    try {
      await supabase.from('students').delete().eq('id', id);
      await supabase.from('users').delete().eq('id', student.user_id);
      console.log(`[Supabase Cloud Sync] Student ${student.roll_number} deleted from Supabase Cloud.`);
    } catch (syncErr: any) {
      console.warn('[Supabase Cloud Sync Notice] Handled student deletion notice:', syncErr.message);
    }
    await logAuditEvent(req, 'DELETE_STUDENT', 'STUDENT', id, {
      deletedEmail: student.email,
      rollNumber: student.roll_number,
      collegeId: student.college_id,
    });

    res.json({ message: 'Student removed successfully.' });
  } catch (error) {
    console.error('Delete student error:', error);
    res.status(500).json({ error: 'Failed to delete student.' });
  }
});

// Allocate Student(s) to Trainer (Super Admin, Program Manager, College Admin, TPO)
router.post(
  '/allocate-trainer',
  authenticateToken,
  requireRole('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { studentIds, studentId, trainerId, courseName, courseId } = req.body;
      const ids: string[] = Array.isArray(studentIds) ? studentIds : (studentId ? [studentId] : []);

      if (ids.length === 0 || !trainerId) {
        res.status(400).json({ error: 'studentIds and trainerId are required.' });
        return;
      }

      // Fetch trainer details
      let trainerUser: any = null;
      try {
        const trRes = await pool.query('SELECT * FROM users WHERE id = $1', [trainerId]);
        if (trRes.rows.length > 0) trainerUser = trRes.rows[0];
      } catch (_) {}

      if (!trainerUser) {
        const { data: sbTr } = await supabase.from('users').select('*').eq('id', trainerId).single();
        if (sbTr) trainerUser = sbTr;
      }

      if (!trainerUser) {
        res.status(404).json({ error: 'Selected Trainer not found.' });
        return;
      }

      const effectiveCourseName = courseName || (trainerUser.email?.includes('python') ? 'Python Full Stack & AI' : 'Technical Session & Mentorship');

      for (const sid of ids) {
        const notesObj = {
          assigned_trainer_id: trainerUser.id,
          assigned_trainer_name: trainerUser.full_name,
          assigned_trainer_email: trainerUser.email,
          course_name: effectiveCourseName,
          allocated_at: new Date().toISOString(),
          allocated_by: req.user!.userId,
        };
        const notesStr = JSON.stringify(notesObj);

        // 1. Update in Postgres
        try {
          await pool.query(
            `INSERT INTO student_behaviour (student_id, college_id, trainer_notes, updated_at)
             VALUES ($1, $2, $3, NOW())
             ON CONFLICT (student_id) DO UPDATE SET trainer_notes = $3, updated_at = NOW()`,
            [sid, trainerUser.college_id, notesStr]
          );
        } catch (_) {}

        // 2. Update in Supabase Cloud
        try {
          await supabase.from('student_behaviour').upsert({
            student_id: sid,
            college_id: trainerUser.college_id,
            trainer_notes: notesStr,
            updated_at: new Date().toISOString(),
          }, { onConflict: 'student_id' });
        } catch (sbEx) {
          console.warn('[ALLOCATE-TRAINER] Supabase sync notice:', sbEx);
        }
      }

      try {
        await logAuditEvent(req, 'STUDENTS_ALLOCATED_TO_TRAINER', 'TRAINER', trainerId, {
          allocatedCount: ids.length,
          trainerEmail: trainerUser.email,
          trainerName: trainerUser.full_name,
          studentIds: ids,
        });
      } catch (_) {}

      res.json({
        success: true,
        message: `Successfully allocated ${ids.length} student(s) to ${trainerUser.full_name}.`,
        allocatedCount: ids.length,
        trainer: {
          id: trainerUser.id,
          fullName: trainerUser.full_name,
          email: trainerUser.email,
          courseName: effectiveCourseName,
        },
      });
    } catch (error) {
      console.error('Student allocation error:', error);
      res.status(500).json({ error: 'Failed to allocate students to trainer.' });
    }
  }
);

export default router;
