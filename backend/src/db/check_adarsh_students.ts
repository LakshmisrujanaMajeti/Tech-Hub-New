import { supabase } from './supabase.js';

async function checkStudents() {
  const { data: students, error } = await supabase
    .from('students')
    .select('id, user_id, roll_number, year, branch, college_id, users(id, email, full_name)')
    .eq('college_id', 'ce3937d8-db9a-4002-8128-bf5a68bec78b');

  console.log(`Total students in Adarsh (${students?.length}):`);
  if (students) {
    const byYear: Record<string, any[]> = {};
    for (const s of students) {
      const yr = s.year || 'Unknown';
      if (!byYear[yr]) byYear[yr] = [];
      byYear[yr].push({ roll: s.roll_number, branch: s.branch, name: (s.users as any)?.full_name, email: (s.users as any)?.email });
    }
    for (const [yr, list] of Object.entries(byYear)) {
      console.log(`\nYear: ${yr} (Count: ${list.length})`);
      const branches = list.reduce((acc, cur) => {
        acc[cur.branch] = (acc[cur.branch] || 0) + 1;
        return acc;
      }, {});
      console.log('Branches:', branches);
      console.log('Sample students:', list.slice(0, 5));
    }
  }

  process.exit(0);
}

checkStudents();
