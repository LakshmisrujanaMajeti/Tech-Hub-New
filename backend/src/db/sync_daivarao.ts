import bcrypt from 'bcryptjs';
import { supabase } from './supabase.js';

async function syncDaivaRao() {
  console.log('Inspecting and updating Daiva Rao in Supabase...');
  const passwordHash = await bcrypt.hash('Trainer@123', 10);
  
  // 1. Fetch colleges in Supabase
  const { data: cols } = await supabase.from('colleges').select('id, college_name');
  console.log('Colleges in Supabase:', cols);
  const collegeId = cols && cols.length > 0 ? cols[0].id : null;

  // 2. Fetch existing trainer users
  const { data: trainers } = await supabase.from('users').select('*').eq('role', 'TRAINER');
  console.log('Current trainers:', trainers?.map(t => ({ id: t.id, email: t.email, name: t.full_name })));

  // 3. Update any user with uday or daiva in email/name to Daiva Rao
  const { data: updated1, error: err1 } = await supabase
    .from('users')
    .update({
      email: 'daivarao.techhub@cognitoinsights.ai',
      full_name: 'Daiva Rao',
      password_hash: passwordHash,
      mobile: '+91 98888 44444',
      status: 'ACTIVE',
      role: 'TRAINER',
      college_id: collegeId,
    })
    .or('email.ilike.%uday%,full_name.ilike.%uday%,email.ilike.%daiva%')
    .select();

  console.log('Updated existing trainer to Daiva Rao:', updated1, 'error:', err1);

  // If none was updated, insert new user for Daiva Rao
  if (!updated1 || updated1.length === 0) {
    const { data: inserted, error: insErr } = await supabase
      .from('users')
      .insert({
        email: 'daivarao.techhub@cognitoinsights.ai',
        full_name: 'Daiva Rao',
        password_hash: passwordHash,
        mobile: '+91 98888 44444',
        status: 'ACTIVE',
        role: 'TRAINER',
        college_id: collegeId,
      })
      .select();
    console.log('Inserted new Daiva Rao user:', inserted, 'error:', insErr);
  }

  // Also ensure daivarao@cognitoinsights.ai alias exists
  const { data: aliasUser } = await supabase.from('users').select('id').eq('email', 'daivarao@cognitoinsights.ai');
  if (!aliasUser || aliasUser.length === 0) {
    await supabase.from('users').insert({
      email: 'daivarao@cognitoinsights.ai',
      full_name: 'Daiva Rao',
      password_hash: passwordHash,
      mobile: '+91 98888 44444',
      status: 'ACTIVE',
      role: 'TRAINER',
      college_id: collegeId,
    });
  }

  // Update trainer_assignments
  const { data: daivaUser } = await supabase.from('users').select('id').eq('email', 'daivarao.techhub@cognitoinsights.ai').single();
  if (daivaUser) {
    console.log('Daiva Rao user ID:', daivaUser.id);
    const { data: existTa } = await supabase.from('trainer_assignments').select('id').eq('trainer_id', daivaUser.id);
    if (existTa && existTa.length > 0) {
      await supabase.from('trainer_assignments').update({
        course_name: 'Technical Skills & Python Foundations',
        target_years: ['1st Year', '4th Year'],
        target_branches: ['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH'],
        college_id: collegeId,
      }).eq('trainer_id', daivaUser.id);
    } else {
      await supabase.from('trainer_assignments').insert({
        trainer_id: daivaUser.id,
        course_name: 'Technical Skills & Python Foundations',
        target_years: ['1st Year', '4th Year'],
        target_branches: ['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH'],
        college_id: collegeId,
      });
    }
  }

  console.log('Daiva Rao Supabase setup completed successfully!');
  process.exit(0);
}

syncDaivaRao();
