import bcrypt from 'bcryptjs';
import { supabase } from './supabase.js';

async function checkSushma() {
  const { data: user, error } = await supabase
    .from('users')
    .select('*')
    .ilike('email', '%sushma%');

  console.log('Sushma records in Supabase:', user);

  if (user && user.length > 0) {
    for (const u of user) {
      const match = await bcrypt.compare('Trainer@123', u.password_hash);
      console.log(`User ${u.email} password match for 'Trainer@123':`, match);
      if (!match) {
        const newHash = await bcrypt.hash('Trainer@123', 10);
        await supabase.from('users').update({ password_hash: newHash }).eq('id', u.id);
        console.log(`Updated password_hash for ${u.email}`);
      }
    }
  } else {
    // Insert Sushma Madam
    const { data: kitsOrg } = await supabase.from('organizations').select('id').ilike('name', '%KITS%').single();
    const orgId = kitsOrg ? kitsOrg.id : '11111111-1111-1111-1111-111111111111';
    const hash = await bcrypt.hash('Trainer@123', 10);
    const { data: inserted, error: insErr } = await supabase.from('users').insert({
      email: 'sushma.python@cognitoinsights.ai',
      password_hash: hash,
      role: 'TRAINER',
      full_name: 'Sushma Madam (Python)',
      phone: '+91 98888 33333',
      organization_id: orgId,
      status: 'ACTIVE'
    }).select().single();
    console.log('Inserted Sushma Madam:', inserted, insErr);
  }
}

checkSushma();
