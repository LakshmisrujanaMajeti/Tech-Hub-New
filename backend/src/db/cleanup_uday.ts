import { supabase } from './supabase.js';

async function cleanup() {
  await supabase.from('users').delete().in('email', ['uday.techhub@cognitoinsights.ai', 'uday@cognitoinsights.ai']);
  await supabase.from('users').update({
    full_name: 'Daiva Rao',
  }).eq('id', '0ed2be5c-fce6-4e4f-83eb-96be2b162746');
  console.log('Cleanup finished!');
  process.exit(0);
}

cleanup();
