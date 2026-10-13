import bcrypt from 'bcryptjs';
import { supabase } from './supabase.js';
import { pool } from './pool.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const TRAINER_ID = '48632025-1678-4014-925a-86391063614b';
const TRAINER_EMAIL = 'vsushmaelisala@gmail.com';
const TRAINER_NAME = 'Elisala Sushma';
const TRAINER_COURSE = 'Python Full stack';
const TRAINER_PASSWORD = 'Trainer@123';
const ADARSH_COLLEGE_ID_SB = 'ce3937d8-db9a-4002-8128-bf5a68bec78b';
const ADARSH_COLLEGE_ID_PG = '7b830e12-d85c-4d39-9524-2c63efcf4174';
const TARGET_YEARS = ['2nd Year', '2nd year', '2nd'];
const TARGET_BRANCHES = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AIDS', 'AIML', 'ALL'];

async function syncElisalaSushma() {
  console.log('=== SYNCING ELISALA SUSHMA TRAINER DATA ===');
  const passwordHash = await bcrypt.hash(TRAINER_PASSWORD, 10);

  // 1. SUPABASE SYNC
  try {
    // Delete any old sushma email if under different id
    await supabase.from('users').delete().eq('email', 'sushma.python@cognitoinsights.ai');

    // Upsert Elisala Sushma
    const { data: userSb, error: userSbErr } = await supabase.from('users').upsert({
      id: TRAINER_ID,
      email: TRAINER_EMAIL,
      password_hash: passwordHash,
      role: 'TRAINER',
      full_name: TRAINER_NAME,
      mobile: '+91 98888 33333',
      college_id: ADARSH_COLLEGE_ID_SB,
      status: 'ACTIVE',
      updated_at: new Date().toISOString(),
    }).select().single();

    if (userSbErr) {
      console.warn('Supabase trainer upsert warning:', userSbErr.message);
    } else {
      console.log('Supabase Trainer Upserted:', userSb.email, userSb.full_name);
    }

    // Upsert Trainer Assignment
    const { error: taSbErr } = await supabase.from('trainer_assignments').upsert({
      id: '3b02d5ac-11b9-43ac-84c4-13601a00628b',
      trainer_id: TRAINER_ID,
      college_id: ADARSH_COLLEGE_ID_SB,
      course_name: TRAINER_COURSE,
      target_years: ['2nd Year'],
      target_branches: TARGET_BRANCHES,
    });
    if (taSbErr) console.warn('Supabase trainer_assignment error:', taSbErr.message);
    else console.log('Supabase Trainer Assignment updated for Python Full stack (2nd Year).');

    // 2. Ensure representative 2nd Year Students across all branches (CSE, ECE, EEE, MECH, CIVIL, AIDS, AIML)
    const secondYearStudents = [
      { roll: '26HN5A0503', name: 'Devagupthapu Vijaya Kumari', branch: 'CSE', email: 'vijayadevagupthapu703@gmail.com', sec: 'A', gender: 'FEMALE' },
      { roll: '24HN1A0501', name: 'K. Sai Varun', branch: 'CSE', email: 'saivarun.cse@adarsh.ac.in', sec: 'A', gender: 'MALE' },
      { roll: '24HN1A0502', name: 'B. Tejaswini', branch: 'CSE', email: 'tejaswini.cse@adarsh.ac.in', sec: 'B', gender: 'FEMALE' },
      { roll: '24HN1A0401', name: 'M. Harish Reddy', branch: 'ECE', email: 'harish.ece@adarsh.ac.in', sec: 'A', gender: 'MALE' },
      { roll: '24HN1A0402', name: 'P. Bhavya Sri', branch: 'ECE', email: 'bhavya.ece@adarsh.ac.in', sec: 'A', gender: 'FEMALE' },
      { roll: '24HN1A0201', name: 'Ch. Venkat Raman', branch: 'EEE', email: 'venkat.eee@adarsh.ac.in', sec: 'A', gender: 'MALE' },
      { roll: '24HN1A0202', name: 'G. Lakshmi Prasanna', branch: 'EEE', email: 'lakshmi.eee@adarsh.ac.in', sec: 'A', gender: 'FEMALE' },
      { roll: '24HN1A0301', name: 'T. Suresh Kumar', branch: 'MECH', email: 'suresh.mech@adarsh.ac.in', sec: 'A', gender: 'MALE' },
      { roll: '24HN1A0302', name: 'K. Rajesh', branch: 'MECH', email: 'rajesh.mech@adarsh.ac.in', sec: 'A', gender: 'MALE' },
      { roll: '24HN1A0101', name: 'N. Sandhya Rani', branch: 'CIVIL', email: 'sandhya.civil@adarsh.ac.in', sec: 'A', gender: 'FEMALE' },
      { roll: '24HN1A0102', name: 'D. Karthik', branch: 'CIVIL', email: 'karthik.civil@adarsh.ac.in', sec: 'A', gender: 'MALE' },
      { roll: '24HN1A5401', name: 'A. Divya Sri', branch: 'AIDS', email: 'divya.aids@adarsh.ac.in', sec: 'A', gender: 'FEMALE' },
      { roll: '24HN1A5402', name: 'R. Akhil Kumar', branch: 'AIDS', email: 'akhil.aids@adarsh.ac.in', sec: 'A', gender: 'MALE' },
      { roll: '24HN1A4201', name: 'V. Pranathi', branch: 'AIML', email: 'pranathi.aiml@adarsh.ac.in', sec: 'A', gender: 'FEMALE' },
      { roll: '24HN1A4202', name: 'S. Charan Teja', branch: 'AIML', email: 'charanteja.aiml@adarsh.ac.in', sec: 'A', gender: 'MALE' },
    ];

    const studentPwHash = await bcrypt.hash('Student@123', 10);

    for (const stu of secondYearStudents) {
      // Check existing user by email
      let userId: string;
      const { data: existingUsers } = await supabase.from('users').select('id').eq('email', stu.email).limit(1);
      if (existingUsers && existingUsers.length > 0) {
        userId = existingUsers[0].id;
        await supabase.from('users').update({
          full_name: stu.name,
          college_id: ADARSH_COLLEGE_ID_SB,
          status: 'ACTIVE',
        }).eq('id', userId);
      } else {
        const { data: newU } = await supabase.from('users').insert({
          email: stu.email,
          password_hash: studentPwHash,
          role: 'STUDENT',
          full_name: stu.name,
          college_id: ADARSH_COLLEGE_ID_SB,
          status: 'ACTIVE',
        }).select('id').single();
        userId = newU?.id || '';
      }

      if (userId) {
        // Upsert student
        const { data: stuRow } = await supabase.from('students').upsert({
          user_id: userId,
          college_id: ADARSH_COLLEGE_ID_SB,
          roll_number: stu.roll,
          branch: stu.branch,
          year: '2nd Year',
          section: stu.sec,
          gender: stu.gender,
        }, { onConflict: 'college_id,roll_number' }).select('id').single();

        const sId = stuRow?.id;
        if (sId) {
          const notesObj = {
            assigned_trainer_id: TRAINER_ID,
            assigned_trainer_name: TRAINER_NAME,
            assigned_trainer_email: TRAINER_EMAIL,
            course_name: TRAINER_COURSE,
            allocated_at: new Date().toISOString(),
          };
          await supabase.from('student_behaviour').upsert({
            student_id: sId,
            college_id: ADARSH_COLLEGE_ID_SB,
            attendance_consistency: 94.0,
            participation: 90.0,
            assignment_completion: 92.0,
            assessment_performance: 88.0,
            punctuality: 95.0,
            trainer_notes: JSON.stringify(notesObj),
          }, { onConflict: 'student_id' });
        }
      }
    }

    console.log(`Synced ${secondYearStudents.length} 2nd-year students across CSE, ECE, EEE, MECH, CIVIL, AIDS, AIML to Supabase.`);

  } catch (sbErr: any) {
    console.warn('Supabase sync warning:', sbErr.message);
  }

  // 2. LOCAL POSTGRESQL SYNC (if active)
  try {
    await pool.query(`
      INSERT INTO users (id, email, password_hash, role, full_name, mobile, college_id, status)
      VALUES ($1, $2, $3, 'TRAINER', $4, '+91 98888 33333', $5, 'ACTIVE')
      ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        password_hash = EXCLUDED.password_hash,
        full_name = EXCLUDED.full_name,
        college_id = EXCLUDED.college_id,
        status = 'ACTIVE'
    `, [TRAINER_ID, TRAINER_EMAIL, passwordHash, TRAINER_NAME, ADARSH_COLLEGE_ID_PG]);

    await pool.query(`
      INSERT INTO trainer_assignments (trainer_id, college_id, course_name, target_years, target_branches)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (trainer_id) DO UPDATE SET
        college_id = EXCLUDED.college_id,
        course_name = EXCLUDED.course_name,
        target_years = EXCLUDED.target_years,
        target_branches = EXCLUDED.target_branches
    `, [TRAINER_ID, ADARSH_COLLEGE_ID_PG, TRAINER_COURSE, ['2nd Year'], TARGET_BRANCHES]);

    console.log('PostgreSQL Trainer and Assignment synced successfully.');
  } catch (pgErr: any) {
    console.warn('PostgreSQL sync notice (using Supabase primary):', pgErr.message);
  }

  // 3. UPDATE QUIZZES.JSON DURABLE FILE
  try {
    const quizzesPath = path.join(__dirname, '..', '..', 'data', 'quizzes.json');
    if (fs.existsSync(quizzesPath)) {
      const raw = fs.readFileSync(quizzesPath, 'utf-8');
      const quizzes = JSON.parse(raw);
      for (const q of quizzes) {
        if (q.id === 'quiz-python-daily-01' || q.trainer_name?.includes('Sushma') || q.trainer_email?.includes('sushma')) {
          q.trainer_id = TRAINER_ID;
          q.trainer_name = TRAINER_NAME;
          q.trainer_email = TRAINER_EMAIL;
          q.course_name = TRAINER_COURSE;
          q.target_year = '2nd Year';
          q.target_branch = 'ALL';
        }
      }
      fs.writeFileSync(quizzesPath, JSON.stringify(quizzes, null, 2), 'utf-8');
      console.log('quizzes.json updated for Elisala Sushma (2nd Year, Python Full stack).');
    }
  } catch (qErr: any) {
    console.warn('quizzes.json update error:', qErr.message);
  }

  console.log('=== SYNC COMPLETED SUCCESSFULLY ===');
  process.exit(0);
}

syncElisalaSushma();
