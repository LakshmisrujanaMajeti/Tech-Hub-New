import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function check() {
  const { data: students, error } = await supabase
    .from('students')
    .select('id, roll_number, branch, year, college_id, student_behaviour(trainer_notes)');

  if (error) {
    console.error('Error fetching students:', error);
    return;
  }

  console.log(`Total students across all: ${students.length}`);
  const byCollege = {};
  students.forEach(s => {
    byCollege[s.college_id] = byCollege[s.college_id] || [];
    byCollege[s.college_id].push(s);
  });

  for (const [cId, list] of Object.entries(byCollege)) {
    console.log(`College: ${cId} (Total: ${list.length})`);
    const byYear = {};
    list.forEach(s => {
      const y = s.year || 'UNKNOWN';
      byYear[y] = byYear[y] || [];
      byYear[y].push(s);
    });
    for (const [y, yList] of Object.entries(byYear)) {
      const branches = {};
      yList.forEach(s => {
        const b = s.branch || 'UNKNOWN';
        branches[b] = (branches[b] || 0) + 1;
      });
      console.log(`   Year: ${y} (Count: ${yList.length}) -> Branches:`, branches);
    }
  }

  const { data: assignments } = await supabase
    .from('trainer_assignments')
    .select('*');
  console.log('\nCurrent trainer_assignments:', JSON.stringify(assignments, null, 2));

  // Let's see some samples of 4th year students or any student with roll numbers
  console.log('\nSample students with their years & branches:');
  students.slice(0, 15).forEach(s => {
    console.log(`Roll: ${s.roll_number}, Year: ${s.year}, Branch: ${s.branch}, College: ${s.college_id}`);
  });

  process.exit(0);
}

check();
