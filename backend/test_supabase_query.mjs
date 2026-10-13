import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testQuery() {
  const collegeId = 'ce3937d8-db9a-4002-8128-bf5a68bec78b';
  const targetYears = ['2nd Year', '4th Year'];

  console.log('--- Test 1: users!inner with in(year) ---');
  const { data: d1, error: e1 } = await supabase
    .from('students')
    .select('*, users!inner(full_name, email, mobile), colleges(short_name, college_name)')
    .eq('college_id', collegeId)
    .in('year', targetYears)
    .limit(100);
  console.log('d1 count:', d1?.length, 'e1:', e1);

  console.log('\n--- Test 2: users (without !inner) ---');
  const { data: d2, error: e2 } = await supabase
    .from('students')
    .select('*, users(full_name, email, mobile), colleges(short_name, college_name)')
    .eq('college_id', collegeId)
    .limit(200);
  console.log('d2 count:', d2?.length, 'e2:', e2);
  const byYear2 = {};
  d2?.forEach(s => { byYear2[s.year] = (byYear2[s.year] || 0) + 1; });
  console.log('d2 by year:', byYear2);

  process.exit(0);
}

testQuery();
