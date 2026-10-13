import { supabase } from './src/db/supabase.ts';

async function seedSupabase() {
  try {
    console.log('--- Seeding Supabase Cloud Sessions & Attendance ---');

    const collegeId = 'ce3937d8-db9a-4002-8128-bf5a68bec78b'; // Adarsh College
    const studentId = 'dbdcd659-370a-457f-a16d-7b8e0c410570'; // K. Sai Varun student record
    const userId = '23ad80ac-a00d-44a5-abc4-0c38e49d8b92'; // K. Sai Varun user id

    // 1. Ensure Batch exists in Supabase
    let batchId = 'a1b2c3d4-0001-4000-8000-000000000001';
    const { data: existingBatches } = await supabase.from('batches').select('*').eq('college_id', collegeId);
    if (existingBatches && existingBatches.length > 0) {
      batchId = existingBatches[0].id;
      console.log('Found existing batch:', batchId);
    } else {
      const { data: newBatch, error: bErr } = await supabase.from('batches').upsert({
        id: batchId,
        college_id: collegeId,
        name: 'CSE 2nd Year - Tech Hub Core',
        code: 'ADARSH-CSE-2',
        academic_year: '2026',
      }).select();
      console.log('Created batch:', newBatch, bErr);
    }

    // 2. Insert Yesterday's Session (2026-10-02)
    const yesterdaySessionId = 'c1a2b3d4-2026-1002-0000-000000000001';
    const { data: sess1, error: s1Err } = await supabase.from('sessions').upsert({
      id: yesterdaySessionId,
      college_id: collegeId,
      batch_id: batchId,
      title: 'Python OOP & Data Structures',
      description: 'Object Oriented Architecture, classes, and Pythonic design patterns.',
      session_date: '2026-10-02',
      start_time: '09:00:00',
      end_time: '16:00:00',
      status: 'COMPLETED',
    }).select();
    console.log('Yesterday session:', sess1, s1Err);

    // 3. Insert Today's Session (2026-10-03)
    const todaySessionId = 'c1a2b3d4-2026-1003-0000-000000000002';
    const { data: sess2, error: s2Err } = await supabase.from('sessions').upsert({
      id: todaySessionId,
      college_id: collegeId,
      batch_id: batchId,
      title: 'Python Web Development & REST APIs',
      description: 'Hands-on Full Stack Python development and cloud API integrations.',
      session_date: '2026-10-03',
      start_time: '09:00:00',
      end_time: '16:00:00',
      status: 'IN_PROGRESS',
    }).select();
    console.log('Today session:', sess2, s2Err);

    // 4. Insert Attendance Record for K. Sai Varun for Yesterday (2026-10-02)
    const attRecordId = 'a1b2c3d4-2026-1002-8000-000000000001';
    const { data: attRes, error: attErr } = await supabase.from('attendance_records').upsert({
      id: attRecordId,
      session_id: yesterdaySessionId,
      student_id: studentId,
      college_id: collegeId,
      status: 'PRESENT',
      device_info: 'Cognito Mobile App (QR Scan)',
      method: 'QR_SCAN',
      marked_at: '2026-10-02T10:15:22.000Z',
    }).select();
    console.log('Attendance record inserted:', attRes, attErr);

    // Also check if student record exists and update
    const { data: studentCheck } = await supabase.from('students').select('*').eq('id', studentId);
    console.log('Student check:', studentCheck);

    // 5. Query verification
    const { data: allAtt } = await supabase.from('attendance_records').select('*');
    console.log('Verification - Total attendance in Supabase:', allAtt?.length, allAtt);

    const { data: allSess } = await supabase.from('sessions').select('*');
    console.log('Verification - Total sessions in Supabase:', allSess?.length, allSess);

  } catch (err) {
    console.error('Seed error:', err);
  } finally {
    process.exit(0);
  }
}

seedSupabase();
