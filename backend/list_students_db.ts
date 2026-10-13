import 'dotenv/config';
import { supabase } from './src/db/supabase.js';

async function listAll() {
  const { data: students, count } = await supabase.from('students').select('id, roll_number, branch, year, college_id, users(full_name, email)', { count: 'exact' });
  console.log('Total students:', count);
  students?.forEach((s, idx) => {
    const u = s.users as any;
    console.log(`${idx + 1}: ${s.roll_number} - ${u?.full_name} (${u?.email}) [${s.branch} - ${s.year}]`);
  });
  process.exit(0);
}
listAll();
