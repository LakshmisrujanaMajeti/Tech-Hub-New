import { supabase } from './supabase.js';

async function checkData() {
  const tables = ['organizations', 'users', 'students', 'programs', 'courses', 'materials', 'announcements', 'attendance'];
  for (const t of tables) {
    const { data, error, count } = await supabase.from(t).select('*', { count: 'exact' });
    console.log(`Table ${t}: count=${data?.length || 0}`);
    if (data && data.length > 0) {
      if (t === 'organizations') {
        console.log('Organizations:', data.map(o => ({ id: o.id, name: o.name, code: o.code })));
      } else if (t === 'users') {
        console.log('Users:', data.map(u => ({ id: u.id, email: u.email, role: u.role, full_name: u.full_name })));
      } else if (t === 'students') {
        console.log('Students:', data.map(s => ({ id: s.id, roll_number: s.roll_number, name: s.name, year: s.year, college_id: s.college_id })));
      } else if (t === 'programs' || t === 'courses') {
        console.log(`${t}:`, data.map(x => ({ id: x.id, name: x.name || x.title })));
      }
    }
  }
}

checkData();
