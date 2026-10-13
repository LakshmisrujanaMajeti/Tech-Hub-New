import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const sb = createClient(supabaseUrl, supabaseServiceKey);

async function main() {
  const { data: students } = await sb.from('students').select('id, roll_number, year, branch, college_id, users(full_name, email)');

  function classifyStudent(s) {
    const roll = (s.roll_number || '').toUpperCase().trim();
    const y = (s.year || '').toLowerCase().trim();

    const isExplicit4th = y.includes('4') || y.includes('4th') || roll.startsWith('21HN') || roll.startsWith('22HN');
    const isExplicit3rd = !isExplicit4th && (y.includes('3') || y.includes('3rd') || roll.startsWith('23HN') || roll.startsWith('24HN5'));
    const isExplicit2nd = !isExplicit4th && !isExplicit3rd && (y.includes('2') || y.includes('2nd') || roll.startsWith('24HN1') || roll.startsWith('25HN5') || (roll.startsWith('24HN') && !roll.startsWith('24HN5')));

    let normBranch = (s.branch || 'CSE').trim();
    if (roll.includes('A05') || normBranch.toUpperCase() === 'CSE') normBranch = 'CSE';
    else if (roll.includes('A04') || normBranch.toUpperCase() === 'ECE') normBranch = 'ECE';
    else if (roll.includes('A02') || normBranch.toUpperCase() === 'EEE') normBranch = 'EEE';
    else if (roll.includes('A03') || normBranch.toUpperCase().includes('MECH')) normBranch = 'Mechanical';
    else if (roll.includes('A01') || normBranch.toUpperCase().includes('CIVIL')) normBranch = 'Civil';
    else if (roll.includes('A54') || normBranch.toUpperCase().includes('AIDS') || normBranch.toUpperCase().includes('AI&DS') || normBranch.toUpperCase().includes('AI & DS')) normBranch = 'AI & DS';
    else if (roll.includes('A42') || normBranch.toUpperCase().includes('AIML') || normBranch.toUpperCase().includes('AI&ML') || normBranch.toUpperCase().includes('AI & ML')) normBranch = 'AI & ML';

    return {
      is2nd: isExplicit2nd,
      is3rd: isExplicit3rd,
      is4th: isExplicit4th,
      normBranch
    };
  }

  const sushmaBranches = ['CSE', 'ECE', 'EEE', 'Mechanical', 'Civil', 'AI & DS', 'AI & ML'];
  const daivaBranches = ['CSE', 'ECE', 'EEE', 'Civil', 'Mechanical'];

  const sushma = students.filter(s => {
    const c = classifyStudent(s);
    return (c.is2nd || c.is4th) && !c.is3rd && sushmaBranches.includes(c.normBranch);
  });

  const daiva = students.filter(s => {
    const c = classifyStudent(s);
    return (c.is3rd || c.is4th) && !c.is2nd && daivaBranches.includes(c.normBranch);
  });

  console.log(`\n=== SUSHMA ELISALA (Python Full Stack - Adarsh College) ===`);
  console.log(`Total: ${sushma.length}`);
  const sYears = {};
  const sBranches = {};
  sushma.forEach(s => {
    sYears[s.year] = (sYears[s.year] || 0) + 1;
    sBranches[s.branch] = (sBranches[s.branch] || 0) + 1;
  });
  console.log('Years:', sYears);
  console.log('Branches:', sBranches);

  console.log(`\n=== PATHIVADA DAIVA RAO (Java Full Stack - Adarsh College) ===`);
  console.log(`Total: ${daiva.length}`);
  const dYears = {};
  const dBranches = {};
  daiva.forEach(s => {
    dYears[s.year] = (dYears[s.year] || 0) + 1;
    dBranches[s.branch] = (dBranches[s.branch] || 0) + 1;
  });
  console.log('Years:', dYears);
  console.log('Branches:', dBranches);
}

main().catch(console.error);
