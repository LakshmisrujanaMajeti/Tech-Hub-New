import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testCloudQuiz() {
  console.log('--- Testing Supabase Cloud Quiz Storage ---');
  
  const quizObj = {
    id: 'quiz-cloud-001',
    trainer_id: '48632025-1678-4014-925a-86391063614b',
    trainer_name: 'Elisala Sushma',
    trainer_email: 'vsushmaelisala@gmail.com',
    college_id: 'ce3937d8-db9a-4002-8128-bf5a68bec78b',
    title: 'Python Full stack Daily Assessment - Live',
    description: '15 Mins Concept Quiz',
    course_name: 'Python Full stack',
    target_year: '2nd Year',
    target_branch: 'ALL',
    duration_minutes: 15,
    quiz_type: 'CUSTOM_MCQ',
    is_published: true,
    status: 'PUBLISHED',
    questions: [
      {
        id: 'q1',
        question_text: 'Which keyword is used for a Conditional Statement?',
        options: [
          { id: 'A', text: 'when' },
          { id: 'B', text: 'if' },
          { id: 'C', text: 'switch' },
          { id: 'D', text: 'loop' }
        ],
        correct_option: 'B',
        marks: 2,
        explanation: 'if keyword is used in Python for conditional statements.'
      }
    ]
  };

  // Insert quiz as a cloud material entry
  const { data: insertRes, error: insErr } = await supabase.from('materials').insert({
    college_id: quizObj.college_id,
    subject: quizObj.course_name,
    topic: 'QUIZ_SPEC',
    title: quizObj.title,
    description: JSON.stringify(quizObj),
    file_url: 'https://cognito-techhub/quiz/' + quizObj.id,
    file_type: 'QUIZ_MCQ',
    uploaded_by: quizObj.trainer_id,
  }).select();

  console.log('Insert Result:', { insertRes, insErr });

  // Query quizzes from materials
  const { data: qRows, error: qErr } = await supabase
    .from('materials')
    .select('*')
    .like('file_type', 'QUIZ%');

  console.log(`Fetched ${qRows?.length} quizzes from Supabase cloud:`, qRows?.map(r => r.title));

  // Parse retrieved quiz
  if (qRows && qRows.length > 0) {
    const parsed = JSON.parse(qRows[0].description);
    console.log('Parsed Cloud Quiz:', {
      id: parsed.id,
      title: parsed.title,
      trainer: parsed.trainer_name,
      questionsCount: parsed.questions?.length,
      firstQ: parsed.questions?.[0]?.question_text
    });
  }

  process.exit(0);
}

testCloudQuiz().catch(console.error);
