import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  const { data: bData } = await supabase.from('student_behaviour').select('*').limit(1);
  console.log('student_behaviour sample:', bData);

  const { data: mData } = await supabase.from('materials').select('*').limit(1);
  console.log('materials sample:', mData);

  // Check all available tables in public schema via rpc or select
  const { data: users } = await supabase.from('users').select('id, email, role').limit(2);
  console.log('users sample:', users);
}

check().catch(console.error);
