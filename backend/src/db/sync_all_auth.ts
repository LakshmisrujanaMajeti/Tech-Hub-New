import bcrypt from 'bcryptjs';
import { supabase } from './supabase.js';

async function syncAllAuthAndAssignments() {
  console.log('=== SYNCING PASSWORDS AND TRAINER ASSIGNMENTS ===');

  const adminHash = await bcrypt.hash('Admin@123', 10);
  const trainerHash = await bcrypt.hash('Trainer@123', 10);

  // 1. Sync passwords for all staff accounts
  const staffEmails = [
    'admin@kitsdivili.ac.in',
    'admin@adarsh.ac.in',
    'tpo@kitsdivili.ac.in',
    'tpo@adarsh.ac.in',
    'admin@cognitoinsights.ai',
    'superadmin@cognitoinsights.ai'
  ];

  for (const email of staffEmails) {
    const { data: user } = await supabase.from('users').select('id, email').eq('email', email).maybeSingle();
    if (user) {
      await supabase.from('users').update({ password_hash: adminHash }).eq('id', user.id);
      console.log(`Updated password for ${email}`);
    }
  }

  // 2. Sync trainer passwords
  const trainerEmails = [
    'sushma.python@cognitoinsights.ai',
    'daivarao.techhub@cognitoinsights.ai'
  ];

  for (const email of trainerEmails) {
    const { data: user } = await supabase.from('users').select('id, email').eq('email', email).maybeSingle();
    if (user) {
      await supabase.from('users').update({ password_hash: trainerHash }).eq('id', user.id);
      console.log(`Updated password for ${email}`);
    }
  }

  // 3. Ensure both trainers are assigned to both KITS Divili and Adarsh
  const { data: colleges } = await supabase.from('colleges').select('id, college_code');
  const kitsId = colleges?.find(c => c.college_code === 'KITS_DIVILI')?.id || 'ae02729b-30ec-43f8-993b-15579252af3c';
  const adarshId = colleges?.find(c => c.college_code === 'ADARSH')?.id || 'ce3937d8-db9a-4002-8128-bf5a68bec78b';

  const { data: sushmaUser } = await supabase.from('users').select('id').eq('email', 'sushma.python@cognitoinsights.ai').single();
  const { data: daivaUser } = await supabase.from('users').select('id').eq('email', 'daivarao.techhub@cognitoinsights.ai').single();

  if (sushmaUser) {
    for (const colId of [kitsId, adarshId]) {
      await supabase.from('trainer_assignments').upsert({
        trainer_id: sushmaUser.id,
        college_id: colId,
        course_name: 'Python Full Stack & AI',
        target_years: ['2nd Year', '3rd Year'],
        target_branches: ['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH']
      }, { onConflict: 'trainer_id,college_id' });
    }
    console.log('Assigned Sushma Madam to both partner colleges (2nd & 3rd Year Python).');
  }

  if (daivaUser) {
    for (const colId of [kitsId, adarshId]) {
      await supabase.from('trainer_assignments').upsert({
        trainer_id: daivaUser.id,
        college_id: colId,
        course_name: 'Technical Skills & Python Foundations',
        target_years: ['1st Year', '4th Year'],
        target_branches: ['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH']
      }, { onConflict: 'trainer_id,college_id' });
    }
    console.log('Assigned Daiva Rao to both partner colleges (1st & 4th Year).');
  }

  console.log('=== SYNC COMPLETED ===');
}

syncAllAuthAndAssignments();
