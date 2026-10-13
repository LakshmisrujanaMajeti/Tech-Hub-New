import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function inspectSubs() {
  const { data: subRows } = await supabase
    .from('materials')
    .select('*')
    .eq('file_type', 'QUIZ_SUBMISSION');

  console.log(`Found ${subRows?.length} submissions in Supabase:`);
  for (const r of (subRows || [])) {
    console.log('\n--- Row ID:', r.id, 'Title:', r.title);
    console.log('Description:', r.description);
  }

  // Also check quizzes
  const { data: qRows } = await supabase
    .from('materials')
    .select('*')
    .eq('topic', 'QUIZ_SPEC');

  console.log(`\nFound ${qRows?.length} quizzes in Supabase:`);
  for (const r of (qRows || [])) {
    console.log('\n--- Quiz Row ID:', r.id, 'Title:', r.title);
    console.log('Description:', r.description);
  }

  process.exit(0);
}

inspectSubs().catch(console.error);
