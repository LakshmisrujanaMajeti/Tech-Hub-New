import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const sb = createClient(supabaseUrl, supabaseServiceKey);

async function checkAllStudents() {
  const { data: students, error } = await sb
    .from('students')
    .select('id, roll_number, branch, year, college_id, users(full_name, email, mobile), colleges(college_name, short_name)');

  if (error) {
    console.error('Error:', error);
    return;
  }

  console.log('--- ALL STUDENTS SUMMARY ---');
  console.log('Total Registered Students:', students.length);

  // Group by year
  const byYear = {};
  const byBranchIn4thYear = {};

  const fourthYears = [];

  students.forEach(s => {
    byYear[s.year] = (byYear[s.year] || 0) + 1;
    const yStr = (s.year || '').toString().toLowerCase();
    const rStr = (s.roll_number || '').toString().toUpperCase();

    if (yStr.includes('4') || rStr.startsWith('21HN') || rStr.startsWith('22HN')) {
      fourthYears.push(s);
      byBranchIn4thYear[s.branch] = (byBranchIn4thYear[s.branch] || 0) + 1;
    }
  });

  console.log('\nBreakdown by Academic Year:');
  console.log(JSON.stringify(byYear, null, 2));

  console.log('\n4th Year Student Count:', fourthYears.length);
  console.log('4th Year Breakdown by Branch:', JSON.stringify(byBranchIn4thYear, null, 2));

  console.log('\n4th Year Student Details:');
  fourthYears.forEach((s, idx) => {
    console.log(`${idx + 1}. Roll: ${s.roll_number} | Name: ${s.users?.full_name} | Branch: ${s.branch} | Year: ${s.year} | Email: ${s.users?.email} | College: ${s.colleges?.short_name || s.colleges?.college_name}`);
  });
}

checkAllStudents();
