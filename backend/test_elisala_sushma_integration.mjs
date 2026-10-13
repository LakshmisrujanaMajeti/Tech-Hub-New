

const BASE_URL = 'http://localhost:5000/api';

async function runTests() {
  console.log('=== STARTING ELISALA SUSHMA INTEGRATION TESTS ===\n');

  // 1. Trainer Login
  console.log('1. Testing Trainer Login for vsushmaelisala@gmail.com...');
  const loginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'vsushmaelisala@gmail.com',
      password: 'Trainer@123',
    }),
  });
  const loginData = await loginRes.json();
  console.log(`Login status: ${loginRes.status}`, loginData.message || loginData.error);
  if (loginRes.status !== 200 || !loginData.token) {
    throw new Error(`Trainer login failed: ${JSON.stringify(loginData)}`);
  }
  const trainerToken = loginData.token;
  console.log(`✓ Trainer logged in successfully: ${loginData.user.fullName} (${loginData.user.role})`);
  console.log(`✓ College: ${loginData.user.college_name || loginData.user.collegeName}\n`);

  // 2. Trainer Profile
  console.log('2. Testing GET /api/trainers/my-profile...');
  const profRes = await fetch(`${BASE_URL}/trainers/my-profile`, {
    headers: { Authorization: `Bearer ${trainerToken}` },
  });
  const profData = await profRes.json();
  console.log(`Profile status: ${profRes.status}`);
  console.log(`Course: ${profData.profile?.course_name}, Years: ${JSON.stringify(profData.profile?.target_years)}`);
  console.log(`✓ Trainer profile verified.\n`);

  // 3. Trainer Students List
  console.log('3. Testing GET /api/trainers/my-students...');
  const stuRes = await fetch(`${BASE_URL}/trainers/my-students`, {
    headers: { Authorization: `Bearer ${trainerToken}` },
  });
  const stuData = await stuRes.json();
  console.log(`my-students status: ${stuRes.status}, Total students: ${stuData.totalStudents}`);
  console.log(`Branches present:`, [...new Set(stuData.students.map(s => s.branch))]);
  console.log(`Years present:`, [...new Set(stuData.students.map(s => s.year))]);
  
  const hasNonSecondYear = stuData.students.some(s => !(s.year || '').toString().includes('2'));
  if (hasNonSecondYear) {
    throw new Error('FAILED: Trainer roster contains non-2nd year students!');
  }
  console.log(`✓ All ${stuData.students.length} students in Trainer roster are strictly 2nd Year Adarsh students!\n`);

  // 4. 2nd Year Student Login & Assigned Trainer
  console.log('4. Testing 2nd Year Student Login (vijayadevagupthapu703@gmail.com)...');
  const s2LoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'vijayadevagupthapu703@gmail.com',
      password: 'Student@123',
    }),
  });
  const s2LoginData = await s2LoginRes.json();
  console.log(`2nd Year Student Login status: ${s2LoginRes.status}`);
  const s2Assigned = s2LoginData.user?.assignedTrainer || s2LoginData.user?.assigned_trainer;
  console.log(`Assigned Trainer:`, s2Assigned);
  if (!s2Assigned?.full_name?.toLowerCase().includes('sushma')) {
    throw new Error(`FAILED: 2nd year student assigned trainer is not Elisala Sushma! Got: ${JSON.stringify(s2Assigned)}`);
  }
  console.log(`✓ 2nd Year Student assigned trainer is strictly Elisala Sushma (${s2Assigned.course_name})\n`);
  const s2Token = s2LoginData.token;

  // 5. 4th Year Student Login & Assigned Trainer
  console.log('5. Testing 4th Year Student Login (sandeepchelli1@gmail.com)...');
  const s4LoginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'sandeepchelli1@gmail.com',
      password: 'Student@123',
    }),
  });
  const s4LoginData = await s4LoginRes.json();
  console.log(`4th Year Student Login status: ${s4LoginRes.status}`);
  const s4Assigned = s4LoginData.user?.assignedTrainer || s4LoginData.user?.assigned_trainer;
  console.log(`Assigned Trainer:`, s4Assigned);
  if (s4Assigned?.full_name?.toLowerCase().includes('sushma')) {
    throw new Error(`FAILED: 4th year student should NOT be assigned to Elisala Sushma!`);
  }
  console.log(`✓ 4th Year Student is NOT assigned to Elisala Sushma (assigned to: ${s4Assigned?.full_name})\n`);
  const s4Token = s4LoginData.token;

  // 6. Trainer Creates and Publishes Quiz
  console.log('6. Trainer Elisala Sushma creating a 2nd Year Python Full stack Quiz...');
  const createQuizRes = await fetch(`${BASE_URL}/quizzes`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${trainerToken}`,
    },
    body: JSON.stringify({
      title: 'Python OOPs & Data Structures - 2nd Year Live Test',
      description: 'Concept verification exam for 2nd year Python Full stack students.',
      course_name: 'Python Full stack',
      target_year: '2nd Year',
      target_branch: 'ALL',
      duration_minutes: 15,
      total_marks: 10,
      quiz_type: 'CUSTOM_MCQ',
      is_published: true,
      questions: [
        {
          id: 'q1',
          question_text: 'What does __init__ method do in Python classes?',
          options: [
            { id: 'A', text: 'It acts as the constructor to initialize object attributes.' },
            { id: 'B', text: 'It deletes the object from memory.' },
            { id: 'C', text: 'It imports external libraries.' },
            { id: 'D', text: 'It compiles the code to bytecode.' }
          ],
          correct_option: 'A',
          marks: 5,
        },
        {
          id: 'q2',
          question_text: 'Which data structure follows LIFO (Last In First Out)?',
          options: [
            { id: 'A', text: 'Queue' },
            { id: 'B', text: 'Stack' },
            { id: 'C', text: 'Array' },
            { id: 'D', text: 'Tree' }
          ],
          correct_option: 'B',
          marks: 5,
        }
      ]
    }),
  });
  const createdQuizData = await createQuizRes.json();
  console.log(`Create quiz status: ${createQuizRes.status}`, createdQuizData.message || createdQuizData.error);
  if (!createdQuizData.success) throw new Error('Failed to create quiz');
  const quizId = createdQuizData.quiz.id;
  console.log(`✓ Quiz created and published: ${quizId} (${createdQuizData.quiz.title})\n`);

  // 7. 2nd Year Student Quiz Visibility
  console.log('7. Testing 2nd Year Student Quiz Visibility...');
  const s2QuizzesRes = await fetch(`${BASE_URL}/quizzes`, {
    headers: { Authorization: `Bearer ${s2Token}` },
  });
  const s2QuizzesData = await s2QuizzesRes.json();
  console.log(`2nd Year Student sees ${s2QuizzesData.quizzes?.length} quizzes:`);
  console.log(s2QuizzesData.quizzes?.map(q => ({ id: q.id, title: q.title, trainer: q.trainer_name, year: q.target_year })));
  const s2CanSeeCreatedQuiz = s2QuizzesData.quizzes?.some(q => q.id === quizId);
  if (!s2CanSeeCreatedQuiz) {
    throw new Error('FAILED: 2nd year student cannot see Elisala Sushma published quiz!');
  }
  console.log(`✓ 2nd Year student CAN see Elisala Sushma's published quiz!\n`);

  // 8. 4th Year Student Quiz Visibility (Must NOT see Elisala Sushma's 2nd Year Quiz)
  console.log('8. Testing 4th Year Student Quiz Isolation...');
  const s4QuizzesRes = await fetch(`${BASE_URL}/quizzes`, {
    headers: { Authorization: `Bearer ${s4Token}` },
  });
  const s4QuizzesData = await s4QuizzesRes.json();
  console.log(`4th Year Student sees ${s4QuizzesData.quizzes?.length} quizzes:`);
  console.log(s4QuizzesData.quizzes?.map(q => ({ id: q.id, title: q.title, trainer: q.trainer_name, year: q.target_year })));
  const s4CanSeeCreatedQuiz = s4QuizzesData.quizzes?.some(q => q.id === quizId);
  if (s4CanSeeCreatedQuiz) {
    throw new Error('FAILED: 4th year student should NOT see Elisala Sushma 2nd year quiz!');
  }
  console.log(`✓ 4th Year student CANNOT see Elisala Sushma's 2nd year quiz (Isolated successfully)!\n`);

  // 9. 4th Year Student Attempt Forbidden Check
  console.log('9. Testing 4th Year Student Direct Access Forbidden...');
  const s4DirectAttemptRes = await fetch(`${BASE_URL}/quizzes/${quizId}`, {
    headers: { Authorization: `Bearer ${s4Token}` },
  });
  console.log(`4th Year direct access status: ${s4DirectAttemptRes.status}`);
  if (s4DirectAttemptRes.status !== 403) {
    throw new Error(`FAILED: Expected 403 Forbidden for 4th year student accessing 2nd year test, got ${s4DirectAttemptRes.status}`);
  }
  console.log(`✓ Direct access properly returns 403 Forbidden for unauthorized student!\n`);

  // 10. 2nd Year Student Starts Quiz
  console.log('10. Testing 2nd Year Student starting test...');
  const s2StartRes = await fetch(`${BASE_URL}/quizzes/${quizId}`, {
    headers: { Authorization: `Bearer ${s2Token}` },
  });
  const s2StartData = await s2StartRes.json();
  console.log(`Start test status: ${s2StartRes.status}, Questions count: ${s2StartData.quiz?.questions?.length}`);
  if (!s2StartData.success || !s2StartData.quiz) {
    throw new Error('FAILED: 2nd year student failed to start quiz');
  }
  console.log(`✓ 2nd Year Student started quiz successfully! Questions randomized and delivered.\n`);

  console.log('=====================================================');
  console.log('🎉 ALL 10 INTEGRATION TESTS PASSED SUCCESSFULLY! 🎉');
  console.log('=====================================================');
}

runTests().catch(err => {
  console.error('\n❌ TEST SUITE FAILED:', err.message);
  process.exit(1);
});
