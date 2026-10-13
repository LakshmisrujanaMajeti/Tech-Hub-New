import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkAdarsh() {
  const collegeId = 'ce3937d8-db9a-4002-8128-bf5a68bec78b';
  const { data: students, error } = await supabase
    .from('students')
    .select('id, roll_number, year, branch, users(full_name, email, mobile)')
    .eq('college_id', collegeId);

  console.log(`Total Adarsh students in Supabase: ${students?.length}`);
  
  const byYear = {};
  students?.forEach(s => {
    byYear[s.year] = byYear[s.year] || { count: 0, branches: {} };
    byYear[s.year].count++;
    byYear[s.year].branches[s.branch] = (byYear[s.year].branches[s.branch] || 0) + 1;
  });
  console.log('Adarsh students breakdown in Supabase:');
  console.log(JSON.stringify(byYear, null, 2));

  process.exit(0);
}

checkAdarsh();
