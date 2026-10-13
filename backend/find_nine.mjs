import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function findNine() {
  const { data: students } = await supabase
    .from('students')
    .select('id, roll_number, year, branch, users(full_name, email)');

  console.log(`Total students: ${students.length}`);
  const matching = students.filter(s => {
    const fn = s.users?.full_name || '';
    return fn.includes('Adarsh') || fn.includes('Alugolu') || fn.includes('Satya') || s.roll_number.startsWith('21HN') || s.roll_number.startsWith('22HN');
  });
  console.log('Matching sample:', JSON.stringify(matching, null, 2));

  process.exit(0);
}

findNine();
