import 'dotenv/config';
import { supabase } from './src/db/supabase.js';

async function inspect() {
  const { data: colleges } = await supabase.from('colleges').select('*');
  console.log('Colleges count:', colleges?.length);
  colleges?.forEach(c => console.log(`- ${c.id}: ${c.short_name} (${c.college_code})`));
  
  const { data: students, count } = await supabase.from('students').select('id, college_id, roll_number, branch, year', { count: 'exact' });
  console.log('Total students in DB:', count);
  
  const byCol: Record<string, number> = {};
  students?.forEach(s => {
    byCol[s.college_id] = (byCol[s.college_id] || 0) + 1;
  });
  console.log('Students by college_id:', byCol);
  
  const kitsCollege = colleges?.find(c => c.short_name?.includes('KITS') || c.college_code?.includes('KITS'));
  const adarshCollege = colleges?.find(c => c.short_name?.includes('Adarsh') || c.college_code?.includes('ADARSH'));
  console.log('KITS College:', kitsCollege?.id, kitsCollege?.short_name);
  console.log('Adarsh College:', adarshCollege?.id, adarshCollege?.short_name);

  if (kitsCollege) {
    const kitsStudents = students?.filter(s => s.college_id === kitsCollege.id);
    console.log('KITS Students found count:', kitsStudents?.length);
    console.log('KITS Students:', kitsStudents);
  }

  if (adarshCollege) {
    const adarshStudents = students?.filter(s => s.college_id === adarshCollege.id);
    console.log('Adarsh Students count:', adarshStudents?.length);
  }

  process.exit(0);
}
inspect().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
