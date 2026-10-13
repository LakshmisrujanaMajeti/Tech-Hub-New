import pg from 'pg';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/cognito_techhub',
});

const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

async function inspect() {
  console.log('--- USERS WITH SUSHMA ---');
  const userRes = await pool.query(`SELECT id, email, full_name, role, college_id FROM users WHERE email ILIKE '%sushma%'`);
  console.log(userRes.rows);

  console.log('--- ALL TRAINERS ---');
  const trainersRes = await pool.query(`SELECT id, email, full_name, role, college_id FROM users WHERE role = 'TRAINER'`);
  console.log(trainersRes.rows);

  console.log('--- TRAINER ASSIGNMENTS ---');
  const taRes = await pool.query(`SELECT ta.*, u.full_name, u.email FROM trainer_assignments ta JOIN users u ON ta.trainer_id = u.id`);
  console.log(taRes.rows);

  console.log('--- 2ND YEAR STUDENTS OF ADARSH ---');
  const stu2Res = await pool.query(`
    SELECT s.id, s.user_id, s.roll_number, s.year, s.branch, s.college_id, u.full_name, u.email
    FROM students s
    JOIN users u ON s.user_id = u.id
    WHERE s.year ILIKE '%2%'
  `);
  console.log('Count of 2nd year students:', stu2Res.rows.length);
  console.log(stu2Res.rows.slice(0, 10));

  console.log('--- ALL STUDENTS BY YEAR ---');
  const yrCounts = await pool.query(`
    SELECT year, branch, COUNT(*) FROM students GROUP BY year, branch ORDER BY year, branch
  `);
  console.log(yrCounts.rows);

  await pool.end();
}

inspect().catch(console.error);
