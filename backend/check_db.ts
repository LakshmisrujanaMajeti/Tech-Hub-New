import { supabase } from './src/db/supabase.ts';

async function check() {
  try {
    console.log('--- Supabase Cloud Check ---');
    const { data: sbUsers, error: uErr } = await supabase.from('users').select('*');
    if (uErr) console.error('uErr:', uErr);
    console.log('Supabase users count:', sbUsers?.length);
    const sbVarun = sbUsers?.filter((u: any) => 
      (u.full_name || '').toLowerCase().includes('varun') || 
      (u.email || '').toLowerCase().includes('varun') || 
      (u.full_name || '').toLowerCase().includes('sai')
    );
    console.log('Supabase users matching Sai/Varun:', sbVarun);

    const { data: sbStudents, error: sErr } = await supabase.from('students').select('*');
    if (sErr) console.error('sErr:', sErr);
    console.log('Supabase students count:', sbStudents?.length);
    const varunStudent = sbStudents?.filter((s: any) => 
      sbVarun?.some((u: any) => u.id === s.user_id || u.id === s.id)
    );
    console.log('Matching students:', varunStudent);

    const { data: sbAtt, error: aErr } = await supabase.from('attendance_records').select('*');
    if (aErr) console.error('aErr:', aErr);
    console.log('Supabase all attendance_records count:', sbAtt?.length);
    console.log('Supabase all attendance_records:', sbAtt);

    const { data: sbSess, error: seErr } = await supabase.from('sessions').select('*');
    if (seErr) console.error('seErr:', seErr);
    console.log('Supabase sessions count:', sbSess?.length);
    console.log('Supabase sessions:', sbSess);

    const { data: qrList } = await supabase.from('attendance_qr').select('*');
    console.log('attendance_qr count:', qrList?.length);
    console.log('attendance_qr:', qrList);

    const { data: trainerAtt } = await supabase.from('trainer_attendance').select('*');
    console.log('trainer_attendance:', trainerAtt);

  } catch (err) {
    console.error('Error:', err);
  } finally {
    process.exit(0);
  }
}

check();
