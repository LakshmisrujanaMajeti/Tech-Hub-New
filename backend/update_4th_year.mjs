import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function updateAssignments() {
  const collegeId = 'ce3937d8-db9a-4002-8128-bf5a68bec78b';
  
  // 1. Update Sushma Elisala (2nd Year & 4th Year)
  const { data: sushmaUpdate, error: sushmaErr } = await supabase
    .from('trainer_assignments')
    .update({
      target_years: ['2nd Year', '4th Year'],
      target_branches: ['CSE', 'ECE', 'EEE', 'Mechanical', 'Civil', 'AI & DS', 'AI & ML', 'AIDS', 'AIML', 'AI-DS', 'AI-ML', 'MECH', 'CIVIL', 'ALL']
    })
    .eq('trainer_id', '48632025-1678-4014-925a-86391063614b')
    .eq('college_id', collegeId);

  console.log('Sushma assignment update result:', sushmaUpdate, sushmaErr);

  // 2. Update Pathivada Daiva Rao (3rd Year & 4th Year)
  const { data: daivaUpdate, error: daivaErr } = await supabase
    .from('trainer_assignments')
    .update({
      target_years: ['3rd Year', '4th Year'],
      target_branches: ['CSE', 'ECE', 'EEE', 'Civil', 'Mechanical', 'CIVIL', 'MECH']
    })
    .eq('trainer_id', '0ed2be5c-fce6-4e4f-83eb-96be2b162746')
    .eq('college_id', collegeId);

  console.log('Daiva assignment update result:', daivaUpdate, daivaErr);

  // 3. Update 21HN1A5403 to 4th Year
  const { data: stuUpdate, error: stuErr } = await supabase
    .from('students')
    .update({ year: '4th Year' })
    .eq('roll_number', '21HN1A5403');
  console.log('21HN1A5403 update result:', stuUpdate, stuErr);

  const { data: assignments } = await supabase.from('trainer_assignments').select('*');
  console.log('Updated assignments:', JSON.stringify(assignments, null, 2));

  process.exit(0);
}

updateAssignments();
