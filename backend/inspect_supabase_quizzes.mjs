import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const sb = createClient(supabaseUrl, supabaseServiceKey);

async function inspectQuizzes() {
  const { data: rows, error } = await sb
    .from('materials')
    .select('*')
    .like('file_type', 'QUIZ%')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching materials:', error);
    return;
  }

  console.log(`Total quiz records in Supabase materials table: ${rows?.length}`);
  rows?.forEach((r, idx) => {
    let parsed = null;
    try {
      parsed = JSON.parse(r.description);
    } catch (_) {}

    console.log(`\n--- Quiz Record #${idx + 1} (DB ID: ${r.id}) ---`);
    console.log('Title in row:', r.title);
    console.log('Subject in row:', r.subject);
    console.log('File type:', r.file_type);
    console.log('Created at:', r.created_at);
    if (parsed) {
      console.log('Parsed Quiz ID:', parsed.id);
      console.log('Parsed Title:', parsed.title);
      console.log('Course Name:', parsed.course_name);
      console.log('Target Year:', parsed.target_year);
      console.log('Target Branch:', parsed.target_branch);
      console.log('Trainer Name:', parsed.trainer_name);
      console.log('Trainer Email:', parsed.trainer_email);
      console.log('Trainer ID:', parsed.trainer_id);
      console.log('Is Published:', parsed.is_published, '| Status:', parsed.status);
      console.log('Questions count:', parsed.questions?.length);
    } else {
      console.log('Description (not JSON):', r.description);
    }
  });
}

inspectQuizzes().catch(console.error);
