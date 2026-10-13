import { supabase } from './supabase.js';
import bcrypt from 'bcryptjs';

async function cleanupSuperAdminData() {
  console.log('=== STARTING SUPER ADMIN DATA CLEANUP ===');

  // 1. Delete dummy announcements
  const { error: annErr } = await supabase
    .from('announcements')
    .delete()
    .or('title.ilike.%test%,message.ilike.%test%');
  console.log('Cleaned dummy announcements:', annErr || 'OK');

  // 2. Delete dummy trainer assignments for deleted dummy trainers
  const dummyTrainerEmails = [
    'trainer.python@cognitoinsights.ai',
    'trainer.java@cognitoinsights.ai',
    'daivarao@cognitoinsights.ai', // duplicate
  ];

  const { data: dummyTrainers } = await supabase
    .from('users')
    .select('id, email')
    .in('email', dummyTrainerEmails);

  if (dummyTrainers && dummyTrainers.length > 0) {
    const dummyTrainerIds = dummyTrainers.map(t => t.id);
    const { error: taErr } = await supabase
      .from('trainer_assignments')
      .delete()
      .in('trainer_id', dummyTrainerIds);
    console.log('Cleaned dummy trainer assignments:', taErr || 'OK');

    const { error: trUserErr } = await supabase
      .from('users')
      .delete()
      .in('id', dummyTrainerIds);
    console.log('Deleted dummy trainer users:', trUserErr || 'OK');
  }

  // 3. Delete dummy students
  const dummyStudentEmails = [
    'student.kits@gmail.com',
    'student.1styear@gmail.com',
    'student.2ndyear@gmail.com',
    'student.4thyear@gmail.com',
    'student.adarsh@gmail.com',
    'student@cognitoinsights.ai'
  ];

  const { data: dummyStudents } = await supabase
    .from('users')
    .select('id, email')
    .in('email', dummyStudentEmails);

  if (dummyStudents && dummyStudents.length > 0) {
    const dummyStudentUserIds = dummyStudents.map(s => s.id);
    await supabase.from('student_behaviour').delete().in('student_id', dummyStudentUserIds);
    await supabase.from('students').delete().in('user_id', dummyStudentUserIds);
    await supabase.from('users').delete().in('id', dummyStudentUserIds);
    console.log('Deleted dummy student user accounts and records.');
  }

  // Also delete dummy roll numbers from students table if any
  const dummyRolls = ['20KITS0501', '21KITS0501', '23KITS0501', '24KITS0501'];
  const { error: rollErr } = await supabase.from('students').delete().in('roll_number', dummyRolls);
  console.log('Deleted dummy student roll numbers:', rollErr || 'OK');

  // 4. Ensure Super Admin users are clean and standard
  // Standard super admins: admin@cognitoinsights.ai and superadmin@cognitoinsights.ai
  const hash = await bcrypt.hash('Admin@123', 10);
  
  // Make sure admin@cognitoinsights.ai has valid password
  await supabase.from('users').upsert({
    email: 'admin@cognitoinsights.ai',
    password_hash: hash,
    role: 'SUPER_ADMIN',
    full_name: 'Cognito Super Admin',
    mobile: '+91 98765 43210',
    status: 'ACTIVE'
  }, { onConflict: 'email' });

  await supabase.from('users').upsert({
    email: 'superadmin@cognitoinsights.ai',
    password_hash: hash,
    role: 'SUPER_ADMIN',
    full_name: 'Cognito Super Admin',
    mobile: '+91 98765 43210',
    status: 'ACTIVE'
  }, { onConflict: 'email' });

  // 5. Ensure Daiva Rao and Sushma Madam trainer assignments are accurately linked
  const { data: kitsCollege } = await supabase.from('colleges').select('id').eq('college_code', 'KITS_DIVILI').single();
  const { data: adarshCollege } = await supabase.from('colleges').select('id').eq('college_code', 'ADARSH').single();

  const kitsId = kitsCollege?.id || 'ae02729b-30ec-43f8-993b-15579252af3c';
  const adarshId = adarshCollege?.id || 'ce3937d8-db9a-4002-8128-bf5a68bec78b';

  const { data: daivaUser } = await supabase.from('users').select('id').eq('email', 'daivarao.techhub@cognitoinsights.ai').single();
  const { data: sushmaUser } = await supabase.from('users').select('id').eq('email', 'sushma.python@cognitoinsights.ai').single();

  if (daivaUser) {
    await supabase.from('trainer_assignments').upsert({
      trainer_id: daivaUser.id,
      college_id: kitsId,
      course_name: 'Technical Skills & Python Foundations',
      target_years: ['1st Year', '4th Year'],
      target_branches: ['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH']
    }, { onConflict: 'trainer_id,college_id' });
  }

  if (sushmaUser) {
    await supabase.from('trainer_assignments').upsert({
      trainer_id: sushmaUser.id,
      college_id: kitsId,
      course_name: 'Python Full Stack & AI',
      target_years: ['2nd Year', '3rd Year'],
      target_branches: ['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH']
    }, { onConflict: 'trainer_id,college_id' });
  }

  console.log('=== CLEANUP FINISHED SUCCESSFULLY ===');
}

cleanupSuperAdminData();
