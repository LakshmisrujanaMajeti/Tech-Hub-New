import { pool } from './pool.js';
import { supabase } from './supabase.js';

async function main() {
  console.log('=== CHECKING POSTGRESQL ===');
  try {
    const users = await pool.query(`SELECT id, email, full_name, role, college_id FROM users WHERE email ILIKE '%sushma%' OR full_name ILIKE '%sushma%' OR email ILIKE '%elisala%'`);
    console.log('PG Users matching sushma/elisala:', users.rows);

    const colleges = await pool.query(`SELECT id, college_name, short_name, college_code, roll_code FROM colleges`);
    console.log('PG Colleges:', colleges.rows);

    const adarshCollege = colleges.rows.find(c => c.short_name?.toLowerCase().includes('adarsh') || c.college_name?.toLowerCase().includes('adarsh'));
    const adarshId = adarshCollege?.id;
    console.log('Adarsh College ID:', adarshId);

    const students = await pool.query(`
      SELECT s.id, s.roll_number, s.year, s.branch, u.full_name, u.email
      FROM students s
      JOIN users u ON s.user_id = u.id
      WHERE s.college_id = $1 OR $1 IS NULL
      ORDER BY s.year, s.branch, s.roll_number
    `, [adarshId]);
    console.log(`Total students for Adarsh in PG: ${students.rows.length}`);
    console.log('Sample PG students:', students.rows.slice(0, 15));

    const yearCounts = await pool.query(`
      SELECT year, branch, COUNT(*)
      FROM students
      GROUP BY year, branch
      ORDER BY year, branch
    `);
    console.log('PG Students grouped by year and branch:', yearCounts.rows);

    const trainerAssignments = await pool.query(`
      SELECT ta.*, u.full_name, u.email
      FROM trainer_assignments ta
      JOIN users u ON ta.trainer_id = u.id
    `);
    console.log('PG Trainer Assignments:', trainerAssignments.rows);

  } catch (err: any) {
    console.error('PG Error:', err.message);
  }

  console.log('\n=== CHECKING SUPABASE ===');
  try {
    const { data: sbUsers, error: sbUserErr } = await supabase.from('users').select('*').or('email.ilike.%sushma%,email.ilike.%elisala%,full_name.ilike.%sushma%');
    console.log('Supabase Users matching sushma/elisala:', sbUsers, sbUserErr);

    const { data: sbColleges } = await supabase.from('colleges').select('id, college_name, short_name, college_code');
    console.log('Supabase Colleges:', sbColleges);

    const { data: sbStudents, error: sbStuErr } = await supabase.from('students').select('id, roll_number, year, branch, college_id');
    console.log('Supabase Total Students:', sbStudents?.length, sbStuErr);
    if (sbStudents && sbStudents.length > 0) {
      console.log('Sample Supabase students:', sbStudents.slice(0, 10));
    }

    const { data: sbAssignments } = await supabase.from('trainer_assignments').select('*');
    console.log('Supabase Trainer Assignments:', sbAssignments);
  } catch (err: any) {
    console.error('Supabase Error:', err.message);
  }

  process.exit(0);
}

main();
