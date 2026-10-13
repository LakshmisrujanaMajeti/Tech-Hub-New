import pg from 'pg';
import { createClient } from '@supabase/supabase-js';

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/cognito_techhub',
});

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function check() {
  console.log('=== LOCAL PG CHECK ===');
  try {
    const taRes = await pool.query('SELECT * FROM trainer_assignments');
    console.log('Local PG trainer_assignments:', taRes.rows);

    const stuRes = await pool.query(`
      SELECT s.id, s.roll_number, s.year, s.branch, s.college_id, u.full_name, u.email
      FROM students s
      JOIN users u ON s.user_id = u.id
    `);
    console.log('Local PG total students:', stuRes.rows.length);
    const pgByYear = {};
    stuRes.rows.forEach(r => {
      pgByYear[r.year] = (pgByYear[r.year] || 0) + 1;
    });
    console.log('Local PG students by year:', pgByYear);
    console.log('Local PG students sample:', stuRes.rows.slice(0, 10));
  } catch (err) {
    console.log('Local PG error:', err.message);
  }

  console.log('\n=== SUPABASE CHECK ===');
  try {
    const { data: taSb } = await supabase.from('trainer_assignments').select('*');
    console.log('Supabase trainer_assignments:', taSb);

    const { data: stuSb } = await supabase.from('students').select('id, roll_number, year, branch, college_id, users(full_name, email)');
    console.log('Supabase total students:', stuSb.length);
    const sbByYear = {};
    stuSb.forEach(r => {
      sbByYear[r.year] = (sbByYear[r.year] || 0) + 1;
    });
    console.log('Supabase students by year:', sbByYear);
    console.log('Supabase students sample:', stuSb.slice(0, 10));
  } catch (err) {
    console.log('Supabase error:', err.message);
  }

  process.exit(0);
}

check();
