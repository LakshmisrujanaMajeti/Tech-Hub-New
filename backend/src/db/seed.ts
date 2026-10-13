import bcrypt from 'bcryptjs';
import { pool } from './pool.js';
import { supabase } from './supabase.js';

async function seedDB() {
  console.log('Seeding Cognito Tech Hub database...');
  try {
    const passwordHash = await bcrypt.hash('Cognito@123', 10);

    // 1. Colleges
    const kitsRes = await pool.query(`
      INSERT INTO colleges (college_code, college_name, short_name, address, district, state, logo_url, banner_url, primary_color, secondary_color, student_registration_enabled, status)
      VALUES (
        'KITS_DIVILI',
        'Kakinada Institute of Technology & Science',
        'KITS Divili',
        'Divili, Peddapuram Mandal, Kakinada District, Andhra Pradesh - 533433',
        'Kakinada',
        'Andhra Pradesh',
        '/uploads/kits_logo.png',
        '/uploads/PHOTO-2026-09-15-10-09-04.jpg',
        '#0057B8',
        '#003366',
        TRUE,
        'ACTIVE'
      )
      ON CONFLICT (college_code) DO UPDATE SET
        college_name = EXCLUDED.college_name,
        logo_url = EXCLUDED.logo_url,
        banner_url = EXCLUDED.banner_url,
        primary_color = EXCLUDED.primary_color
      RETURNING id;
    `);
    const kitsId = kitsRes.rows[0].id;

    const adarshRes = await pool.query(`
      INSERT INTO colleges (college_code, college_name, short_name, address, district, state, logo_url, banner_url, primary_color, secondary_color, student_registration_enabled, status)
      VALUES (
        'ADARSH',
        'Adarsh College of Engineering',
        'Adarsh Engineering College',
        'NH-16, Chebrolu, Gollaprolu Mandal, Kakinada District, Andhra Pradesh - 533449',
        'Kakinada',
        'Andhra Pradesh',
        '/uploads/adharsh_logo.png',
        '/uploads/PHOTO-2026-09-17-19-26-21.jpg',
        '#C2410C',
        '#7C2D12',
        TRUE,
        'ACTIVE'
      )
      ON CONFLICT (college_code) DO UPDATE SET
        college_name = EXCLUDED.college_name,
        logo_url = EXCLUDED.logo_url,
        banner_url = EXCLUDED.banner_url,
        primary_color = EXCLUDED.primary_color
      RETURNING id;
    `);
    const adarshId = adarshRes.rows[0].id;

    console.log(`Colleges seeded: KITS (${kitsId}), Adarsh (${adarshId})`);

    // 2. Users: Super Admin & Program Manager & Trainers
    await pool.query(`
      INSERT INTO users (email, password_hash, role, full_name, mobile, college_id, status)
      VALUES
      ('cognitoinsights2025@gmail.com', $1, 'SUPER_ADMIN', 'Cognito Super Admin', '+91 98765 43210', NULL, 'ACTIVE'),
      ('admin@cognitoinsights.ai', $1, 'SUPER_ADMIN', 'Cognito Super Admin', '+91 98765 43210', NULL, 'ACTIVE'),
      ('pm@cognitoinsights.ai', $1, 'PROGRAM_MANAGER', 'Cognito Program Manager', '+91 98765 43211', NULL, 'ACTIVE')
      ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash;
    `, [passwordHash]);

    // KITS Users including Tutor Sushma Madam (Python Trainer - 2nd & 3rd Year) and Tutor Daiva Rao (1st & 4th Year)
    await pool.query(`
      INSERT INTO users (email, password_hash, role, full_name, mobile, college_id, status)
      VALUES
      ('admin@kitsdivili.ac.in', $1, 'COLLEGE_ADMIN', 'Dr. K. Srinivas (KITS Principal)', '+91 94401 23456', $2, 'ACTIVE'),
      ('tpo@kitsdivili.ac.in', $1, 'TPO', 'Prof. R. Varma (KITS TPO)', '+91 94401 23457', $2, 'ACTIVE'),
      ('sushma.python@cognitoinsights.ai', $1, 'TRAINER', 'Sushma Madam (Python)', '+91 98888 33333', $2, 'ACTIVE'),
      ('daivarao.techhub@cognitoinsights.ai', $1, 'TRAINER', 'Daiva Rao', '+91 98888 44444', $2, 'ACTIVE'),
      ('daivarao@cognitoinsights.ai', $1, 'TRAINER', 'Daiva Rao', '+91 98888 44444', $2, 'ACTIVE'),
      ('trainer.python@cognitoinsights.ai', $1, 'TRAINER', 'Priya Sharma (Python Specialist)', '+91 98888 11111', $2, 'ACTIVE'),
      ('student.kits@gmail.com', $1, 'STUDENT', 'Rahul Varma', '+91 91234 56789', $2, 'ACTIVE'),
      ('student.1styear@gmail.com', $1, 'STUDENT', 'Ananya Sharma', '+91 91234 11111', $2, 'ACTIVE'),
      ('student.2ndyear@gmail.com', $1, 'STUDENT', 'Vikram Varma', '+91 91234 22222', $2, 'ACTIVE'),
      ('student.4thyear@gmail.com', $1, 'STUDENT', 'Karthik Raju', '+91 91234 44444', $2, 'ACTIVE')
      ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash, full_name = EXCLUDED.full_name;
    `, [passwordHash, kitsId]);

    // Adarsh Users
    await pool.query(`
      INSERT INTO users (email, password_hash, role, full_name, mobile, college_id, status)
      VALUES
      ('admin@adarsh.ac.in', $1, 'COLLEGE_ADMIN', 'Dr. M. Prasad (Adarsh Dean)', '+91 94402 34567', $2, 'ACTIVE'),
      ('tpo@adarsh.ac.in', $1, 'TPO', 'Prem (Adarsh TPO)', '+91 94402 34568', $2, 'ACTIVE')
      ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash, full_name = EXCLUDED.full_name;
    `, [passwordHash, adarshId]);

    console.log('Users seeded successfully across all roles.');

    // Find student & trainer IDs
    const rahulUser = await pool.query(`SELECT id FROM users WHERE email = 'student.kits@gmail.com'`);
    const student1st = await pool.query(`SELECT id FROM users WHERE email = 'student.1styear@gmail.com'`);
    const student2nd = await pool.query(`SELECT id FROM users WHERE email = 'student.2ndyear@gmail.com'`);
    const student4th = await pool.query(`SELECT id FROM users WHERE email = 'student.4thyear@gmail.com'`);
    const snehaUser = await pool.query(`SELECT id FROM users WHERE email = 'student.adarsh@gmail.com'`);
    
    const sushmaTrainer = await pool.query(`SELECT id FROM users WHERE email = 'sushma.python@cognitoinsights.ai'`);
    const daivaTrainer = await pool.query(`SELECT id FROM users WHERE email = 'daivarao.techhub@cognitoinsights.ai'`);
    const kitsTrainer = await pool.query(`SELECT id FROM users WHERE email = 'trainer.python@cognitoinsights.ai'`);
    const adarshTrainer = await pool.query(`SELECT id FROM users WHERE email = 'trainer.java@cognitoinsights.ai'`);

    // 3. Students Table
    const kitsStudentRes = await pool.query(`
      INSERT INTO students (user_id, college_id, roll_number, registration_number, branch, year, section)
      VALUES ($1, $2, '21KITS0501', '21034A0501', 'CSE', '3rd Year', 'A')
      ON CONFLICT (college_id, roll_number) DO UPDATE SET branch = EXCLUDED.branch
      RETURNING id;
    `, [rahulUser.rows[0].id, kitsId]);
    const rahulStudentId = kitsStudentRes.rows[0].id;

    const student1stRes = await pool.query(`
      INSERT INTO students (user_id, college_id, roll_number, registration_number, branch, year, section)
      VALUES ($1, $2, '24KITS0501', '24034A0501', 'CSE', '1st Year', 'A')
      ON CONFLICT (college_id, roll_number) DO UPDATE SET branch = EXCLUDED.branch
      RETURNING id;
    `, [student1st.rows[0].id, kitsId]);

    const student2ndRes = await pool.query(`
      INSERT INTO students (user_id, college_id, roll_number, registration_number, branch, year, section)
      VALUES ($1, $2, '23KITS0501', '23034A0501', 'CSE', '2nd Year', 'A')
      ON CONFLICT (college_id, roll_number) DO UPDATE SET branch = EXCLUDED.branch
      RETURNING id;
    `, [student2nd.rows[0].id, kitsId]);

    const student4thRes = await pool.query(`
      INSERT INTO students (user_id, college_id, roll_number, registration_number, branch, year, section)
      VALUES ($1, $2, '20KITS0501', '20034A0501', 'CSE', '4th Year', 'A')
      ON CONFLICT (college_id, roll_number) DO UPDATE SET branch = EXCLUDED.branch
      RETURNING id;
    `, [student4th.rows[0].id, kitsId]);

    const adarshStudentRes = await pool.query(`
      INSERT INTO students (user_id, college_id, roll_number, registration_number, branch, year, section)
      VALUES ($1, $2, '21ADR0402', '21034A0402', 'ECE', '3rd Year', 'B')
      ON CONFLICT (college_id, roll_number) DO UPDATE SET branch = EXCLUDED.branch
      RETURNING id;
    `, [snehaUser.rows[0].id, adarshId]);
    const snehaStudentId = adarshStudentRes.rows[0].id;

    // 4. Programs & Batches
    // KITS Program & Batch
    const kitsProgRes = await pool.query(`
      INSERT INTO programs (college_id, name, code, description)
      VALUES ($1, 'Python Full Stack Development', 'PY-FS-2026', 'Comprehensive web architecture with Python, FastAPI, and React.')
      RETURNING id;
    `, [kitsId]);
    const kitsProgId = kitsProgRes.rows[0].id;

    const kitsBatchRes = await pool.query(`
      INSERT INTO batches (program_id, college_id, name, academic_year)
      VALUES ($1, $2, '2026-B.Tech-CSE-A', '2025-2026')
      RETURNING id;
    `, [kitsProgId, kitsId]);
    const kitsBatchId = kitsBatchRes.rows[0].id;

    // Enroll Rahul in KITS Batch
    await pool.query(`
      INSERT INTO student_batch_enrollments (student_id, batch_id, college_id)
      VALUES ($1, $2, $3)
      ON CONFLICT (student_id, batch_id) DO NOTHING;
    `, [rahulStudentId, kitsBatchId, kitsId]);

    // Adarsh Program & Batch
    const adarshProgRes = await pool.query(`
      INSERT INTO programs (college_id, name, code, description)
      VALUES ($1, 'Java Full Stack & Cloud Services', 'JV-FS-2026', 'Enterprise application engineering with Java Spring Boot and Microservices.')
      RETURNING id;
    `, [adarshId]);
    const adarshProgId = adarshProgRes.rows[0].id;

    const adarshBatchRes = await pool.query(`
      INSERT INTO batches (program_id, college_id, name, academic_year)
      VALUES ($1, $2, '2026-B.Tech-ECE-B', '2025-2026')
      RETURNING id;
    `, [adarshProgId, adarshId]);
    const adarshBatchId = adarshBatchRes.rows[0].id;

    // Enroll Sneha in Adarsh Batch
    await pool.query(`
      INSERT INTO student_batch_enrollments (student_id, batch_id, college_id)
      VALUES ($1, $2, $3)
      ON CONFLICT (student_id, batch_id) DO NOTHING;
    `, [snehaStudentId, adarshBatchId, adarshId]);

    // 5. Sessions (Today's Sessions)
    const kitsSessionRes = await pool.query(`
      INSERT INTO sessions (batch_id, college_id, trainer_id, title, description, session_date, start_time, end_time, status)
      VALUES
      ($1, $2, $3, 'Python OOP & Data Structures', 'Deep dive into Object Oriented Architecture, classes, inheritance, and Pythonic patterns.', CURRENT_DATE, '09:30:00', '13:00:00', 'IN_PROGRESS'),
      ($1, $2, $3, 'FastAPI Microservices & Async I/O', 'High-performance backend services with Pydantic and async database connectors.', CURRENT_DATE, '14:00:00', '16:00:00', 'UPCOMING')
      RETURNING id, title;
    `, [kitsBatchId, kitsId, kitsTrainer.rows[0].id]);
    const kitsSessionId = kitsSessionRes.rows[0].id;

    const adarshSessionRes = await pool.query(`
      INSERT INTO sessions (batch_id, college_id, trainer_id, title, description, session_date, start_time, end_time, status)
      VALUES
      ($1, $2, $3, 'Spring Boot Rest API & JPA', 'Enterprise design patterns with Spring Boot 3, Spring Data JPA, and PostgreSQL.', CURRENT_DATE, '09:30:00', '13:00:00', 'IN_PROGRESS')
      RETURNING id, title;
    `, [adarshBatchId, adarshId, adarshTrainer.rows[0].id]);
    const adarshSessionId = adarshSessionRes.rows[0].id;

    // 6. Generate active Dynamic QR for KITS session (5 min token)
    const sampleToken = 'COG-KITS-' + Math.random().toString(36).substring(2, 10).toUpperCase();
    await pool.query(`
      INSERT INTO attendance_qr (session_id, college_id, batch_id, token, valid_from, valid_until, is_active, created_by)
      VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '10 minutes', TRUE, $5)
    `, [kitsSessionId, kitsId, kitsBatchId, sampleToken, kitsTrainer.rows[0].id]);

    console.log(`Generated active dynamic attendance token for KITS session: ${sampleToken}`);

    // 7. Student Behaviour Records
    await pool.query(`
      INSERT INTO student_behaviour (student_id, college_id, attendance_consistency, participation, assignment_completion, assessment_performance, punctuality, trainer_notes)
      VALUES
      ($1, $2, 91.0, 88.0, 85.0, 79.0, 94.0, 'Excellent progress in Python OOP tasks. Consistent participation in live coding exercises.'),
      ($3, $4, 93.0, 90.0, 92.0, 86.0, 95.0, 'High proficiency in Java algorithms. Excellent assignment submission record.')
      ON CONFLICT (student_id) DO NOTHING;
    `, [rahulStudentId, kitsId, snehaStudentId, adarshId]);

    // 8. Materials
    await pool.query(`
      INSERT INTO materials (college_id, program_id, batch_id, subject, topic, title, description, file_url, file_type, file_size, uploaded_by)
      VALUES
      ($1, $2, $3, 'Python Programming', 'Object Oriented Programming', 'Python OOP Master Architecture Guide.pdf', 'Complete breakdown of classes, dunder methods, metaclasses, and design patterns.', '/uploads/PHOTO-2026-09-17-19-27-30.jpg', 'PDF', '2.4 MB', $4),
      ($1, $2, $3, 'Python Programming', 'FastAPI Web Services', 'FastAPI & Async Rest API Architecture.pdf', 'Building scalable microservices with Swagger documentation and SQLModel.', '/uploads/PHOTO-2026-09-15-10-09-04.jpg', 'PDF', '1.8 MB', $4),
      ($5, $6, $7, 'Java Full Stack', 'Spring Framework', 'Spring Boot 3 Enterprise Guide.pdf', 'Spring Dependency Injection, Spring Data, and security architecture.', '/uploads/PHOTO-2026-09-17-19-26-21.jpg', 'PDF', '3.1 MB', $8);
    `, [kitsId, kitsProgId, kitsBatchId, kitsTrainer.rows[0].id, adarshId, adarshProgId, adarshBatchId, adarshTrainer.rows[0].id]);

    // 9. Announcements
    await pool.query(`
      INSERT INTO announcements (college_id, title, message, priority, target_role, created_by)
      VALUES
      ($1, 'Welcome to Cognito Tech Hub 2026', 'Classes have commenced for the 2026 batch. Ensure you scan your daily QR code during morning sessions.', 'HIGH', 'ALL', $2),
      ($1, 'Cognito Hackathon 2026 Announcement', 'Annual intra-college 24-hour development hackathon registrations are now open for CSE 3rd Year.', 'MEDIUM', 'STUDENT', $2),
      ($3, 'Adarsh Tech Hub Onboarding', 'Welcome students of Adarsh College of Engineering. Please complete your profile and verify your email.', 'HIGH', 'ALL', $4);
    `, [kitsId, kitsTrainer.rows[0].id, adarshId, adarshTrainer.rows[0].id]);

    // 10. Courses Catalog
    await pool.query(`
      INSERT INTO courses (name, code, description, category)
      VALUES
      ('Python Full Stack & AI', 'PY-101', 'Python Programming, OOP, FastAPI microservices, and AI models', 'TECHNICAL'),
      ('Java Enterprise Architecture', 'JV-101', 'Java 17, Spring Boot 3, Hibernate JPA, and Microservices', 'TECHNICAL')
      ON CONFLICT (name) DO NOTHING;
    `);

    const pythonCourse = await pool.query(`SELECT id FROM courses WHERE name = 'Python Full Stack & AI'`);
    const javaCourse = await pool.query(`SELECT id FROM courses WHERE name = 'Java Enterprise Architecture'`);

    // 11. Trainer / Tutor Assignments
    // Sushma Madam: Python to 2nd & 3rd Year ONLY (1st & 4th Year strictly excluded)
    // Daiva Rao: 1st & 4th Year
    await pool.query(`DELETE FROM trainer_assignments WHERE trainer_id IN ($1, $2, $3, $4)`, [
      sushmaTrainer.rows[0].id,
      daivaTrainer.rows[0].id,
      kitsTrainer.rows[0].id,
      adarshTrainer.rows[0].id
    ]);

    await pool.query(`
      INSERT INTO trainer_assignments (trainer_id, college_id, course_id, course_name, target_years, target_branches)
      VALUES
      ($1, $2, $3, 'Python Full Stack & AI', ARRAY['2nd Year', '3rd Year'], ARRAY['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH']),
      ($4, $2, $3, 'Technical Skills & Python Foundations', ARRAY['1st Year', '4th Year'], ARRAY['CSE', 'ECE', 'IT', 'AI&DS', 'EEE', 'CIVIL', 'MECH']),
      ($5, $2, $3, 'Python Full Stack & AI', ARRAY['2nd Year', '3rd Year'], ARRAY['CSE']),
      ($6, $7, $8, 'Java Enterprise Architecture', ARRAY['1st Year', '2nd Year', '3rd Year', '4th Year'], ARRAY['ECE', 'EEE']);
    `, [
      sushmaTrainer.rows[0].id,
      kitsId,
      pythonCourse.rows[0]?.id,
      daivaTrainer.rows[0].id,
      kitsTrainer.rows[0].id,
      adarshTrainer.rows[0].id,
      adarshId,
      javaCourse.rows[0]?.id
    ]);

    // 12. Supabase Cloud Sync
    try {
      const allUsers = await pool.query(`SELECT id, email, password_hash, role, full_name, mobile, college_id, status FROM users`);
      for (const u of allUsers.rows) {
        await supabase.from('users').upsert(u);
      }
      const allStudents = await pool.query(`SELECT id, user_id, college_id, roll_number, registration_number, branch, year, section FROM students`);
      for (const s of allStudents.rows) {
        await supabase.from('students').upsert(s);
      }
      const allAssignments = await pool.query(`SELECT id, trainer_id, college_id, course_name, target_years, target_branches FROM trainer_assignments`);
      for (const ta of allAssignments.rows) {
        await supabase.from('trainer_assignments').upsert(ta);
      }
      console.log('Successfully synced users, students, and trainer assignments to Supabase Cloud.');
    } catch (syncErr: any) {
      console.warn('Non-blocking Supabase sync notice:', syncErr.message);
    }

    // 13. Initial Audit Log
    await pool.query(`
      INSERT INTO audit_logs (actor_role, action, entity_type, metadata, ip_address)
      VALUES ('SYSTEM', 'SYSTEM_INITIALIZED', 'DATABASE', '{"event": "Seed data populated for KITS, Adarsh, and Trainer Sushma"}'::jsonb, '127.0.0.1');
    `);

    console.log('Database seeded successfully with multi-tenant data for KITS Divili, Adarsh, and Trainer Sushma!');
  } catch (error) {
    console.error('Error seeding database:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

seedDB();
