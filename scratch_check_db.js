const { Pool } = require('pg');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '../backend/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/cognito_techhub'
});

const supabase = createClient(
  process.env.SUPABASE_URL || 'https://wumzszxogbvqjjzvvvmt.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || ''
);

async function check() {
  try {
    console.log('--- PostgreSQL Check ---');
    const uRes = await pool.query("SELECT id, email, full_name, role, college_id FROM users");
    console.log('All Users in PG:', uRes.rows);

    const sRes = await pool.query("SELECT * FROM students");
    console.log('All Students in PG:', sRes.rows);

    const arRes = await pool.query("SELECT * FROM attendance_records");
    console.log('All Attendance Records in PG:', arRes.rows);

    const sessRes = await pool.query("SELECT * FROM sessions");
    console.log('All Sessions in PG:', sessRes.rows);

    const enrollRes = await pool.query("SELECT * FROM student_batch_enrollments");
    console.log('All Batch Enrollments in PG:', enrollRes.rows);

    console.log('--- Supabase Check ---');
    const { data: sbUsers } = await supabase.from('users').select('*');
    console.log('Supabase users:', sbUsers);

    const { data: sbStudents } = await supabase.from('students').select('*');
    console.log('Supabase students:', sbStudents);

    const { data: sbAtt } = await supabase.from('attendance_records').select('*');
    console.log('Supabase attendance_records:', sbAtt);

    const { data: sbSess } = await supabase.from('sessions').select('*');
    console.log('Supabase sessions:', sbSess);

  } catch (err) {
    console.error('Error:', err);
  } finally {
    pool.end();
  }
}

check();
