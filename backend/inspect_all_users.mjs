import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkAllUsers() {
  const { data: users, error } = await supabase.from('users').select('*').limit(200);
  console.log(`Total users in Supabase: ${users.length}`);
  for (const u of users) {
    if (u.full_name?.includes('Sai') || u.full_name?.includes('Satya') || u.full_name?.includes('Adarsh') || u.email?.includes('satya')) {
      console.log(`User: ${u.id}, Email: ${u.email}, Name: ${u.full_name}, Role: ${u.role}, College: ${u.college_id}`);
    }
  }

  // Let's also check all colleges in Supabase
  const { data: colleges } = await supabase.from('colleges').select('*');
  console.log('\nAll Colleges in Supabase:');
  console.log(colleges);

  process.exit(0);
}

checkAllUsers();
