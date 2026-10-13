import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testFlow() {
  console.log('=== 1. Fetching all quizzes from Supabase ===');
  const { data: qRows, error: qErr } = await supabase
    .from('materials')
    .select('*')
    .like('file_type', 'QUIZ%');

  console.log(`Found ${qRows?.length} quiz items in Supabase.`);
  
  // Find the published quiz
  const quizzes = [];
  for (const row of (qRows || [])) {
    if (row.topic === 'QUIZ_SPEC') {
      try {
        const q = JSON.parse(row.description);
        quizzes.push({ rowId: row.id, ...q });
      } catch (_) {}
    }
  }

  console.log('Parsed Quizzes in Supabase:', quizzes.map(q => ({ id: q.id, title: q.title, is_published: q.is_published, qCount: q.questions?.length })));

  if (quizzes.length > 0) {
    const targetQuiz = quizzes[0];
    console.log(`\n=== 2. Simulating a student submission for quiz: ${targetQuiz.title} (${targetQuiz.id}) ===`);
    
    const submissionPayload = {
      quiz_id: targetQuiz.id,
      student_id: 'dbdcd659-370a-457f-a16d-7b8e0c410570',
      student_name: 'N. Sandhya Rani',
      roll_number: '24HN1A0101',
      branch: 'CIVIL',
      year: '2nd Year',
      answers: { 'q1': 'B' },
      score: 1,
      total_marks: targetQuiz.questions?.length || 1,
      percentage: 100,
      total_questions: targetQuiz.questions?.length || 1,
      correct_count: 1,
      incorrect_count: 0,
      unanswered_count: 0,
      time_taken_seconds: 45,
      is_auto_submitted: false,
      submission_reason: 'NORMAL',
      tab_switch_count: 0,
      submitted_at: new Date().toISOString(),
      review_breakdown: [
        {
          question_id: 'q1',
          question_text: 'Which keyword is used for a Conditional Statement?',
          student_answer: 'B',
          correct_option: 'B',
          is_correct: true,
          marks_earned: 1,
          total_marks: 1,
          explanation: 'if is used in Python.'
        }
      ]
    };

    const { data: subInsert, error: subErr } = await supabase.from('materials').insert({
      college_id: targetQuiz.college_id || 'ce3937d8-db9a-4002-8128-bf5a68bec78b',
      subject: 'Quiz Submission',
      topic: 'QUIZ_SUBMISSION',
      title: `Submission - ${targetQuiz.id} - ${submissionPayload.roll_number} - ${submissionPayload.student_id}`,
      description: JSON.stringify(submissionPayload),
      file_url: `https://cognito-techhub/submissions/${targetQuiz.id}/${submissionPayload.student_id}`,
      file_type: 'QUIZ_SUBMISSION',
      uploaded_by: submissionPayload.student_id,
    }).select();

    console.log('Submission inserted to Supabase:', { id: subInsert?.[0]?.id, error: subErr?.message });

    console.log('\n=== 3. Querying Submissions for Trainer ===');
    const { data: subRows } = await supabase
      .from('materials')
      .select('*')
      .eq('file_type', 'QUIZ_SUBMISSION');

    const subsForQuiz = [];
    for (const r of (subRows || [])) {
      try {
        const parsed = JSON.parse(r.description);
        if (parsed.quiz_id === targetQuiz.id) {
          subsForQuiz.push(parsed);
        }
      } catch (_) {}
    }

    console.log(`Found ${subsForQuiz.length} submission(s) for quiz ${targetQuiz.id}:`, subsForQuiz.map(s => ({
      name: s.student_name,
      roll: s.roll_number,
      score: `${s.score}/${s.total_marks}`,
      time: `${s.time_taken_seconds}s`,
      submitted_at: s.submitted_at
    })));
  }

  process.exit(0);
}

testFlow().catch(console.error);
