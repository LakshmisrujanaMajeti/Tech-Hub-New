import { supabase } from './supabase.js';

async function listAll() {
  console.log('--- USERS ---');
  const { data: users } = await supabase.from('users').select('*').order('role');
  users?.forEach(u => console.log(`${u.role} | ${u.full_name} | ${u.email} | ${u.mobile} | college: ${u.college_id}`));

  console.log('\n--- COLLEGES ---');
  const { data: colleges } = await supabase.from('colleges').select('*');
  colleges?.forEach(c => console.log(`${c.id} | ${c.college_code} | ${c.short_name} | ${c.college_name}`));

  console.log('\n--- TRAINER ASSIGNMENTS ---');
  const { data: ta } = await supabase.from('trainer_assignments').select('*');
  console.log(ta);

  console.log('\n--- ANNOUNCEMENTS ---');
  const { data: ann } = await supabase.from('announcements').select('*');
  console.log(ann);

  console.log('\n--- SESSIONS ---');
  const { data: sess } = await supabase.from('sessions').select('*');
  console.log(`Count: ${sess?.length}`);

  console.log('\n--- BATCHES ---');
  const { data: batches } = await supabase.from('batches').select('*');
  console.log(batches);
}

listAll();
