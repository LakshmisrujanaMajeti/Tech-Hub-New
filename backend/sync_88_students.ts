import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { supabase } from './src/db/supabase.js';

async function sync88() {
  const { data: adarshCollege } = await supabase.from('colleges').select('id').eq('college_code', 'ADARSH').single();
  const adarshId = adarshCollege?.id || 'ce3937d8-db9a-4002-8128-bf5a68bec78b';

  // Check current students
  const { data: currentStudents, count } = await supabase.from('students').select('id, roll_number', { count: 'exact' }).eq('college_id', adarshId);
  console.log('Current Adarsh students count:', count);

  const existingRolls = new Set(currentStudents?.map(s => s.roll_number) || []);

  const additionalStudents = [
    {
      rollNumber: '24HN1A0501',
      fullName: 'G. Sai Krishna',
      email: 'saikrishna.adarsh@gmail.com',
      mobile: '+91 94402 77001',
      branch: 'CSE',
      year: '3rd Year',
      section: 'A',
      gender: 'Male',
      dob: '2005-06-15',
      aadharId: '638968015291',
      address: 'Chebrolu, Kakinada District',
    },
    {
      rollNumber: '24HN1A0502',
      fullName: 'P. Harika',
      email: 'harika.adarsh@gmail.com',
      mobile: '+91 94402 77002',
      branch: 'CSE',
      year: '3rd Year',
      section: 'A',
      gender: 'Female',
      dob: '2005-08-20',
      aadharId: '638968015292',
      address: 'Gollaprolu, Kakinada District',
    },
    {
      rollNumber: '24HN1A0401',
      fullName: 'K. Rajesh',
      email: 'rajesh.adarsh@gmail.com',
      mobile: '+91 94402 77003',
      branch: 'ECE',
      year: '3rd Year',
      section: 'A',
      gender: 'Male',
      dob: '2005-03-10',
      aadharId: '638968015293',
      address: 'Pithapuram, Kakinada District',
    },
    {
      rollNumber: '23HN1A0501',
      fullName: 'T. Ramya',
      email: 'ramya.adarsh@gmail.com',
      mobile: '+91 94402 77004',
      branch: 'CSE',
      year: '4th Year',
      section: 'A',
      gender: 'Female',
      dob: '2004-11-25',
      aadharId: '638968015294',
      address: 'Kakinada City, AP',
    },
  ];

  const defaultPasswordHash = await bcrypt.hash('Student@2025', 10);

  for (const st of additionalStudents) {
    if (existingRolls.has(st.rollNumber)) {
      console.log(`Student ${st.rollNumber} already exists.`);
      continue;
    }

    // Check user by email
    const { data: existU } = await supabase.from('users').select('id').eq('email', st.email).limit(1);
    let userId = existU?.[0]?.id;

    if (!userId) {
      const { data: newU, error: uErr } = await supabase.from('users').insert({
        email: st.email,
        password_hash: defaultPasswordHash,
        role: 'STUDENT',
        full_name: st.fullName,
        mobile: st.mobile,
        college_id: adarshId,
        status: 'ACTIVE',
      }).select().single();

      if (uErr) {
        console.error(`Failed to insert user for ${st.email}:`, uErr.message);
        continue;
      }
      userId = newU.id;
    }

    const { error: sErr } = await supabase.from('students').insert({
      user_id: userId,
      college_id: adarshId,
      roll_number: st.rollNumber,
      branch: st.branch,
      year: st.year,
      section: st.section,
      gender: st.gender,
      date_of_birth: st.dob,
      aadhar_id: st.aadharId,
      address: st.address,
    });

    if (sErr) {
      console.error(`Failed to insert student ${st.rollNumber}:`, sErr.message);
    } else {
      console.log(`Successfully added student ${st.rollNumber} (${st.fullName})`);
    }
  }

  // Verify total count
  const { count: finalCount } = await supabase.from('students').select('*', { count: 'exact', head: true });
  console.log('Final verified students count in database:', finalCount);

  process.exit(0);
}

sync88().catch(e => {
  console.error(e);
  process.exit(1);
});
