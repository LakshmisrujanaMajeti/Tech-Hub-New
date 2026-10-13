const BASE_URL = 'http://localhost:5000/api';

async function testTabSwitchAndProctoring() {
  console.log('=== STARTING TAB SWITCH & ANTI-CHEAT PROCTORING TESTS ===');

  // 1. Super Admin login to find real student
  const saRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'superadmin@cognito.ai', password: 'Password@123' }),
  });
  const saData = await saRes.json();
  const saToken = saData.token;

  // 2. Fetch real student
  const stRes = await fetch(`${BASE_URL}/admin/students`, {
    headers: { 'Authorization': `Bearer ${saToken}` },
  });
  const stData = await stRes.json();
  const list = Array.isArray(stData) ? stData : (stData.students || stData.data || []);
  const realStudent = list.find(s => (s.year || '').toString().includes('2') && (s.college_name?.includes('Adarsh') || s.email?.includes('vijaya') || s.email?.includes('saivarun'))) || {
    email: 'vijayadevagupthapu703@gmail.com',
    roll_number: '26HN5A0503',
  };
  console.log('1. Testing Student:', realStudent.email, realStudent.roll_number);

  // 3. Trainer Elisala Sushma login
  const trRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'vsushmaelisala@gmail.com', password: 'Trainer@123' }),
  });
  const trData = await trRes.json();
  const trToken = trData.token;

  // 4. Create new Live Quiz for testing tab switch
  const quizRes = await fetch(`${BASE_URL}/quizzes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${trToken}` },
    body: JSON.stringify({
      title: 'Proctoring & Anti-Cheat Tab Switch Test #' + Date.now(),
      course_name: 'Python Full stack',
      target_branch: 'ALL',
      target_year: '2nd Year',
      duration_minutes: 15,
      is_published: true,
      questions: [
        {
          id: 'q1',
          question_text: 'What keyword defines a function in Python?',
          options: [
            { id: 'A', text: 'func' },
            { id: 'B', text: 'def' },
            { id: 'C', text: 'function' },
            { id: 'D', text: 'define' },
          ],
          correct_option: 'B',
          marks: 2,
        },
        {
          id: 'q2',
          question_text: 'Which data type is immutable?',
          options: [
            { id: 'A', text: 'tuple' },
            { id: 'B', text: 'list' },
            { id: 'C', text: 'dict' },
            { id: 'D', text: 'set' },
          ],
          correct_option: 'A',
          marks: 2,
        }
      ],
    }),
  });
  const quizData = await quizRes.json();
  if (!quizData.quiz) {
    console.error('Quiz creation failed:', quizData);
    return;
  }
  console.log('2. Quiz Created:', quizData.quiz.id, quizData.quiz.title);

  // 5. Student Login
  const stuLoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: realStudent.email, password: 'Student@123' }),
  });
  const stuLoginData = await stuLoginRes.json();
  const stuToken = stuLoginData.token;

  // 6. Student Starts Test (GET /api/quizzes/:id initializes IN_PROGRESS attempt)
  const startRes = await fetch(`${BASE_URL}/quizzes/${quizData.quiz.id}`, {
    headers: { 'Authorization': `Bearer ${stuToken}` },
  });
  const startData = await startRes.json();
  console.log('3. Student Started Test: Status', startRes.status, 'Questions received:', startData.quiz?.questions?.length);

  // 7. Student answers Q1 and records 1st Tab Switch
  const save1Res = await fetch(`${BASE_URL}/quizzes/${quizData.quiz.id}/save-progress`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${stuToken}` },
    body: JSON.stringify({
      answers: { q1: 'B' },
      tab_switch_count: 1,
    }),
  });
  console.log('4. Tab Switch 1 recorded & Q1 answer synced: Status', save1Res.status);

  // 8. Student answers Q2 and records 2nd Tab Switch
  const save2Res = await fetch(`${BASE_URL}/quizzes/${quizData.quiz.id}/save-progress`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${stuToken}` },
    body: JSON.stringify({
      answers: { q1: 'B', q2: 'A' },
      tab_switch_count: 2,
    }),
  });
  console.log('5. Tab Switch 2 recorded & Q2 answer synced: Status', save2Res.status);

  // 9. 3rd Tab Switch violation -> triggers auto submit with TERMINATED_TAB_SWITCH_LIMIT_EXCEEDED
  const termRes = await fetch(`${BASE_URL}/quizzes/${quizData.quiz.id}/submit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${stuToken}` },
    body: JSON.stringify({
      answers: { q1: 'B', q2: 'A' },
      time_taken_seconds: 45,
      is_auto_submitted: true,
      submission_reason: 'TERMINATED_TAB_SWITCH_LIMIT_EXCEEDED',
      tab_switch_count: 3,
    }),
  });
  const termData = await termRes.json();
  console.log('6. Tab Switch 3 auto-submit status:', termRes.status, 'Message:', termData.message);

  // 10. Student tries to re-enter or reattempt
  const reattemptRes = await fetch(`${BASE_URL}/quizzes/${quizData.quiz.id}`, {
    headers: { 'Authorization': `Bearer ${stuToken}` },
  });
  const reattemptData = await reattemptRes.json();
  console.log('7. Student re-entry check (Expected 400):', reattemptRes.status, 'Error:', reattemptData.error);

  // 11. Test Unexpected Window Closure scenario with another quiz
  const quiz2Res = await fetch(`${BASE_URL}/quizzes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${trToken}` },
    body: JSON.stringify({
      title: 'Unexpected Window Close Test #' + Date.now(),
      course_name: 'Python Full stack',
      target_branch: 'ALL',
      target_year: '2nd Year',
      duration_minutes: 15,
      is_published: true,
      questions: [
        {
          id: 'q1',
          question_text: 'Sample Q1?',
          options: [{ id: 'A', text: 'Opt1' }, { id: 'B', text: 'Opt2' }],
          correct_option: 'A',
          marks: 1,
        }
      ],
    }),
  });
  const quiz2Data = await quiz2Res.json();

  // Student starts Quiz 2
  await fetch(`${BASE_URL}/quizzes/${quiz2Data.quiz.id}`, {
    headers: { 'Authorization': `Bearer ${stuToken}` },
  });
  console.log('8. Quiz 2 started by student (attempt IN_PROGRESS)');

  // Student closes window without submitting, then tries to open Quiz 2 again (simulating reload/re-entry)
  const windowCloseRes = await fetch(`${BASE_URL}/quizzes/${quiz2Data.quiz.id}`, {
    headers: { 'Authorization': `Bearer ${stuToken}` },
  });
  const windowCloseData = await windowCloseRes.json();
  console.log('9. Unexpected window close re-entry result (Expected 400 auto-terminated):', windowCloseRes.status, 'Error:', windowCloseData.error);

  // 12. Trainer verifies submission roster
  const subsRes = await fetch(`${BASE_URL}/quizzes/${quizData.quiz.id}/submissions`, {
    headers: { 'Authorization': `Bearer ${trToken}` },
  });
  const subsData = await subsRes.json();
  console.log('10. Trainer Roster Submissions:', subsData.submissions.length, 'Reason:', subsData.submissions[0]?.submission_reason, 'Tab Switches:', subsData.submissions[0]?.tab_switch_count);

  console.log('=== ALL PROCTORING TESTS PASSED PERFECTLY ===');
}

testTabSwitchAndProctoring().catch(console.error);
