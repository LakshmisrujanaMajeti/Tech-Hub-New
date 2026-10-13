import { Router, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool } from '../db/pool.js';
import { supabase } from '../db/supabase.js';
import { AuthenticatedRequest } from '../types/index.js';
import { authenticateToken, requireRole } from '../middleware/auth.js';
import { logAuditEvent } from '../middleware/audit.js';

const router = Router();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.join(__dirname, '..', '..', 'data');

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const QUIZZES_FILE = path.join(DATA_DIR, 'quizzes.json');
const SUBMISSIONS_FILE = path.join(DATA_DIR, 'quiz_submissions.json');

export interface QuizQuestion {
  id: string;
  question_text: string;
  options: { id: string; text: string }[];
  correct_option: string; // 'A' | 'B' | 'C' | 'D'
  marks: number;
  explanation?: string;
}

export interface Quiz {
  id: string;
  trainer_id: string;
  trainer_name: string;
  trainer_email?: string;
  college_id?: string;
  college_name?: string;
  title: string;
  description: string;
  course_name: string;
  target_branch: string; // 'ALL', 'CSE', 'AI&DS', etc.
  target_year: string; // 'ALL', '1st Year', '2nd Year', '3rd Year', '4th Year'
  duration_minutes: number;
  total_marks: number;
  passing_percentage: number;
  quiz_type: 'CUSTOM_MCQ' | 'GOOGLE_FORM';
  google_form_url?: string;
  questions: QuizQuestion[];
  is_published: boolean;
  status: 'DRAFT' | 'PUBLISHED' | 'CLOSED';
  published_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface QuizSubmission {
  id: string;
  quiz_id: string;
  student_id: string;
  user_id: string;
  student_name: string;
  roll_number: string;
  college_id?: string;
  college_name?: string;
  branch?: string;
  year?: string;
  answers: Record<string, string>; // { question_id: selected_option_id }
  score: number;
  total_marks: number;
  percentage: number;
  total_questions: number;
  correct_count: number;
  incorrect_count: number;
  unanswered_count: number;
  time_taken_seconds: number;
  is_auto_submitted: boolean;
  tab_switch_count?: number;
  submission_reason?: 'NORMAL' | 'TIMEOUT' | 'TERMINATED_TAB_SWITCH_LIMIT_EXCEEDED' | 'TERMINATED_UNEXPECTED_WINDOW_CLOSE';
  status: 'IN_PROGRESS' | 'SUBMITTED' | 'COMPLETED';
  started_at?: string;
  submitted_at: string;
  review_breakdown?: any[];
}

// Durable Store Management
function loadQuizzes(): Quiz[] {
  try {
    if (fs.existsSync(QUIZZES_FILE)) {
      const raw = fs.readFileSync(QUIZZES_FILE, 'utf-8');
      return JSON.parse(raw);
    }
  } catch (err) {
    console.error('Error loading quizzes file:', err);
  }
  return initialQuizzes;
}

function saveQuizzes(quizzes: Quiz[]) {
  try {
    fs.writeFileSync(QUIZZES_FILE, JSON.stringify(quizzes, null, 2), 'utf-8');
  } catch (err) {
    console.error('Error saving quizzes file:', err);
  }
}

function loadSubmissions(): QuizSubmission[] {
  try {
    if (fs.existsSync(SUBMISSIONS_FILE)) {
      const raw = fs.readFileSync(SUBMISSIONS_FILE, 'utf-8');
      return JSON.parse(raw);
    }
  } catch (err) {
    console.error('Error loading submissions file:', err);
  }
  return [];
}

function saveSubmissions(submissions: QuizSubmission[]) {
  try {
    fs.writeFileSync(SUBMISSIONS_FILE, JSON.stringify(submissions, null, 2), 'utf-8');
  } catch (err) {
    console.error('Error saving submissions file:', err);
  }
}

// Initial seed quizzes
const initialQuizzes: Quiz[] = [
  {
    id: 'quiz-python-daily-01',
    trainer_id: '48632025-1678-4014-925a-86391063614b', // Elisala Sushma
    trainer_name: 'Elisala Sushma',
    trainer_email: 'vsushmaelisala@gmail.com',
    college_id: 'ce3937d8-db9a-4002-8128-bf5a68bec78b', // Adarsh
    college_name: 'Adarsh Engineering College',
    title: 'Python Functions, Lists & Comprehensions - Daily Quiz #14',
    description: 'Post-class 15-minute concept review quiz. Questions are randomized for each student. All submissions automatically close once timer expires.',
    course_name: 'Python Full stack',
    target_branch: 'ALL',
    target_year: '2nd Year',
    duration_minutes: 15,
    total_marks: 10,
    passing_percentage: 60,
    quiz_type: 'CUSTOM_MCQ',
    is_published: true,
    status: 'PUBLISHED',
    published_at: new Date().toISOString(),
    created_at: new Date(Date.now() - 3600 * 1000 * 2).toISOString(),
    updated_at: new Date().toISOString(),
    questions: [
      {
        id: 'q1',
        question_text: 'What will be the output of: print([x**2 for x in range(5) if x % 2 == 0])?',
        options: [
          { id: 'A', text: '[0, 4, 16]' },
          { id: 'B', text: '[1, 9]' },
          { id: 'C', text: '[0, 2, 4]' },
          { id: 'D', text: '[4, 16]' },
        ],
        correct_option: 'A',
        marks: 2,
        explanation: 'range(5) gives 0, 1, 2, 3, 4. Even numbers are 0, 2, 4. Their squares are 0, 4, 16.',
      },
      {
        id: 'q2',
        question_text: 'Which Python keyword is used to create an anonymous function?',
        options: [
          { id: 'A', text: 'def' },
          { id: 'B', text: 'lambda' },
          { id: 'C', text: 'anonymous' },
          { id: 'D', text: 'inline' },
        ],
        correct_option: 'B',
        marks: 2,
        explanation: 'The lambda keyword creates small anonymous functions on the fly.',
      },
      {
        id: 'q3',
        question_text: 'In Python, what is the default return value of a function that does not contain a return statement?',
        options: [
          { id: 'A', text: '0' },
          { id: 'B', text: 'False' },
          { id: 'C', text: 'None' },
          { id: 'D', text: 'Null' },
        ],
        correct_option: 'C',
        marks: 2,
        explanation: 'Functions in Python without an explicit return statement return None by default.',
      },
      {
        id: 'q4',
        question_text: 'What is the time complexity of appending an element to the end of a Python list on average?',
        options: [
          { id: 'A', text: 'O(1)' },
          { id: 'B', text: 'O(n)' },
          { id: 'C', text: 'O(log n)' },
          { id: 'D', text: 'O(n^2)' },
        ],
        correct_option: 'A',
        marks: 2,
        explanation: 'list.append() operates in amortized O(1) constant time.',
      },
      {
        id: 'q5',
        question_text: 'Which built-in function returns both the index and value when iterating over a sequence?',
        options: [
          { id: 'A', text: 'zip()' },
          { id: 'B', text: 'enumerate()' },
          { id: 'C', text: 'map()' },
          { id: 'D', text: 'filter()' },
        ],
        correct_option: 'B',
        marks: 2,
        explanation: 'enumerate(iterable) yields pairs of (index, item) during iteration.',
      },
    ],
  },
  {
    id: 'quiz-tech-googleform-01',
    trainer_id: '0ed2be5c-fce6-4e4f-83eb-96be2b162746', // Pathivada Daiva Rao
    trainer_name: 'Pathivada Daiva Rao',
    trainer_email: 'daivaraopathivada@gmail.com',
    college_id: 'ce3937d8-db9a-4002-8128-bf5a68bec78b', // Adarsh
    college_name: 'Adarsh college of Engineering',
    title: 'Java Full Stack & Aptitude Live Test',
    description: 'Direct Google Form Quiz. Complete the test within 20 minutes.',
    course_name: 'Java full stack',
    target_branch: 'ALL',
    target_year: 'ALL',
    duration_minutes: 20,
    total_marks: 20,
    passing_percentage: 60,
    quiz_type: 'GOOGLE_FORM',
    google_form_url: 'https://docs.google.com/forms/d/e/1FAIpQLSc_Example_TechHub_Aptitude/viewform',
    is_published: true,
    status: 'PUBLISHED',
    published_at: new Date().toISOString(),
    created_at: new Date(Date.now() - 3600 * 1000 * 5).toISOString(),
    updated_at: new Date().toISOString(),
    questions: [],
  },
];

let memoryQuizzes: Quiz[] = loadQuizzes();
let memorySubmissions: QuizSubmission[] = loadSubmissions();

// Helper: Seed pseudo-random shuffle per student ID (determinstic so student gets same randomized order during their attempt)
function seededShuffle<T>(array: T[], seedStr: string): T[] {
  let hash = 0;
  for (let i = 0; i < seedStr.length; i++) {
    hash = (hash << 5) - hash + seedStr.charCodeAt(i);
    hash |= 0;
  }
  const cloned = [...array];
  for (let i = cloned.length - 1; i > 0; i--) {
    hash = Math.imul(hash ^ (hash >>> 16), 2246822507);
    hash = Math.imul(hash ^ (hash >>> 13), 3266489909);
    const j = Math.abs(hash % (i + 1));
    const temp = cloned[i];
    cloned[i] = cloned[j];
    cloned[j] = temp;
  }
  return cloned;
}

function normalizeYear(y?: string): string {
  if (!y) return '';
  const match = y.match(/\d+/);
  return match ? match[0] : y.trim().toLowerCase();
}

function normalizeBranch(b?: string): string {
  if (!b) return '';
  const clean = b.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
  if (clean === 'all' || clean === 'allbranches') return 'all';
  return clean;
}

// Helper: Dynamic trainer-student assignment resolution
async function getStudentAssignedTrainers(userId: string): Promise<{
  student: any | null;
  assignedTrainerIds: Set<string>;
  assignedTrainerEmails: Set<string>;
}> {
  const assignedTrainerIds = new Set<string>();
  const assignedTrainerEmails = new Set<string>();
  let studentRecord: any = null;

  // 1. Fetch student record from PG pool
  try {
    const sRes = await pool.query(
      `SELECT s.*, u.full_name, u.email, u.mobile, sb.trainer_notes
       FROM students s
       JOIN users u ON s.user_id = u.id
       LEFT JOIN student_behaviour sb ON s.id = sb.student_id
       WHERE s.user_id = $1 OR s.id = $1`,
      [userId]
    );
    if (sRes.rows.length > 0) {
      studentRecord = sRes.rows[0];
    }
  } catch (_) {}

  // Fallback to Supabase
  if (!studentRecord) {
    try {
      const { data: sSb } = await supabase
        .from('students')
        .select('*, users!inner(full_name, email, mobile), student_behaviour(trainer_notes)')
        .or(`user_id.eq.${userId},id.eq.${userId}`)
        .limit(1);
      if (sSb && sSb.length > 0) {
        const s = sSb[0];
        const bh = Array.isArray(s.student_behaviour) ? s.student_behaviour[0] : s.student_behaviour;
        studentRecord = {
          id: s.id,
          user_id: s.user_id,
          college_id: s.college_id,
          branch: s.branch,
          year: s.year,
          roll_number: s.roll_number,
          full_name: s.users?.full_name,
          email: s.users?.email,
          trainer_notes: bh?.trainer_notes,
        };
      }
    } catch (_) {}
  }

  if (studentRecord) {
    // A. Explicit trainer allocation in trainer_notes
    if (studentRecord.trainer_notes) {
      try {
        const parsed = typeof studentRecord.trainer_notes === 'string' ? JSON.parse(studentRecord.trainer_notes) : studentRecord.trainer_notes;
        if (parsed?.assigned_trainer_id) assignedTrainerIds.add(parsed.assigned_trainer_id);
        if (parsed?.assigned_trainer_email) assignedTrainerEmails.add(parsed.assigned_trainer_email.toLowerCase());
      } catch (_) {}
    }

    // B. College & Year/Branch assignment lookup (PG Pool)
    try {
      const taRes = await pool.query(
        `SELECT ta.trainer_id, u.email as trainer_email, ta.target_years, ta.target_branches
         FROM trainer_assignments ta
         JOIN users u ON ta.trainer_id = u.id
         WHERE ta.college_id = $1`,
        [studentRecord.college_id]
      );
      for (const row of taRes.rows) {
        const yearMatch = !row.target_years || row.target_years.length === 0 || row.target_years.some((y: string) => normalizeYear(y) === normalizeYear(studentRecord.year));
        const branchMatch = !row.target_branches || row.target_branches.length === 0 || row.target_branches.some((b: string) => normalizeBranch(b) === 'all' || normalizeBranch(b) === normalizeBranch(studentRecord.branch));
        if (yearMatch && branchMatch) {
          if (row.trainer_id) assignedTrainerIds.add(row.trainer_id);
          if (row.trainer_email) assignedTrainerEmails.add(row.trainer_email.toLowerCase());
        }
      }
    } catch (_) {}

    // B2. Supabase trainer_assignments lookup if still empty
    if (assignedTrainerIds.size === 0) {
      try {
        const { data: taSb } = await supabase
          .from('trainer_assignments')
          .select('trainer_id, target_years, target_branches, users:trainer_id(email)')
          .eq('college_id', studentRecord.college_id);
        if (taSb && taSb.length > 0) {
          for (const row of taSb) {
            const yearMatch = !row.target_years || row.target_years.length === 0 || row.target_years.some((y: string) => normalizeYear(y) === normalizeYear(studentRecord.year));
            const branchMatch = !row.target_branches || row.target_branches.length === 0 || row.target_branches.some((b: string) => normalizeBranch(b) === 'all' || normalizeBranch(b) === normalizeBranch(studentRecord.branch));
            if (yearMatch && branchMatch) {
              if (row.trainer_id) assignedTrainerIds.add(row.trainer_id);
              const tEmail = (row.users as any)?.email;
              if (tEmail) assignedTrainerEmails.add(tEmail.toLowerCase());
            }
          }
        }
      } catch (_) {}
    }

    // C. Default year-based assignment fallback
    const sYearNorm = normalizeYear(studentRecord.year);
    const sBranchNorm = normalizeBranch(studentRecord.branch);
    if (sYearNorm === '2') {
      assignedTrainerIds.add('48632025-1678-4014-925a-86391063614b'); // Elisala Sushma
      assignedTrainerEmails.add('vsushmaelisala@gmail.com');
    } else if (sYearNorm === '3') {
      assignedTrainerIds.add('0ed2be5c-fce6-4e4f-83eb-96be2b162746'); // Pathivada Daiva Rao
      assignedTrainerEmails.add('daivaraopathivada@gmail.com');
      assignedTrainerEmails.add('daivarao.techhub@cognitoinsights.ai');
    } else if (sYearNorm === '4') {
      if (sBranchNorm.includes('ai') || sBranchNorm.includes('ds') || sBranchNorm.includes('ml')) {
        assignedTrainerIds.add('48632025-1678-4014-925a-86391063614b'); // Elisala Sushma
        assignedTrainerEmails.add('vsushmaelisala@gmail.com');
      } else {
        // Both trainers handle 4th year for CSE, ECE, EEE, Civil, Mechanical
        assignedTrainerIds.add('48632025-1678-4014-925a-86391063614b');
        assignedTrainerEmails.add('vsushmaelisala@gmail.com');
        assignedTrainerIds.add('0ed2be5c-fce6-4e4f-83eb-96be2b162746');
        assignedTrainerEmails.add('daivaraopathivada@gmail.com');
        assignedTrainerEmails.add('daivarao.techhub@cognitoinsights.ai');
      }
    } else {
      assignedTrainerIds.add('0ed2be5c-fce6-4e4f-83eb-96be2b162746');
      assignedTrainerEmails.add('daivaraopathivada@gmail.com');
    }
  }

  return { student: studentRecord, assignedTrainerIds, assignedTrainerEmails };
}

// Helper: Check if student is authorized to view/attempt this quiz
function isStudentAuthorizedForQuiz(quiz: Quiz, student: any, assignedTrainerIds: Set<string>, assignedTrainerEmails: Set<string>): boolean {
  if (!quiz.is_published || quiz.status !== 'PUBLISHED') {
    return false;
  }

  const tEmail = (quiz.trainer_email || '').toLowerCase();
  const tName = (quiz.trainer_name || '').toLowerCase();
  const cName = (quiz.course_name || '').toLowerCase();
  const isSushmaQuiz = tEmail.includes('sushma') || tName.includes('sushma') || cName.includes('python');
  const isDaivaQuiz = tEmail.includes('daiva') || tEmail.includes('pathivada') || tName.includes('daiva') || tName.includes('pathivada') || cName.includes('java');

  const sYear = student?.year ? normalizeYear(student.year) : '';
  const isSushmaAssigned = Array.from(assignedTrainerEmails).some(e => e.includes('sushma')) || sYear === '2';
  const isDaivaAssigned = Array.from(assignedTrainerEmails).some(e => e.includes('daiva') || e.includes('pathivada')) || sYear === '3';

  if (isSushmaQuiz) {
    if (!isSushmaAssigned && sYear === '3') return false;
  } else if (isDaivaQuiz) {
    if (!isDaivaAssigned && sYear === '2') return false;
  } else {
    const trainerIdMatch = quiz.trainer_id && assignedTrainerIds.has(quiz.trainer_id);
    const trainerEmailMatch = quiz.trainer_email && assignedTrainerEmails.has(quiz.trainer_email.toLowerCase());
    if (!trainerIdMatch && !trainerEmailMatch) {
      return false;
    }
  }

  if (student) {
    // 2. Target Year Check
    if (quiz.target_year && quiz.target_year.trim().toUpperCase() !== 'ALL' && student.year) {
      const qYearNorm = normalizeYear(quiz.target_year);
      const sYearNorm = normalizeYear(student.year);
      if (qYearNorm && sYearNorm && qYearNorm !== sYearNorm) {
        return false;
      }
    }

    // 3. Target Branch Check
    if (quiz.target_branch && quiz.target_branch.trim().toUpperCase() !== 'ALL' && student.branch) {
      const qBranchNorm = normalizeBranch(quiz.target_branch);
      const sBranchNorm = normalizeBranch(student.branch);
      if (qBranchNorm && qBranchNorm !== 'all' && sBranchNorm && qBranchNorm !== sBranchNorm) {
        return false;
      }
    }
  }

  return true;
}

// =========================================================================
// 1. GET /api/quizzes - List Quizzes (Role-Scoped & Trainer Assigned)
// =========================================================================
router.get('/', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const user = req.user!;
    let quizzes = [...memoryQuizzes];

    if (user.role === 'STUDENT') {
      // 1. Resolve student and assigned trainers
      const studentId = user.studentId || user.userId;
      const { student, assignedTrainerIds, assignedTrainerEmails } = await getStudentAssignedTrainers(user.userId);

      // 2. Filter strictly to published tests created by student's assigned trainer(s) matching their year/branch
      const authorizedQuizzes = quizzes.filter(q => isStudentAuthorizedForQuiz(q, student, assignedTrainerIds, assignedTrainerEmails));

      // 3. Attach student's submission status for each quiz
      const enriched = authorizedQuizzes.map(q => {
        const sub = memorySubmissions.find(s => s.quiz_id === q.id && (s.student_id === studentId || s.user_id === user.userId));
        const isResultsPublished = (q as any).is_results_published === true;
        return {
          id: q.id,
          title: q.title,
          description: q.description,
          trainer_name: q.trainer_name,
          course_name: q.course_name,
          target_branch: q.target_branch,
          target_year: q.target_year,
          duration_minutes: q.duration_minutes,
          total_marks: q.total_marks,
          quiz_type: q.quiz_type,
          google_form_url: q.google_form_url,
          question_count: q.questions.length,
          is_published: q.is_published,
          is_results_published: isResultsPublished,
          status: q.status,
          published_at: q.published_at,
          has_submitted: !!sub,
          submission_status: sub ? 'SUBMITTED' : 'NOT_STARTED',
          submitted_at: sub?.submitted_at || null,
          submission: sub ? {
            id: sub.id,
            score: sub.score,
            total_marks: sub.total_marks,
            percentage: sub.percentage,
            correct_count: sub.correct_count,
            incorrect_count: sub.incorrect_count,
            unanswered_count: sub.unanswered_count,
            time_taken_seconds: sub.time_taken_seconds,
            is_auto_submitted: sub.is_auto_submitted,
            submitted_at: sub.submitted_at,
            review_breakdown: isResultsPublished ? (sub.review_breakdown || []) : [],
            quiz_type: q.quiz_type,
          } : null,
        };
      });

      res.json({ success: true, quizzes: enriched });
      return;
    }

    // For TRAINER
    if (user.role === 'TRAINER') {
      const currentTrainerId = user.userId || (user as any).id;
      const currentTrainerEmail = (user.email || '').toLowerCase();

      quizzes = quizzes.filter(q => {
        if (q.trainer_id && currentTrainerId && q.trainer_id === currentTrainerId) return true;
        if (q.trainer_email && currentTrainerEmail && q.trainer_email.toLowerCase() === currentTrainerEmail) return true;
        if (currentTrainerEmail.includes('sushma') && (q.trainer_name?.toLowerCase().includes('sushma') || (q.course_name && q.course_name.toLowerCase().includes('python')))) return true;
        if (!q.trainer_id && !q.trainer_email) return true;
        return false;
      });
    }

    // Attach submission counts & stats for trainers/admins
    const enriched = quizzes.map(q => {
      const subs = memorySubmissions.filter(s => s.quiz_id === q.id);
      const avgScore = subs.length > 0 ? (subs.reduce((acc, cur) => acc + cur.score, 0) / subs.length).toFixed(1) : '0';
      const avgPct = subs.length > 0 ? (subs.reduce((acc, cur) => acc + cur.percentage, 0) / subs.length).toFixed(1) : '0';

      return {
        ...q,
        submission_count: subs.length,
        average_score: Number(avgScore),
        average_percentage: Number(avgPct),
      };
    });

    res.json({
      success: true,
      quizzes: enriched,
      stats: {
        total_quizzes: enriched.length,
        published_quizzes: enriched.filter(q => q.is_published).length,
        draft_quizzes: enriched.filter(q => !q.is_published).length,
        total_submissions: memorySubmissions.filter(s => quizzes.some(q => q.id === s.quiz_id)).length,
      },
    });
  } catch (err: any) {
    console.error('Fetch quizzes error:', err);
    res.status(500).json({ success: false, error: 'Failed to fetch quizzes.' });
  }
});

// =========================================================================
// 2. GET /api/quizzes/:id - Get Quiz Details
// =========================================================================
router.get('/:id', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const user = req.user!;
    const quiz = memoryQuizzes.find(q => q.id === id);

    if (!quiz) {
      res.status(404).json({ success: false, error: 'Quiz not found.' });
      return;
    }

    const studentId = user.studentId || user.userId;
    const existingSub = memorySubmissions.find(s => s.quiz_id === id && (s.student_id === studentId || s.user_id === user.userId));

    if (user.role === 'STUDENT') {
      // 1. Authorization check
      const { student, assignedTrainerIds, assignedTrainerEmails } = await getStudentAssignedTrainers(user.userId);
      if (!isStudentAuthorizedForQuiz(quiz, student, assignedTrainerIds, assignedTrainerEmails)) {
        res.status(403).json({ success: false, error: 'Forbidden: You are not authorized to access this test.' });
        return;
      }

      // 2. STRICT ONE-ATTEMPT-ONLY & UNEXPECTED CLOSURE HANDLING:
      if (existingSub) {
        if (existingSub.status === 'IN_PROGRESS') {
          // Unexpected window/tab closure occurred while test was in progress.
          // Auto-finalize and terminate the attempt immediately per rules!
          let calcScore = 0;
          let totalM = quiz.total_marks || 10;
          let corr = 0;
          let incorr = 0;
          let unans = 0;
          const reviewList: any[] = [];

          if (quiz.quiz_type !== 'GOOGLE_FORM') {
            totalM = quiz.questions.reduce((sum, q) => sum + (q.marks || 1), 0);
            quiz.questions.forEach(q => {
              const studentAns = existingSub.answers ? existingSub.answers[q.id] : undefined;
              if (!studentAns) {
                unans++;
                reviewList.push({
                  question_id: q.id,
                  question_text: q.question_text,
                  student_answer: 'NOT_ATTEMPTED',
                  correct_option: q.correct_option,
                  is_correct: false,
                  marks_earned: 0,
                  total_marks: q.marks || 1,
                  explanation: q.explanation || '',
                });
              } else {
                const isCorrect = studentAns.toUpperCase() === q.correct_option.toUpperCase();
                const earned = isCorrect ? (q.marks || 1) : 0;
                calcScore += earned;
                if (isCorrect) corr++;
                else incorr++;
                reviewList.push({
                  question_id: q.id,
                  question_text: q.question_text,
                  student_answer: studentAns,
                  correct_option: q.correct_option,
                  is_correct: isCorrect,
                  marks_earned: earned,
                  total_marks: q.marks || 1,
                  explanation: q.explanation || '',
                });
              }
            });
          }

          existingSub.status = 'SUBMITTED';
          existingSub.is_auto_submitted = true;
          existingSub.submission_reason = 'TERMINATED_UNEXPECTED_WINDOW_CLOSE';
          existingSub.score = calcScore;
          existingSub.total_marks = totalM;
          existingSub.percentage = totalM > 0 ? Math.round((calcScore / totalM) * 1000) / 10 : 0;
          existingSub.correct_count = corr;
          existingSub.incorrect_count = incorr;
          existingSub.unanswered_count = unans;
          existingSub.submitted_at = new Date().toISOString();
          existingSub.review_breakdown = reviewList;
          saveSubmissions(memorySubmissions);

          res.status(400).json({
            success: false,
            error: 'You have already attempted this test. Unexpected test closure detected. Reattempt is not allowed.',
            is_completed: true,
            has_submitted: true,
            submitted_at: existingSub.submitted_at,
          });
          return;
        }

        // Already submitted
        res.status(400).json({
          success: false,
          error: 'You have already attempted this test. Reattempt is not allowed.',
          is_completed: true,
          has_submitted: true,
          submitted_at: existingSub.submitted_at,
        });
        return;
      }

      // 3. First time entering test: Initialize IN_PROGRESS attempt
      const newAttempt: QuizSubmission = {
        id: `sub-${uuidv4().substring(0, 8)}`,
        quiz_id: quiz.id,
        student_id: studentId,
        user_id: user.userId,
        student_name: user.fullName || student?.full_name || user.email?.split('@')[0] || 'Student',
        roll_number: (user as any).rollNumber || student?.roll_number || user.email?.split('@')[0].toUpperCase() || 'STUDENT',
        college_id: user.collegeId || student?.college_id || quiz.college_id,
        college_name: quiz.college_name || 'Adarsh Engineering College',
        branch: (user as any).branch || student?.branch || 'CSE',
        year: (user as any).year || student?.year || '3rd Year',
        answers: {},
        score: 0,
        total_marks: quiz.total_marks || 10,
        percentage: 0,
        total_questions: quiz.questions.length,
        correct_count: 0,
        incorrect_count: 0,
        unanswered_count: quiz.questions.length,
        time_taken_seconds: 0,
        is_auto_submitted: false,
        tab_switch_count: 0,
        status: 'IN_PROGRESS',
        started_at: new Date().toISOString(),
        submitted_at: '',
      };
      memorySubmissions.push(newAttempt);
      saveSubmissions(memorySubmissions);

      // 4. Jumble questions and options uniquely per student to prevent cheating and plagiarism
      const seed = `${studentId}_${quiz.id}`;
      const shuffledQuestions = seededShuffle(quiz.questions, `${seed}_questions`);
      const jumbledQuestions = shuffledQuestions.map((q, idx) => {
        // Strip correct_option and explanation to completely protect answers!
        const jumbledOptions = seededShuffle(q.options, `${seed}_q_${q.id}`).map(opt => ({
          id: opt.id,
          text: opt.text,
        }));

        return {
          id: q.id,
          question_number: idx + 1,
          question_text: q.question_text,
          options: jumbledOptions,
          marks: q.marks || 1,
        };
      });

      res.json({
        success: true,
        quiz: {
          id: quiz.id,
          title: quiz.title,
          description: quiz.description,
          trainer_name: quiz.trainer_name,
          course_name: quiz.course_name,
          duration_minutes: quiz.duration_minutes,
          duration_seconds: quiz.duration_minutes * 60,
          total_marks: quiz.total_marks,
          quiz_type: quiz.quiz_type,
          google_form_url: quiz.google_form_url,
          questions: jumbledQuestions,
        },
        has_submitted: false,
        server_time: new Date().toISOString(),
      });
      return;
    }

    // For Trainer: Verify ownership
    if (user.role === 'TRAINER') {
      const currentTrainerId = user.userId;
      const currentTrainerEmail = (user.email || '').toLowerCase();
      const isOwner = quiz.trainer_id === currentTrainerId || (quiz.trainer_email && quiz.trainer_email.toLowerCase() === currentTrainerEmail);

      if (!isOwner) {
        res.status(403).json({ success: false, error: 'Forbidden: You do not have permission to view tests created by another trainer.' });
        return;
      }
    }

    // Return full quiz with submissions list for Trainer / Admin
    const subs = memorySubmissions.filter(s => s.quiz_id === id);
    res.json({
      success: true,
      quiz,
      submissions: subs,
      stats: {
        total_submissions: subs.length,
        avg_score: subs.length > 0 ? (subs.reduce((a, b) => a + b.score, 0) / subs.length).toFixed(1) : 0,
        avg_percentage: subs.length > 0 ? (subs.reduce((a, b) => a + b.percentage, 0) / subs.length).toFixed(1) : 0,
      },
    });
  } catch (err: any) {
    console.error('Get quiz error:', err);
    res.status(500).json({ success: false, error: 'Failed to fetch quiz details.' });
  }
});

// =========================================================================
// 3. POST /api/quizzes - Create New Quiz (Trainer / Super Admin)
// =========================================================================
router.post(
  '/',
  authenticateToken,
  requireRole('TRAINER', 'SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const user = req.user!;
      const {
        title,
        description,
        courseName,
        course_name,
        targetBranch,
        target_branch,
        targetYear,
        target_year,
        durationMinutes,
        duration_minutes,
        totalMarks,
        total_marks,
        quizType,
        quiz_type,
        googleFormUrl,
        google_form_url,
        questions,
        isPublished,
        is_published,
      } = req.body;

      if (!title || !title.trim()) {
        res.status(400).json({ success: false, error: 'Quiz title is required.' });
        return;
      }

      const qType = quiz_type || quizType || 'CUSTOM_MCQ';
      const rawQuestions: any[] = Array.isArray(questions) ? questions : [];
      const published = is_published === true || isPublished === true;

      if (qType === 'CUSTOM_MCQ') {
        if (rawQuestions.length === 0) {
          if (published) {
            res.status(400).json({ success: false, error: 'Please add at least one question to the question paper.' });
            return;
          } else {
            rawQuestions.push({
              question_text: 'Question 1',
              options: [
                { id: 'A', text: 'Option A' },
                { id: 'B', text: 'Option B' },
                { id: 'C', text: 'Option C' },
                { id: 'D', text: 'Option D' },
              ],
              correct_option: 'A',
              marks: 2,
            });
          }
        }

        // Validate each question in publish mode; auto-fill defaults in draft mode
        for (let i = 0; i < rawQuestions.length; i++) {
          const q = rawQuestions[i];
          const qNum = i + 1;

          if (!q.question_text || !q.question_text.trim()) {
            if (published) {
              res.status(400).json({ success: false, error: `Question ${qNum}: Question text is required.` });
              return;
            } else {
              q.question_text = `Question ${qNum}`;
            }
          }

          if (!Array.isArray(q.options) || q.options.length === 0) {
            q.options = [
              { id: 'A', text: 'Option A' },
              { id: 'B', text: 'Option B' },
              { id: 'C', text: 'Option C' },
              { id: 'D', text: 'Option D' },
            ];
          }

          for (const opt of q.options) {
            if (!opt.text || !opt.text.trim()) {
              if (published) {
                res.status(400).json({ success: false, error: `Question ${qNum}: Option ${opt.id} text cannot be empty.` });
                return;
              } else {
                opt.text = `Option ${opt.id}`;
              }
            }
          }

          if (!q.correct_option || !q.correct_option.toString().trim()) {
            if (published) {
              res.status(400).json({ success: false, error: `Question ${qNum}: Please select the correct answer key.` });
              return;
            } else {
              q.correct_option = 'A';
            }
          }

          const validOptionIds = q.options.map((o: any) => o.id.toString().toUpperCase());
          if (!validOptionIds.includes(q.correct_option.toString().toUpperCase())) {
            if (published) {
              res.status(400).json({ success: false, error: `Question ${qNum}: Selected correct answer is invalid.` });
              return;
            } else {
              q.correct_option = validOptionIds[0] || 'A';
            }
          }
        }
      }

      if (qType === 'GOOGLE_FORM' && (!googleFormUrl && !google_form_url)) {
        res.status(400).json({ success: false, error: 'Please provide the Google Form link.' });
        return;
      }

      const parsedDuration = parseInt(duration_minutes || durationMinutes || '15', 10);
      const parsedTotalMarks = parseInt(
        total_marks || totalMarks || (rawQuestions.length > 0 ? rawQuestions.reduce((acc, q) => acc + (q.marks || 1), 0).toString() : '10'),
        10
      );

      const formattedQuestions: QuizQuestion[] = rawQuestions.map((q, idx) => ({
        id: q.id || `q_${idx + 1}_${Date.now()}`,
        question_text: (q.question_text || `Question ${idx + 1}`).trim(),
        options: (q.options || []).map((opt: any) => ({
          id: opt.id.toString().toUpperCase(),
          text: (opt.text || `Option ${opt.id}`).trim(),
        })),
        correct_option: (q.correct_option || 'A').toString().toUpperCase(),
        marks: parseInt(q.marks || '2', 10) || 2,
        explanation: q.explanation?.trim() || '',
      }));

      const newQuiz: Quiz = {
        id: `quiz-${uuidv4().substring(0, 8)}`,
        trainer_id: user.userId || (user as any).id,
        trainer_name: user.fullName || user.email?.split('@')[0] || 'Faculty Trainer',
        trainer_email: user.email,
        college_id: user.collegeId || 'ce3937d8-db9a-4002-8128-bf5a68bec78b',
        college_name: 'Adarsh Engineering College',
        title: title.trim(),
        description: (description || 'Class assessment quiz. Complete within the time limit.').trim(),
        course_name: (course_name || courseName || 'Technical Session').trim(),
        target_branch: (target_branch || targetBranch || 'ALL').trim(),
        target_year: (target_year || targetYear || 'ALL').trim(),
        duration_minutes: Math.max(5, parsedDuration),
        total_marks: Math.max(1, parsedTotalMarks),
        passing_percentage: 60,
        quiz_type: qType,
        google_form_url: (google_form_url || googleFormUrl || '').trim() || undefined,
        questions: formattedQuestions,
        is_published: published,
        status: published ? 'PUBLISHED' : 'DRAFT',
        published_at: published ? new Date().toISOString() : null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      memoryQuizzes.unshift(newQuiz);
      saveQuizzes(memoryQuizzes);

      await logAuditEvent(req, 'CREATE_QUIZ', 'QUIZ', newQuiz.id, {
        title: newQuiz.title,
        quizType: newQuiz.quiz_type,
        isPublished: newQuiz.is_published,
        questionCount: newQuiz.questions.length,
      });

      res.status(201).json({
        success: true,
        message: published ? 'Question paper published live to student portal!' : 'Question paper saved as draft.',
        quiz: newQuiz,
      });
    } catch (err: any) {
      console.error('Create quiz error:', err);
      res.status(500).json({ success: false, error: 'Failed to create quiz.' });
    }
  }
);

// =========================================================================
// 3.5. PUT /api/quizzes/:id - Update Existing Quiz (Trainer / Super Admin)
// =========================================================================
router.put(
  '/:id',
  authenticateToken,
  requireRole('TRAINER', 'SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const user = req.user!;
      const quiz = memoryQuizzes.find(q => q.id === id);

      if (!quiz) {
        res.status(404).json({ success: false, error: 'Quiz not found.' });
        return;
      }

      // Check trainer ownership
      if (user.role === 'TRAINER') {
        const isOwner = quiz.trainer_id === user.userId || (quiz.trainer_email && quiz.trainer_email.toLowerCase() === (user.email || '').toLowerCase());
        if (!isOwner) {
          res.status(403).json({ success: false, error: 'Forbidden: You cannot modify tests belonging to another trainer.' });
          return;
        }
      }

      const {
        title,
        description,
        courseName,
        course_name,
        targetBranch,
        target_branch,
        targetYear,
        target_year,
        durationMinutes,
        duration_minutes,
        totalMarks,
        total_marks,
        quizType,
        quiz_type,
        googleFormUrl,
        google_form_url,
        questions,
        isPublished,
        is_published,
      } = req.body;

      if (title !== undefined) quiz.title = title.trim();
      if (description !== undefined) quiz.description = description.trim();
      if (course_name !== undefined || courseName !== undefined) quiz.course_name = (course_name || courseName || quiz.course_name).trim();
      if (target_branch !== undefined || targetBranch !== undefined) quiz.target_branch = (target_branch || targetBranch || quiz.target_branch).trim();
      if (target_year !== undefined || targetYear !== undefined) quiz.target_year = (target_year || targetYear || quiz.target_year).trim();
      if (duration_minutes !== undefined || durationMinutes !== undefined) {
        quiz.duration_minutes = Math.max(5, parseInt(duration_minutes || durationMinutes || '15', 10));
      }
      if (quiz_type !== undefined || quizType !== undefined) {
        quiz.quiz_type = quiz_type || quizType || quiz.quiz_type;
      }
      if (google_form_url !== undefined || googleFormUrl !== undefined) {
        quiz.google_form_url = (google_form_url || googleFormUrl || '').trim() || undefined;
      }

      if (Array.isArray(questions)) {
        quiz.questions = questions.map((q: any, idx: number) => ({
          id: q.id || `q_${idx + 1}_${Date.now()}`,
          question_text: (q.question_text || `Question ${idx + 1}`).trim(),
          options: (q.options || []).map((opt: any) => ({
            id: opt.id.toString().toUpperCase(),
            text: (opt.text || `Option ${opt.id}`).trim(),
          })),
          correct_option: (q.correct_option || 'A').toString().toUpperCase(),
          marks: parseInt(q.marks || '2', 10) || 2,
          explanation: q.explanation?.trim() || '',
        }));
        quiz.total_marks = quiz.questions.reduce((sum, q) => sum + (q.marks || 1), 0);
      } else if (total_marks !== undefined || totalMarks !== undefined) {
        quiz.total_marks = Math.max(1, parseInt(total_marks || totalMarks || '10', 10));
      }

      if (is_published !== undefined || isPublished !== undefined) {
        const pub = is_published === true || isPublished === true;
        quiz.is_published = pub;
        quiz.status = pub ? 'PUBLISHED' : 'DRAFT';
        if (pub && !quiz.published_at) {
          quiz.published_at = new Date().toISOString();
        }
      }

      quiz.updated_at = new Date().toISOString();
      saveQuizzes(memoryQuizzes);

      await logAuditEvent(req, 'UPDATE_QUIZ', 'QUIZ', quiz.id, {
        title: quiz.title,
        quizType: quiz.quiz_type,
        isPublished: quiz.is_published,
        questionCount: quiz.questions.length,
      });

      res.json({
        success: true,
        message: quiz.is_published ? 'Question paper updated and published live!' : 'Question paper draft saved successfully!',
        quiz,
      });
    } catch (err: any) {
      console.error('Update quiz error:', err);
      res.status(500).json({ success: false, error: 'Failed to update quiz.' });
    }
  }
);

// =========================================================================
// 4. PATCH /api/quizzes/:id/publish - Toggle Publish Status
// =========================================================================
router.patch(
  '/:id/publish',
  authenticateToken,
  requireRole('TRAINER', 'SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const { is_published, isPublished } = req.body;
      const user = req.user!;
      const quiz = memoryQuizzes.find(q => q.id === id);

      if (!quiz) {
        res.status(404).json({ success: false, error: 'Quiz not found.' });
        return;
      }

      // Check trainer ownership
      if (user.role === 'TRAINER') {
        const isOwner = quiz.trainer_id === user.userId || (quiz.trainer_email && quiz.trainer_email.toLowerCase() === (user.email || '').toLowerCase());
        if (!isOwner) {
          res.status(403).json({ success: false, error: 'Forbidden: You cannot modify tests belonging to another trainer.' });
          return;
        }
      }

      // If publishing, ensure every question has a valid correct answer
      const targetStatus = (is_published !== undefined ? is_published : isPublished) !== undefined
        ? (is_published ?? isPublished)
        : !quiz.is_published;

      if (targetStatus && quiz.quiz_type === 'CUSTOM_MCQ') {
        for (let i = 0; i < quiz.questions.length; i++) {
          const q = quiz.questions[i];
          if (!q.correct_option) {
            res.status(400).json({ success: false, error: `Question ${i + 1}: Please select the correct answer before publishing.` });
            return;
          }
        }
      }

      quiz.is_published = !!targetStatus;
      quiz.status = quiz.is_published ? 'PUBLISHED' : 'DRAFT';
      if (quiz.is_published && !quiz.published_at) {
        quiz.published_at = new Date().toISOString();
      }
      quiz.updated_at = new Date().toISOString();

      saveQuizzes(memoryQuizzes);

      res.json({
        success: true,
        message: quiz.is_published
          ? 'Question paper published live to students!'
          : 'Question paper unpublished and moved to draft.',
        quiz,
      });
    } catch (err: any) {
      console.error('Publish quiz error:', err);
      res.status(500).json({ success: false, error: 'Failed to update publish status.' });
    }
  }
);

// =========================================================================
// 4.5. PATCH /api/quizzes/:id/publish-results - Toggle Result Publishing Status
// =========================================================================
router.patch(
  '/:id/publish-results',
  authenticateToken,
  requireRole('TRAINER', 'SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const { is_results_published, isPublished } = req.body;
      const user = req.user!;
      const quiz = memoryQuizzes.find(q => q.id === id);

      if (!quiz) {
        res.status(404).json({ success: false, error: 'Quiz not found.' });
        return;
      }

      if (user.role === 'TRAINER') {
        const isOwner = quiz.trainer_id === user.userId || (quiz.trainer_email && quiz.trainer_email.toLowerCase() === (user.email || '').toLowerCase());
        if (!isOwner) {
          res.status(403).json({ success: false, error: 'Forbidden: You cannot modify tests belonging to another trainer.' });
          return;
        }
      }

      const targetStatus = (is_results_published !== undefined ? is_results_published : isPublished) !== undefined
        ? (is_results_published ?? isPublished)
        : !(quiz as any).is_results_published;

      (quiz as any).is_results_published = !!targetStatus;
      (quiz as any).results_published_at = targetStatus ? new Date().toISOString() : null;
      quiz.updated_at = new Date().toISOString();

      saveQuizzes(memoryQuizzes);

      res.json({
        success: true,
        message: targetStatus ? 'Quiz results published live to students!' : 'Quiz results hidden from students.',
        is_results_published: targetStatus,
        quiz,
      });
    } catch (err: any) {
      console.error('Publish results error:', err);
      res.status(500).json({ success: false, error: 'Failed to update result publishing status.' });
    }
  }
);

// =========================================================================
// 5. POST /api/quizzes/:id/save-progress - Save in-progress answers and tab switch counter
// =========================================================================
router.post('/:id/save-progress', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const user = req.user!;
    const studentId = user.studentId || user.userId;
    const { answers, tab_switch_count } = req.body;

    const existing = memorySubmissions.find(s => s.quiz_id === id && (s.student_id === studentId || s.user_id === user.userId));
    if (existing && existing.status === 'IN_PROGRESS') {
      if (answers && typeof answers === 'object') {
        existing.answers = { ...existing.answers, ...answers };
      }
      if (typeof tab_switch_count === 'number') {
        existing.tab_switch_count = tab_switch_count;
      }
      saveSubmissions(memorySubmissions);
    }
    res.json({ success: true });
  } catch (err: any) {
    console.error('Save progress error:', err);
    res.status(500).json({ success: false, error: 'Failed to save progress.' });
  }
});

// =========================================================================
// 6. POST /api/quizzes/:id/submit - Submit Student Quiz Attempt
// =========================================================================
router.post('/:id/submit', authenticateToken, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const user = req.user!;
    const quiz = memoryQuizzes.find(q => q.id === id);

    if (!quiz) {
      res.status(404).json({ success: false, error: 'Quiz not found.' });
      return;
    }

    const studentId = user.studentId || user.userId;

    // 1. Authorization Check: Verify student is assigned to this test's trainer
    const { student, assignedTrainerIds, assignedTrainerEmails } = await getStudentAssignedTrainers(user.userId);
    if (!isStudentAuthorizedForQuiz(quiz, student, assignedTrainerIds, assignedTrainerEmails)) {
      res.status(403).json({ success: false, error: 'Forbidden: You are not authorized to submit this test.' });
      return;
    }

    // 2. STRICT ONE-ATTEMPT-ONLY CHECK
    const existing = memorySubmissions.find(s => s.quiz_id === id && (s.student_id === studentId || s.user_id === user.userId));
    if (existing && (existing.status === 'SUBMITTED' || existing.status === 'COMPLETED')) {
      res.status(400).json({
        success: false,
        error: 'You have already attempted this test. Reattempt is not allowed.',
        is_completed: true,
        has_submitted: true,
      });
      return;
    }

    const { answers, time_taken_seconds, timeTakenSeconds, is_auto_submitted, isAutoSubmitted, submission_reason, tab_switch_count } = req.body;
    const studentAnswers: Record<string, string> = answers || (existing ? existing.answers : {});
    const timeSpent = parseInt(time_taken_seconds || timeTakenSeconds || '0', 10);
    const autoSubmitted = is_auto_submitted === true || isAutoSubmitted === true;
    const subReason = submission_reason || (autoSubmitted ? 'TIMEOUT' : 'NORMAL');
    const tabCount = typeof tab_switch_count === 'number' ? tab_switch_count : (existing?.tab_switch_count || 0);

    // 3. Evaluate score securely on backend
    let calculatedScore = 0;
    let totalMarks = quiz.total_marks || 10;
    let correctCount = 0;
    let incorrectCount = 0;
    let unansweredCount = 0;
    const reviewBreakdown: any[] = [];

    if (quiz.quiz_type === 'GOOGLE_FORM') {
      calculatedScore = quiz.total_marks;
      correctCount = 1;
    } else {
      totalMarks = quiz.questions.reduce((sum, q) => sum + (q.marks || 1), 0);
      quiz.questions.forEach(q => {
        const studentAns = studentAnswers[q.id];
        if (!studentAns) {
          unansweredCount++;
          reviewBreakdown.push({
            question_id: q.id,
            question_text: q.question_text,
            student_answer: 'NOT_ATTEMPTED',
            correct_option: q.correct_option,
            is_correct: false,
            marks_earned: 0,
            total_marks: q.marks || 1,
            explanation: q.explanation || '',
          });
        } else {
          const isCorrect = studentAns.toUpperCase() === q.correct_option.toUpperCase();
          const earned = isCorrect ? (q.marks || 1) : 0;
          calculatedScore += earned;

          if (isCorrect) correctCount++;
          else incorrectCount++;

          reviewBreakdown.push({
            question_id: q.id,
            question_text: q.question_text,
            student_answer: studentAns,
            correct_option: q.correct_option,
            is_correct: isCorrect,
            marks_earned: earned,
            total_marks: q.marks || 1,
            explanation: q.explanation || '',
          });
        }
      });
    }

    const percentage = totalMarks > 0 ? Math.round((calculatedScore / totalMarks) * 1000) / 10 : 0;

    if (existing) {
      existing.answers = studentAnswers;
      existing.score = calculatedScore;
      existing.total_marks = totalMarks;
      existing.percentage = percentage;
      existing.total_questions = quiz.questions.length;
      existing.correct_count = correctCount;
      existing.incorrect_count = incorrectCount;
      existing.unanswered_count = unansweredCount;
      existing.time_taken_seconds = timeSpent;
      existing.is_auto_submitted = autoSubmitted;
      existing.tab_switch_count = tabCount;
      existing.submission_reason = subReason;
      existing.status = 'SUBMITTED';
      existing.submitted_at = new Date().toISOString();
      existing.review_breakdown = reviewBreakdown;
    } else {
      const submission: QuizSubmission = {
        id: `sub-${uuidv4().substring(0, 8)}`,
        quiz_id: quiz.id,
        student_id: studentId,
        user_id: user.userId,
        student_name: user.fullName || student?.full_name || user.email?.split('@')[0] || 'Student',
        roll_number: (user as any).rollNumber || student?.roll_number || user.email?.split('@')[0].toUpperCase() || 'STUDENT',
        college_id: user.collegeId || student?.college_id || quiz.college_id,
        college_name: quiz.college_name || 'Adarsh Engineering College',
        branch: (user as any).branch || student?.branch || 'CSE',
        year: (user as any).year || student?.year || '3rd Year',
        answers: studentAnswers,
        score: calculatedScore,
        total_marks: totalMarks,
        percentage: percentage,
        total_questions: quiz.questions.length,
        correct_count: correctCount,
        incorrect_count: incorrectCount,
        unanswered_count: unansweredCount,
        time_taken_seconds: timeSpent,
        is_auto_submitted: autoSubmitted,
        tab_switch_count: tabCount,
        submission_reason: subReason,
        status: 'SUBMITTED',
        started_at: new Date().toISOString(),
        submitted_at: new Date().toISOString(),
        review_breakdown: reviewBreakdown,
      };
      memorySubmissions.push(submission);
    }

    saveSubmissions(memorySubmissions);

    // Sync student behaviour assessment score in DB
    try {
      await pool.query(
        `UPDATE student_behaviour
         SET assessment_performance = $1, updated_at = NOW()
         WHERE student_id = $2`,
        [percentage, studentId]
      );
    } catch (_) {}

    try {
      await supabase
        .from('student_behaviour')
        .update({ assessment_performance: percentage, updated_at: new Date().toISOString() })
        .eq('student_id', studentId);
    } catch (_) {}

    // 4. REQUIREMENT 5: Student MUST NOT see result / score / answers immediately.
    // Return clean confirmation response without exposing score or breakdown.
    let responseMsg = 'Test Submitted Successfully. You have successfully submitted your test. Your result will be available through your trainer/portal.';
    if (subReason === 'TERMINATED_TAB_SWITCH_LIMIT_EXCEEDED') {
      responseMsg = 'Exam Terminated: You exceeded the allowed tab switch limit. Your test was automatically submitted.';
    } else if (autoSubmitted) {
      responseMsg = 'Time expired! Your test was automatically submitted.';
    }

    res.status(201).json({
      success: true,
      message: responseMsg,
      is_submitted: true,
    });
  } catch (err: any) {
    console.error('Submit quiz error:', err);
    res.status(500).json({ success: false, error: 'Failed to submit quiz attempt.' });
  }
});

// =========================================================================
// 6. GET /api/quizzes/:id/submissions - Trainer Submissions Roster & Leaderboard
// =========================================================================
router.get(
  '/:id/submissions',
  authenticateToken,
  requireRole('TRAINER', 'SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const user = req.user!;
      const quiz = memoryQuizzes.find(q => q.id === id);

      if (!quiz) {
        res.status(404).json({ success: false, error: 'Quiz not found.' });
        return;
      }

      // Check trainer ownership
      if (user.role === 'TRAINER') {
        const isOwner = quiz.trainer_id === user.userId || (quiz.trainer_email && quiz.trainer_email.toLowerCase() === (user.email || '').toLowerCase());
        if (!isOwner) {
          res.status(403).json({ success: false, error: 'Forbidden: You cannot access results of tests belonging to another trainer.' });
          return;
        }
      }

      const subs = memorySubmissions.filter(s => s.quiz_id === id);

      // Sort by score descending (leaderboard)
      subs.sort((a, b) => b.score - a.score || a.time_taken_seconds - b.time_taken_seconds);

      const avgScore = subs.length > 0 ? parseFloat((subs.reduce((a, b) => a + (b.score || 0), 0) / subs.length).toFixed(1)) : 0;
      const avgPct = subs.length > 0 ? parseFloat((subs.reduce((a, b) => a + (b.percentage || 0), 0) / subs.length).toFixed(1)) : 0;

      res.json({
        success: true,
        quiz_id: quiz.id,
        quiz_title: quiz.title,
        course_name: quiz.course_name,
        total_marks: quiz.total_marks,
        quiz_type: quiz.quiz_type,
        google_form_url: quiz.google_form_url,
        is_results_published: (quiz as any).is_results_published || false,
        submissions_count: subs.length,
        submissions: subs,
        stats: {
          total_submissions: subs.length,
          avg_score: avgScore,
          avg_percentage: avgPct,
        },
      });
    } catch (err: any) {
      console.error('Fetch submissions error:', err);
      res.status(500).json({ success: false, error: 'Failed to fetch submissions.' });
    }
  }
);

// =========================================================================
// 7. GET /api/quizzes/trainer/all-results - All Results for Authenticated Trainer
// =========================================================================
router.get(
  '/trainer/all-results',
  authenticateToken,
  requireRole('TRAINER', 'SUPER_ADMIN', 'PROGRAM_MANAGER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const user = req.user!;
      let trainerQuizzes = [...memoryQuizzes];

      if (user.role === 'TRAINER') {
        const currentTrainerId = user.userId;
        const currentTrainerEmail = (user.email || '').toLowerCase();
        trainerQuizzes = trainerQuizzes.filter(q => q.trainer_id === currentTrainerId || (q.trainer_email && q.trainer_email.toLowerCase() === currentTrainerEmail));
      }

      const quizIds = new Set(trainerQuizzes.map(q => q.id));
      const subs = memorySubmissions.filter(s => quizIds.has(s.quiz_id));

      res.json({
        success: true,
        total_submissions: subs.length,
        submissions: subs,
      });
    } catch (err: any) {
      console.error('Fetch all trainer results error:', err);
      res.status(500).json({ success: false, error: 'Failed to fetch trainer results.' });
    }
  }
);

// =========================================================================
// 8. DELETE /api/quizzes/:id - Delete Quiz
// =========================================================================
router.delete(
  '/:id',
  authenticateToken,
  requireRole('TRAINER', 'SUPER_ADMIN', 'PROGRAM_MANAGER'),
  async (req: AuthenticatedRequest, res: Response): Promise<void> => {
    try {
      const { id } = req.params;
      const user = req.user!;
      const idx = memoryQuizzes.findIndex(q => q.id === id);

      if (idx === -1) {
        res.status(404).json({ success: false, error: 'Quiz not found.' });
        return;
      }

      const quiz = memoryQuizzes[idx];
      if (user.role === 'TRAINER') {
        const isOwner = quiz.trainer_id === user.userId || (quiz.trainer_email && quiz.trainer_email.toLowerCase() === (user.email || '').toLowerCase());
        if (!isOwner) {
          res.status(403).json({ success: false, error: 'Forbidden: You cannot delete tests belonging to another trainer.' });
          return;
        }
      }

      memoryQuizzes.splice(idx, 1);
      memorySubmissions = memorySubmissions.filter(s => s.quiz_id !== id);

      saveQuizzes(memoryQuizzes);
      saveSubmissions(memorySubmissions);

      res.json({ success: true, message: 'Quiz deleted successfully.' });
    } catch (err: any) {
      console.error('Delete quiz error:', err);
      res.status(500).json({ success: false, error: 'Failed to delete quiz.' });
    }
  }
);

export default router;
