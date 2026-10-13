import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://awjohmjbortcvnugxbiv.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3am9obWpib3J0Y3ZudWd4Yml2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4OTgwNTQ5NywiZXhwIjoyMTA1MzgxNDk3fQ.P6jymcYjqJO5rAgZlULMbW3lva3h2obsVIma_8lf9fQ';

const sb = createClient(supabaseUrl, supabaseServiceKey);

async function testStudentQuizzes() {
  const { data: materials } = await sb.from('materials').select('*').like('file_type', 'QUIZ%').order('created_at', { ascending: false });

  const allQuizzes = [];
  const allSubmissions = [];

  materials.forEach(r => {
    try {
      const parsed = JSON.parse(r.description);
      if (r.file_type === 'QUIZ_SUBMISSION' || r.topic === 'QUIZ_SUBMISSION') {
        allSubmissions.push(parsed);
      } else {
        allQuizzes.push(parsed);
      }
    } catch (_) {}
  });

  function evaluateQuizzesForStudent(student) {
    const userYear = (student.year || '').toLowerCase();
    const userRollNo = (student.rollNumber || '').toLowerCase();
    const userBranch = (student.branch || '').toLowerCase();
    const assignedTrainerEmail = (student.assignedTrainer?.email || '').toLowerCase();
    const assignedTrainerName = (student.assignedTrainer?.full_name || '').toLowerCase();

    const is2ndYearStudent = userYear.includes('2') || userYear.includes('2nd') || userRollNo.startsWith('24hn') || userRollNo.startsWith('25hn5');
    const is3rdYearStudent = (userYear.includes('3') || userYear.includes('3rd') || userRollNo.startsWith('23hn') || userRollNo.startsWith('24hn5')) && !is2ndYearStudent;
    const isAssignedToSushma = assignedTrainerEmail.includes('sushma') || assignedTrainerName.includes('sushma') || is2ndYearStudent;
    const isAssignedToDaiva = assignedTrainerEmail.includes('daiva') || assignedTrainerEmail.includes('pathivada') || is3rdYearStudent;

    const studentQuizzes = [];

    for (const q of allQuizzes) {
      const isPub = q.is_published === true || q.status === 'PUBLISHED';
      if (!isPub) continue;

      const tEmail = (q.trainer_email || '').toLowerCase();
      const tName = (q.trainer_name || '').toLowerCase();
      const cName = (q.course_name || '').toLowerCase();

      finalIsSushmaQuiz:
      var isSushmaQuiz = tEmail.includes('sushma') || tName.includes('sushma') || cName.includes('python');
      var isDaivaQuiz = tEmail.includes('daiva') || tEmail.includes('pathivada') || tName.includes('daiva') || tName.includes('pathivada') || cName.includes('java');

      if (isSushmaQuiz) {
        if (is3rdYearStudent && !isAssignedToSushma) continue;
        if (isAssignedToDaiva && !is2ndYearStudent && !isAssignedToSushma) continue;
      } else if (isDaivaQuiz) {
        if (is2ndYearStudent && !isAssignedToDaiva) continue;
        if (isAssignedToSushma && !is3rdYearStudent && !isAssignedToDaiva) continue;
      }

      const targetYear = (q.target_year || 'ALL').toString().toLowerCase().trim();
      if (targetYear !== 'all' && !targetYear.includes('all')) {
        const qYearNum = targetYear.match(/\d+/)?.[0];
        const sYearNum = userYear.match(/\d+/)?.[0] || (is2ndYearStudent ? '2' : '3');
        if (qYearNum && sYearNum && qYearNum !== sYearNum) continue;
      }

      const targetBranch = (q.target_branch || 'ALL').toString().toUpperCase().trim();
      if (targetBranch !== 'ALL' && targetBranch.length > 0 && targetBranch !== 'ALL BRANCHES') {
        const sBranch = userBranch.toUpperCase().replace(/[^A-Z0-9]/g, '');
        const tBranch = targetBranch.replace(/[^A-Z0-9]/g, '');
        if (sBranch && tBranch && sBranch !== tBranch && !tBranch.includes(sBranch) && !sBranch.includes(tBranch)) continue;
      }

      const qId = q.id || '';
      const studentSub = allSubmissions.find(sub => sub.quiz_id === qId && (sub.roll_number?.toLowerCase() === userRollNo));

      studentQuizzes.push({
        ...q,
        has_submitted: !!studentSub,
        submission: studentSub || null
      });
    }

    return studentQuizzes;
  }

  // 1. Sushma Student
  const sushmaStudent = {
    role: 'STUDENT',
    year: '2nd Year',
    branch: 'Mechanical',
    rollNumber: '24HN1A0301',
    assignedTrainer: {
      full_name: 'Sushma Elisala',
      email: 'vsushmaelisala@gmail.com',
      course_name: 'Python Full stack'
    }
  };
  const sList = evaluateQuizzesForStudent(sushmaStudent);
  console.log(`\n=== 2nd Year Student (Sushma Elisala Track: 24HN1A0301 - Mechanical) ===`);
  console.log(`Visible Quizzes Count: ${sList.length}`);
  sList.forEach((q, i) => console.log(`  ${i+1}. [${q.status}] ${q.title} (${q.course_name}) - Submitted: ${q.has_submitted}`));

  // 2. Daiva Rao Student
  const daivaStudent = {
    role: 'STUDENT',
    year: '3rd Year',
    branch: 'CSE',
    rollNumber: '23HN1A0501',
    assignedTrainer: {
      full_name: 'Pathivada Daiva Rao',
      email: 'daivaraopathivada@gmail.com',
      course_name: 'Java full stack'
    }
  };
  const dList = evaluateQuizzesForStudent(daivaStudent);
  console.log(`\n=== 3rd Year Student (Daiva Rao Track: 23HN1A0501 - CSE) ===`);
  console.log(`Visible Quizzes Count: ${dList.length}`);
  dList.forEach((q, i) => console.log(`  ${i+1}. [${q.status}] ${q.title} (${q.course_name}) - Submitted: ${q.has_submitted}`));
}

testStudentQuizzes().catch(console.error);
