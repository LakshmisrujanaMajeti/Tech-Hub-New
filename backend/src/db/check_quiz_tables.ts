import { pool } from './pool.js';
import { supabase } from './supabase.js';

async function check() {
  try {
    const res = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name;
    `);
    console.log('PostgreSQL tables:', res.rows.map(r => r.table_name));
  } catch (e: any) {
    console.error('PG Error:', e.message);
  }

  try {
    const { data: qData, error: qErr } = await supabase.from('quizzes').select('*').limit(5);
    console.log('Supabase quizzes exists:', !qErr, qErr?.message || 'OK');
  } catch (e: any) {
    console.log('Supabase check error:', e.message);
  }
  process.exit(0);
}

check();
