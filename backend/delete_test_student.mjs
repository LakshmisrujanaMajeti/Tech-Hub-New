import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const sb = createClient(supabaseUrl, supabaseServiceKey);

async function removeTestStudent() {
  console.log('Searching for test student Pitani Sravya / 21HN1A5403...');

  // 1. Find the student record
  const { data: students, error: sErr } = await sb
    .from('students')
    .select('*, users(*)')
    .or('roll_number.eq.21HN1A5403,roll_number.ilike.%21HN1A5403%');

  if (sErr) {
    console.error('Error finding student:', sErr);
    return;
  }

  console.log('Found students:', JSON.stringify(students, null, 2));

  for (const s of (students || [])) {
    const studentId = s.id;
    const userId = s.user_id;

    console.log(`Cleaning up studentId: ${studentId}, userId: ${userId}...`);

    // Remove from attendance_records
    const { error: attErr } = await sb.from('attendance_records').delete().eq('student_id', studentId);
    if (attErr) console.warn('attendance_records delete note:', attErr.message);

    // Remove from student_behaviour
    const { error: behErr } = await sb.from('student_behaviour').delete().eq('student_id', studentId);
    if (behErr) console.warn('student_behaviour delete note:', behErr.message);

    // Remove from quiz_submissions if table exists
    try {
      await sb.from('quiz_submissions').delete().eq('student_id', studentId);
    } catch (_) {}

    // Remove from test_submissions if table exists
    try {
      await sb.from('test_submissions').delete().eq('student_id', studentId);
    } catch (_) {}

    // Delete from students table
    const { error: delStuErr } = await sb.from('students').delete().eq('id', studentId);
    if (delStuErr) {
      console.error('Error deleting from students:', delStuErr);
    } else {
      console.log(`Successfully deleted student record ${studentId} (Roll: ${s.roll_number})`);
    }

    // Delete from users table if userId exists
    if (userId) {
      const { error: delUserErr } = await sb.from('users').delete().eq('id', userId);
      if (delUserErr) {
        console.error('Error deleting from users:', delUserErr);
      } else {
        console.log(`Successfully deleted user record ${userId} (${s.users?.email || s.users?.full_name})`);
      }
    }
  }

  // Also check if any leftover user with email sravyapitani45@gmail.com
  const { data: leftoverUsers } = await sb.from('users').select('*').ilike('email', '%sravyapitani%');
  for (const u of (leftoverUsers || [])) {
    console.log('Deleting leftover user:', u.id, u.email);
    await sb.from('students').delete().eq('user_id', u.id);
    await sb.from('users').delete().eq('id', u.id);
  }

  // Verification
  console.log('\n--- VERIFYING CURRENT DATABASE STATE ---');
  const { data: allRemaining } = await sb.from('students').select('id, roll_number, year, branch, users(full_name, email)');
  console.log('Total remaining students in Supabase:', allRemaining?.length);
  
  const yearCounts = {};
  allRemaining?.forEach(st => {
    yearCounts[st.year] = (yearCounts[st.year] || 0) + 1;
  });
  console.log('Remaining students by academic year:', yearCounts);
}

removeTestStudent().catch(console.error);
