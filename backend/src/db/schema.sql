-- Cognito Tech Hub Multi-Tenant Database Schema
-- Extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Colleges (Tenants)
CREATE TABLE IF NOT EXISTS colleges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    college_code VARCHAR(50) UNIQUE NOT NULL,
    college_name VARCHAR(255) NOT NULL,
    short_name VARCHAR(100) NOT NULL,
    address TEXT,
    district VARCHAR(100),
    state VARCHAR(100),
    logo_url TEXT,
    banner_url TEXT,
    primary_color VARCHAR(20) DEFAULT '#0057B8',
    secondary_color VARCHAR(20) DEFAULT '#003366',
    student_registration_enabled BOOLEAN DEFAULT TRUE,
    is_registered_hub BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER', 'STUDENT')),
    full_name VARCHAR(255) NOT NULL,
    mobile VARCHAR(30),
    college_id UUID REFERENCES colleges(id) ON DELETE CASCADE,
    status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'PENDING_VERIFICATION')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for tenant queries and auth
CREATE INDEX IF NOT EXISTS idx_users_college ON users(college_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- 3. Students
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    roll_number VARCHAR(100) NOT NULL,
    registration_number VARCHAR(100),
    branch VARCHAR(100) NOT NULL,
    year VARCHAR(50) NOT NULL,
    section VARCHAR(20) NOT NULL,
    gender VARCHAR(20),
    date_of_birth DATE,
    aadhar_id VARCHAR(20),
    address TEXT,
    profile_photo TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_college_roll_number UNIQUE (college_id, roll_number)
);

ALTER TABLE students ADD COLUMN IF NOT EXISTS aadhar_id VARCHAR(20);
ALTER TABLE students ADD COLUMN IF NOT EXISTS address TEXT;

CREATE INDEX IF NOT EXISTS idx_students_college ON students(college_id);
CREATE INDEX IF NOT EXISTS idx_students_roll ON students(roll_number);

-- 4. Programs
CREATE TABLE IF NOT EXISTS programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_programs_college ON programs(college_id);

-- 5. Batches
CREATE TABLE IF NOT EXISTS batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    program_id UUID NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    academic_year VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_batches_college ON batches(college_id);
CREATE INDEX IF NOT EXISTS idx_batches_program ON batches(program_id);

-- 6. Student Batch Enrollments
CREATE TABLE IF NOT EXISTS student_batch_enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_student_batch UNIQUE (student_id, batch_id)
);

CREATE INDEX IF NOT EXISTS idx_enrollment_student ON student_batch_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollment_batch ON student_batch_enrollments(batch_id);

-- 7. Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status VARCHAR(30) DEFAULT 'UPCOMING' CHECK (status IN ('UPCOMING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_batch ON sessions(batch_id);
CREATE INDEX IF NOT EXISTS idx_sessions_college_date ON sessions(college_id, session_date);

-- 8. Attendance QR Sessions
CREATE TABLE IF NOT EXISTS attendance_qr (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_qr_token ON attendance_qr(token);
CREATE INDEX IF NOT EXISTS idx_qr_session ON attendance_qr(session_id);

-- 9. Attendance Records
CREATE TABLE IF NOT EXISTS attendance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    marked_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'LATE', 'ABSENT')),
    device_info TEXT,
    ip_address VARCHAR(50),
    method VARCHAR(30) DEFAULT 'QR_SCAN',
    CONSTRAINT unique_session_student_attendance UNIQUE (session_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_att_records_student ON attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_att_records_session ON attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_att_records_college ON attendance_records(college_id);

-- 10. Student Behaviour & Analytics
CREATE TABLE IF NOT EXISTS student_behaviour (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID UNIQUE NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    attendance_consistency NUMERIC(5,2) DEFAULT 90.0,
    participation NUMERIC(5,2) DEFAULT 85.0,
    assignment_completion NUMERIC(5,2) DEFAULT 88.0,
    assessment_performance NUMERIC(5,2) DEFAULT 82.0,
    punctuality NUMERIC(5,2) DEFAULT 92.0,
    trainer_notes TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_behaviour_student ON student_behaviour(student_id);

-- 11. Materials & Notes
CREATE TABLE IF NOT EXISTS materials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    program_id UUID REFERENCES programs(id) ON DELETE SET NULL,
    batch_id UUID REFERENCES batches(id) ON DELETE SET NULL,
    subject VARCHAR(150) NOT NULL,
    topic VARCHAR(200) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_url TEXT NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    file_size VARCHAR(50),
    uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_materials_college ON materials(college_id);
CREATE INDEX IF NOT EXISTS idx_materials_batch ON materials(batch_id);

-- 12. Announcements
CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    college_id UUID REFERENCES colleges(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    priority VARCHAR(30) DEFAULT 'MEDIUM' CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
    target_role VARCHAR(50) DEFAULT 'ALL',
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_announcements_college ON announcements(college_id);

-- 13. Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_role VARCHAR(50),
    college_id UUID REFERENCES colleges(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100),
    metadata JSONB,
    ip_address VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_college ON audit_logs(college_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);

-- 14. App Versions
CREATE TABLE IF NOT EXISTS app_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    platform VARCHAR(30) NOT NULL,
    latest_version VARCHAR(30) NOT NULL,
    minimum_version VARCHAR(30) NOT NULL,
    force_update BOOLEAN DEFAULT FALSE,
    release_notes JSONB,
    download_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_platform_version UNIQUE (platform)
);

-- 15. OTP Verifications
CREATE TABLE IF NOT EXISTS otp_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    attempts INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_otp_email ON otp_verifications(email);

-- 16. Courses Catalog
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50),
    description TEXT,
    category VARCHAR(50) DEFAULT 'TECHNICAL',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 17. Trainer Campus Assignments
CREATE TABLE IF NOT EXISTS trainer_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    course_name VARCHAR(100),
    target_years TEXT[] DEFAULT ARRAY['3rd Year'],
    target_branches TEXT[] DEFAULT ARRAY['CSE'],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 18. Trainer Mandatory Daily Attendance
CREATE TABLE IF NOT EXISTS trainer_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    check_out_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'LATE', 'HALF_DAY', 'ON_DUTY', 'ABSENT')),
    location_notes TEXT,
    device_info TEXT,
    verified_by_admin UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_trainer_daily_attendance UNIQUE (trainer_id, attendance_date)
);

CREATE INDEX IF NOT EXISTS idx_trainer_att_date ON trainer_attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_trainer_att_college ON trainer_attendance(college_id);
CREATE INDEX IF NOT EXISTS idx_trainer_att_trainer ON trainer_attendance(trainer_id);

-- 19. Trainer Payroll & Financial Compensation (SUPER ADMIN & PROGRAM MANAGER ONLY)
CREATE TABLE IF NOT EXISTS trainer_payroll (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID REFERENCES colleges(id) ON DELETE SET NULL,
    payroll_month VARCHAR(20) NOT NULL,
    base_monthly_salary NUMERIC(12, 2) DEFAULT 0.00,
    per_session_rate NUMERIC(10, 2) DEFAULT 0.00,
    sessions_delivered INTEGER DEFAULT 0,
    hours_delivered NUMERIC(8, 2) DEFAULT 0.00,
    incentive_amount NUMERIC(10, 2) DEFAULT 0.00,
    deductions NUMERIC(10, 2) DEFAULT 0.00,
    total_payout NUMERIC(12, 2) GENERATED ALWAYS AS (base_monthly_salary + (per_session_rate * sessions_delivered) + incentive_amount - deductions) STORED,
    currency VARCHAR(10) DEFAULT 'INR',
    payment_status VARCHAR(30) DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PROCESSED', 'PAID', 'ON_HOLD')),
    payment_date DATE,
    transaction_reference VARCHAR(100),
    bank_name VARCHAR(100),
    bank_account_number VARCHAR(50),
    bank_ifsc VARCHAR(30),
    pan_number VARCHAR(30),
    contract_type VARCHAR(50) DEFAULT 'FULL_TIME' CHECK (contract_type IN ('FULL_TIME', 'VISITING_FACULTY', 'CONTRACT', 'HOURLY')),
    notes TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_trainer_payroll_month UNIQUE (trainer_id, payroll_month)
);

CREATE INDEX IF NOT EXISTS idx_payroll_trainer ON trainer_payroll(trainer_id);
CREATE INDEX IF NOT EXISTS idx_payroll_month ON trainer_payroll(payroll_month);
CREATE INDEX IF NOT EXISTS idx_payroll_status ON trainer_payroll(payment_status);

-- 20. Trainer Daily Reports
CREATE TABLE IF NOT EXISTS trainer_daily_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    course_name VARCHAR(100),
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    target_year VARCHAR(20),
    target_branch VARCHAR(50),
    topics_covered TEXT NOT NULL,
    students_present INTEGER DEFAULT 0,
    hands_on_activities TEXT,
    challenges_faced TEXT,
    tomorrow_plan TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
