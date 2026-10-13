import { supabase } from './supabase.js';

async function checkMore() {
  const { data: colleges } = await supabase.from('colleges').select('*');
  console.log('Colleges table count:', colleges?.length);
  console.log('Colleges:', colleges);

  const { data: users } = await supabase.from('users').select('id, email, role, full_name, college_id');
  console.log('Users by role:');
  const roleGroups: Record<string, any[]> = {};
  users?.forEach((u: any) => {
    roleGroups[u.role] = roleGroups[u.role] || [];
    roleGroups[u.role].push(u);
  });
  for (const role in roleGroups) {
    console.log(`Role: ${role} (${roleGroups[role].length})`);
    roleGroups[role].slice(0, 5).forEach((u: any) => console.log(`  - ${u.full_name} <${u.email}> (${u.college_id})`));
  }
}

checkMore();
