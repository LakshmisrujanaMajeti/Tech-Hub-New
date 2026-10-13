import 'dotenv/config';

async function run() {
  try {
    const loginRes = await fetch('http://localhost:5000/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'admin@cognitoinsights.ai', password: 'Admin@123' })
    });
    const loginData = await loginRes.json();
    console.log('Login success:', loginData.success, 'Role:', loginData.user?.role);
    const token = loginData.token;

    const colRes = await fetch('http://localhost:5000/api/colleges/registered', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const colData = await colRes.json();
    console.log('Registered Colleges count:', colData.colleges?.length);
    console.log('Colleges summary:', colData.colleges?.map((c: any) => ({
      id: c.id,
      name: c.short_name,
      student_count: c.student_count,
      active_hub: c.is_registered_hub
    })));

    const overRes = await fetch('http://localhost:5000/api/analytics/overview', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const overData = await overRes.json();
    console.log('Analytics Overview metrics:', overData.metrics);
    console.log('College Comparison in Overview:', overData.collegeComparison?.map((c: any) => ({
      id: c.id,
      name: c.short_name,
      student_count: c.student_count
    })));

    const studRes = await fetch('http://localhost:5000/api/students', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const studData = await studRes.json();
    console.log('Students API count:', studData.total, 'Array length:', studData.students?.length, 'Present:', studData.presentCount, 'Absent:', studData.absentCount, 'Rate:', studData.attendanceRate);
    if (studData.students && studData.students.length > 0) {
      console.log('First student sample:', studData.students[0].full_name, studData.students[0].roll_number, studData.students[0].college_name);
    }
  } catch (err) {
    console.error('Error:', err);
  }
}
run();
