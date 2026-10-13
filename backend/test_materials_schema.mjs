import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testMaterials() {
  const { data, error } = await supabase.from('materials').insert({
    college_id: 'ce3937d8-db9a-4002-8128-bf5a68bec78b',
    subject: 'Python Full stack',
    topic: 'Assessment',
    title: 'Quiz Probe',
    file_url: 'https://example.com',
    file_type: 'QUIZ',
  }).select();

  console.log('Result:', { data, error });
  if (data && data.length > 0) {
    console.log('Columns in materials:', Object.keys(data[0]));
    console.log('Row:', data[0]);
    await supabase.from('materials').delete().eq('id', data[0].id);
  }
}

testMaterials().catch(console.error);
