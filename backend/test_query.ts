import 'dotenv/config';
import { supabase } from './src/db/supabase.js';

async function test() {
  const { data, error } = await supabase
    .from('students')
    .select('*, users!inner(full_name, email, mobile, status), colleges(short_name, college_name, logo_url), student_behaviour(attendance_consistency, participation, assignment_completion, assessment_performance, punctuality, trainer_notes)')
    .limit(5);
  console.log('Error with !inner:', error);
  console.log('Data length:', data?.length);

  const { data: d2, error: e2 } = await supabase
    .from('students')
    .select('*, users(full_name, email, mobile, status), colleges(short_name, college_name, logo_url)')
    .limit(5);
  console.log('Error without !inner:', e2);
  console.log('D2 length:', d2?.length);
  process.exit(0);
}
test().catch(e => { console.error(e); process.exit(1); });
