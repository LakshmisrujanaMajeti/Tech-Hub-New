import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const sb = createClient(supabaseUrl, supabaseServiceKey);

async function inspectTrainers() {
  const { data: users } = await sb.from('users').select('*').in('role', ['TRAINER', 'FACULTY', 'SUPER_ADMIN', 'ADMIN']);
  console.log('--- USERS WITH TRAINER/ADMIN ROLES ---');
  users?.forEach(u => {
    console.log(`ID: ${u.id} | Email: ${u.email} | Name: ${u.full_name} | Role: ${u.role}`);
  });

  const { data: assignments } = await sb.from('trainer_assignments').select('*');
  console.log('\n--- TRAINER ASSIGNMENTS ---');
  assignments?.forEach(a => {
    console.log(`Assignment ID: ${a.id} | Trainer ID: ${a.trainer_id} | Course: ${a.course_name} | Years: ${JSON.stringify(a.target_years)}`);
  });
}

inspectTrainers().catch(console.error);
