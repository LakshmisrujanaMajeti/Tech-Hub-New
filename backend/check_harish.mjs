import { createClient } from '@supabase/supabase-js';
import pg from 'pg';
import bcrypt from 'bcryptjs';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);
const pool = new pg.Pool({
  connectionString: 'postgresql://postgres:postgres@localhost:5432/cognito_techhub'
});

async function main() {
  console.log('--- Checking Supabase for harish ---');
  const { data: sbUsers, error: sbErr } = await supabase
    .from('users')
    .select('id, email, role, full_name, password_hash, status')
    .ilike('email', '%harish%');
  console.log('SB Users matching harish:', sbUsers, 'SB Error:', sbErr);

  const { data: allUsers } = await supabase
    .from('users')
    .select('id, email, role, full_name')
    .eq('role', 'STUDENT')
    .limit(30);
  console.log('Sample SB Student Users:', allUsers);

  const { data: sbStudents } = await supabase
    .from('students')
    .select('*')
    .ilike('roll_number', '%0401%');
  console.log('SB Students (0401):', sbStudents);

  try {
    const pgUsers = await pool.query("SELECT id, email, role, full_name, password_hash, status FROM users WHERE email ILIKE '%harish%'");
    console.log('PG Users:', pgUsers.rows);
    const pgStudents = await pool.query("SELECT * FROM students WHERE roll_number ILIKE '%0401%'");
    console.log('PG Students:', pgStudents.rows);
  } catch (e) {
    console.log('PG query error:', e.message);
  }

  process.exit(0);
}

main();
