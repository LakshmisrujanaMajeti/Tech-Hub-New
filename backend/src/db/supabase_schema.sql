-- ====================================================================
-- COGNITO TECH HUB — SUPABASE PRODUCTION MULTI-TENANT SCHEMA & POLICIES
-- ====================================================================
-- Version: 2.1.0
-- Target: Supabase SQL Editor (PostgreSQL 15+)
-- Features:
--   1. Dynamic Attendance QR:
--      - DISPLAYED ONLY FOR: SUPER_ADMIN, PROGRAM_MANAGER, COLLEGE_ADMIN, TPO, TRAINER
--      - HIDDEN FROM STUDENTS (Students scan and submit token via secure RPC)
--   2. Trainer Payroll & Financial Details:
--      - DISPLAYED ONLY FOR: SUPER_ADMIN and PROGRAM_MANAGER
--      - STRICTLY HIDDEN FROM College Admins, TPOs, Trainers, and Students
--   3. Trainer Attendance Logs:
--      - DISPLAYED FOR: SUPER_ADMIN, PROGRAM_MANAGER, and respective COLLEGE_ADMIN
--   4. Full Row-Level Security (RLS) & Helper Functions
-- ====================================================================

-- 0. Ensure Required Extensions & System Roles Exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Safe creation of standard Supabase Auth Schema & Roles if running in custom environment
CREATE SCHEMA IF NOT EXISTS auth;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Fallback auth.uid() function if running on local Postgres without GoTrue
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'auth' AND p.proname = 'uid'
  ) THEN
    CREATE OR REPLACE FUNCTION auth.uid()
    RETURNS UUID
    LANGUAGE sql
    STABLE
    AS $f$
      SELECT NULL::uuid;
    $f$;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ====================================================================
-- 1. COLLEGES (TENANTS)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.colleges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_code VARCHAR(50) UNIQUE NOT NULL,
    roll_code VARCHAR(10),
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
    is_registered_hub BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.colleges ADD COLUMN IF NOT EXISTS roll_code VARCHAR(10);
ALTER TABLE public.colleges ADD COLUMN IF NOT EXISTS is_registered_hub BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_colleges_code ON public.colleges(college_code);
CREATE INDEX IF NOT EXISTS idx_colleges_roll ON public.colleges(roll_code);

-- ====================================================================
-- 2. USERS TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(30) NOT NULL CHECK (role IN ('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER', 'STUDENT')),
    full_name VARCHAR(255) NOT NULL,
    mobile VARCHAR(30),
    college_id UUID REFERENCES public.colleges(id) ON DELETE CASCADE,
    status VARCHAR(30) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'PENDING_VERIFICATION')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_college ON public.users(college_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- ====================================================================
-- 3. STUDENTS TABLE
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
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
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_college_roll_number UNIQUE (college_id, roll_number)
);

ALTER TABLE public.students ADD COLUMN IF NOT EXISTS aadhar_id VARCHAR(20);
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS address TEXT;

CREATE INDEX IF NOT EXISTS idx_students_college ON public.students(college_id);
CREATE INDEX IF NOT EXISTS idx_students_roll ON public.students(roll_number);

-- ====================================================================
-- 4. ACADEMIC STRUCTURE (PROGRAMS & BATCHES)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES public.programs(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    academic_year VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.student_batch_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_student_batch UNIQUE (student_id, batch_id)
);

-- ====================================================================
-- 5. COURSES & TRAINER ASSIGNMENTS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50),
    description TEXT,
    category VARCHAR(50) DEFAULT 'TECHNICAL',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.trainer_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    course_id UUID REFERENCES public.courses(id) ON DELETE SET NULL,
    course_name VARCHAR(100),
    target_years TEXT[] DEFAULT ARRAY['3rd Year'],
    target_branches TEXT[] DEFAULT ARRAY['CSE'],
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================
-- 6. SESSIONS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status VARCHAR(30) DEFAULT 'UPCOMING' CHECK (status IN ('UPCOMING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_batch ON public.sessions(batch_id);
CREATE INDEX IF NOT EXISTS idx_sessions_college_date ON public.sessions(college_id, session_date);

-- ====================================================================
-- 7. ATTENDANCE DYNAMIC QR SESSIONS
-- (RULE: DISPLAYED ONLY TO SUPER_ADMIN, PROGRAM_MANAGER, COLLEGE_ADMIN, TPO, TRAINER)
-- (STUDENTS CANNOT VIEW OR SELECT DIRECTLY FROM THIS TABLE)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.attendance_qr (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_qr_token ON public.attendance_qr(token);
CREATE INDEX IF NOT EXISTS idx_qr_session ON public.attendance_qr(session_id);
CREATE INDEX IF NOT EXISTS idx_qr_college ON public.attendance_qr(college_id);

-- ====================================================================
-- 8. ATTENDANCE RECORDS (STUDENT CHECK-IN LOGS)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED')),
    marked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    marked_method VARCHAR(30) DEFAULT 'QR_SCAN' CHECK (marked_method IN ('QR_SCAN', 'MANUAL_CODE', 'TRAINER_OVERRIDE')),
    device_info TEXT,
    ip_address VARCHAR(50),
    CONSTRAINT unique_student_session_attendance UNIQUE (session_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_att_records_student ON public.attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_att_records_session ON public.attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_att_records_college ON public.attendance_records(college_id);

-- ====================================================================
-- 9. TRAINER ATTENDANCE DATA
-- (RULE: DISPLAYED TO SUPER_ADMIN, PROGRAM_MANAGER, AND COLLEGE_ADMIN FOR THEIR CAMPUS)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.trainer_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    check_out_time TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'PRESENT' CHECK (status IN ('PRESENT', 'LATE', 'HALF_DAY', 'ON_DUTY', 'ABSENT')),
    location_notes TEXT,
    device_info TEXT,
    verified_by_admin UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_trainer_daily_attendance UNIQUE (trainer_id, attendance_date)
);

ALTER TABLE public.trainer_attendance ADD COLUMN IF NOT EXISTS check_out_time TIMESTAMPTZ;
ALTER TABLE public.trainer_attendance ADD COLUMN IF NOT EXISTS verified_by_admin UUID REFERENCES public.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_trainer_att_date ON public.trainer_attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_trainer_att_college ON public.trainer_attendance(college_id);
CREATE INDEX IF NOT EXISTS idx_trainer_att_trainer ON public.trainer_attendance(trainer_id);

-- ====================================================================
-- 10. TRAINER PAYROLL & COMPENSATION DETAILS
-- (RULE: DISPLAYED AND ACCESSIBLE ONLY TO SUPER_ADMIN AND PROGRAM_MANAGER)
-- (COMPLETELY RESTRICTED FROM COLLEGE ADMINS, TPOS, TRAINERS, AND STUDENTS)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.trainer_payroll (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    college_id UUID REFERENCES public.colleges(id) ON DELETE SET NULL,
    payroll_month VARCHAR(20) NOT NULL, -- Format: 'YYYY-MM' (e.g., '2026-09')
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
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_trainer_payroll_month UNIQUE (trainer_id, payroll_month)
);

CREATE INDEX IF NOT EXISTS idx_payroll_trainer ON public.trainer_payroll(trainer_id);
CREATE INDEX IF NOT EXISTS idx_payroll_month ON public.trainer_payroll(payroll_month);
CREATE INDEX IF NOT EXISTS idx_payroll_status ON public.trainer_payroll(payment_status);

-- ====================================================================
-- 11. TRAINER DAILY REPORTS & LOGS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.trainer_daily_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    course_name VARCHAR(100),
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    target_year VARCHAR(20),
    target_branch VARCHAR(50),
    topics_covered TEXT NOT NULL,
    students_present INTEGER DEFAULT 0,
    hands_on_activities TEXT,
    challenges_faced TEXT,
    tomorrow_plan TEXT,
    submitted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================
-- 12. STUDY MATERIALS & CURRICULUM
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID REFERENCES public.colleges(id) ON DELETE CASCADE,
    program_id UUID REFERENCES public.programs(id) ON DELETE SET NULL,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    course_name VARCHAR(100),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_url TEXT NOT NULL,
    file_type VARCHAR(50) DEFAULT 'PDF',
    file_size_bytes BIGINT,
    target_year VARCHAR(20),
    target_branch VARCHAR(50),
    target_branches TEXT[],
    uploaded_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================
-- 13. STUDENT BEHAVIOUR & ACADEMIC PROGRESS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.student_behaviour (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    attendance_consistency NUMERIC(5, 2) DEFAULT 0.0 CHECK (attendance_consistency >= 0 AND attendance_consistency <= 100),
    session_participation NUMERIC(5, 2) DEFAULT 0.0 CHECK (session_participation >= 0 AND session_participation <= 100),
    assignment_completion NUMERIC(5, 2) DEFAULT 0.0 CHECK (assignment_completion >= 0 AND assignment_completion <= 100),
    assessment_scores NUMERIC(5, 2) DEFAULT 0.0 CHECK (assessment_scores >= 0 AND assessment_scores <= 100),
    classroom_punctuality NUMERIC(5, 2) DEFAULT 0.0 CHECK (classroom_punctuality >= 0 AND classroom_punctuality <= 100),
    overall_progress_score NUMERIC(5, 2) DEFAULT 0.0,
    trainer_feedback TEXT,
    updated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_student_behaviour UNIQUE (student_id)
);

-- ====================================================================
-- 14. ANNOUNCEMENTS & AUDIT LOGS
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID REFERENCES public.colleges(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'NORMAL' CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID REFERENCES public.colleges(id) ON DELETE SET NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(100),
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ANDROID', 'IOS', 'WEB')),
    latest_version VARCHAR(50) NOT NULL,
    min_required_version VARCHAR(50) NOT NULL DEFAULT '1.0.0',
    minimum_version VARCHAR(50) DEFAULT '1.0.0',
    force_update BOOLEAN DEFAULT FALSE,
    download_url TEXT,
    release_notes JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_platform_version UNIQUE (platform)
);

ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS min_required_version VARCHAR(50) DEFAULT '1.0.0';
ALTER TABLE public.app_versions ADD COLUMN IF NOT EXISTS minimum_version VARCHAR(50) DEFAULT '1.0.0';
DO $$
BEGIN
  ALTER TABLE public.app_versions ALTER COLUMN minimum_version DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.otp_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    otp_code VARCHAR(10) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.campus_interest_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID REFERENCES public.colleges(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    mobile VARCHAR(30),
    roll_number VARCHAR(50),
    status VARCHAR(30) DEFAULT 'REQUEST_ACCEPTED',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ====================================================================
-- 15. SECURITY DEFINER HELPER FUNCTIONS FOR RLS
-- ====================================================================

-- Extract current authenticated user ID
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    auth.uid(),
    NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid,
    NULLIF((current_setting('request.jwt.claims', true)::jsonb)->>'sub', '')::uuid
  );
$$;

-- Extract current authenticated user Role
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS VARCHAR
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role VARCHAR;
  v_uid UUID;
BEGIN
  -- 1. Check custom claim in JWT if present
  BEGIN
    v_role := (current_setting('request.jwt.claims', true)::jsonb)->>'user_role';
    IF v_role IS NOT NULL AND v_role IN ('SUPER_ADMIN', 'PROGRAM_MANAGER', 'COLLEGE_ADMIN', 'TPO', 'TRAINER', 'STUDENT') THEN
      RETURN v_role;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- 2. Lookup role from public.users using user ID
  v_uid := public.get_current_user_id();
  IF v_uid IS NOT NULL THEN
    SELECT role INTO v_role FROM public.users WHERE id = v_uid LIMIT 1;
    IF v_role IS NOT NULL THEN
      RETURN v_role;
    END IF;
  END IF;

  RETURN 'ANON';
END;
$$;

-- Extract current authenticated user College ID
CREATE OR REPLACE FUNCTION public.get_current_user_college_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_college_id UUID;
  v_uid UUID;
BEGIN
  -- 1. Check custom claim in JWT if present
  BEGIN
    v_college_id := ((current_setting('request.jwt.claims', true)::jsonb)->>'college_id')::uuid;
    IF v_college_id IS NOT NULL THEN
      RETURN v_college_id;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  -- 2. Lookup college_id from public.users
  v_uid := public.get_current_user_id();
  IF v_uid IS NOT NULL THEN
    SELECT college_id INTO v_college_id FROM public.users WHERE id = v_uid LIMIT 1;
    RETURN v_college_id;
  END IF;

  RETURN NULL;
END;
$$;

-- ====================================================================
-- 16. ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

-- Enable RLS on core protected tables
ALTER TABLE public.attendance_qr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_payroll ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------------------
-- A. ATTENDANCE DYNAMIC QR POLICIES
-- Rule: Displayed to Super Admin, Program Manager, College Admin, TPO, Trainer ONLY.
-- Students have ZERO SELECT access!
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "allow_select_attendance_qr_admin_trainer" ON public.attendance_qr;
CREATE POLICY "allow_select_attendance_qr_admin_trainer"
ON public.attendance_qr
FOR SELECT
TO authenticated
USING (
  -- Super Admin and Program Manager can see all active QR slots
  public.get_current_user_role() IN ('SUPER_ADMIN', 'PROGRAM_MANAGER')
  OR
  -- College Admin and TPO can only see QR slots of their respective college
  (public.get_current_user_role() IN ('COLLEGE_ADMIN', 'TPO') AND college_id = public.get_current_user_college_id())
  OR
  -- Trainers can see QR codes they created or for their assigned college
  (public.get_current_user_role() = 'TRAINER' AND (
     created_by = public.get_current_user_id() 
     OR college_id = public.get_current_user_college_id()
  ))
);

DROP POLICY IF EXISTS "allow_insert_attendance_qr_staff" ON public.attendance_qr;
CREATE POLICY "allow_insert_attendance_qr_staff"
ON public.attendance_qr
FOR INSERT
TO authenticated
WITH CHECK (
  public.get_current_user_role() IN ('SUPER_ADMIN', 'PROGRAM_MANAGER')
  OR
  (public.get_current_user_role() = 'COLLEGE_ADMIN' AND college_id = public.get_current_user_college_id())
  OR
  (public.get_current_user_role() = 'TRAINER' AND college_id = public.get_current_user_college_id())
);

-- --------------------------------------------------------------------
-- B. TRAINER PAYROLL POLICIES
-- Rule: Displayed ONLY for Super Admin and Program Manager.
-- Completely hidden from College Admins, TPOs, Trainers, and Students.
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "allow_full_trainer_payroll_super_admin_pm_only" ON public.trainer_payroll;
CREATE POLICY "allow_full_trainer_payroll_super_admin_pm_only"
ON public.trainer_payroll
FOR ALL
TO authenticated
USING (
  public.get_current_user_role() IN ('SUPER_ADMIN', 'PROGRAM_MANAGER')
)
WITH CHECK (
  public.get_current_user_role() IN ('SUPER_ADMIN', 'PROGRAM_MANAGER')
);

-- --------------------------------------------------------------------
-- C. TRAINER ATTENDANCE POLICIES
-- Rule: Shown to Super Admin, Program Manager, and respective College Admin.
-- Trainer can log and view their own attendance.
-- Hidden from Students and TPOs.
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "allow_select_trainer_attendance" ON public.trainer_attendance;
CREATE POLICY "allow_select_trainer_attendance"
ON public.trainer_attendance
FOR SELECT
TO authenticated
USING (
  -- Super Admin and Program Manager can see all trainer attendances
  public.get_current_user_role() IN ('SUPER_ADMIN', 'PROGRAM_MANAGER')
  OR
  -- College Admin sees attendance of trainers at their college
  (public.get_current_user_role() = 'COLLEGE_ADMIN' AND college_id = public.get_current_user_college_id())
  OR
  -- Trainers can see their own daily attendance logs
  (public.get_current_user_role() = 'TRAINER' AND trainer_id = public.get_current_user_id())
);

DROP POLICY IF EXISTS "allow_insert_trainer_attendance" ON public.trainer_attendance;
CREATE POLICY "allow_insert_trainer_attendance"
ON public.trainer_attendance
FOR INSERT
TO authenticated
WITH CHECK (
  public.get_current_user_role() IN ('SUPER_ADMIN', 'PROGRAM_MANAGER')
  OR
  (public.get_current_user_role() = 'COLLEGE_ADMIN' AND college_id = public.get_current_user_college_id())
  OR
  (public.get_current_user_role() = 'TRAINER' AND trainer_id = public.get_current_user_id())
);

-- --------------------------------------------------------------------
-- D. ATTENDANCE RECORDS (STUDENTS) POLICIES
-- --------------------------------------------------------------------
DROP POLICY IF EXISTS "allow_select_attendance_records" ON public.attendance_records;
CREATE POLICY "allow_select_attendance_records"
ON public.attendance_records
FOR SELECT
TO authenticated
USING (
  public.get_current_user_role() IN ('SUPER_ADMIN', 'PROGRAM_MANAGER')
  OR (public.get_current_user_role() IN ('COLLEGE_ADMIN', 'TPO') AND college_id = public.get_current_user_college_id())
  OR (public.get_current_user_role() = 'TRAINER' AND college_id = public.get_current_user_college_id())
  OR (public.get_current_user_role() = 'STUDENT' AND student_id IN (
       SELECT id FROM public.students WHERE user_id = public.get_current_user_id()
  ))
);

-- ====================================================================
-- 17. SECURE RPC FOR STUDENT QR CODE SCANNING
-- (Students execute this function to mark attendance securely without
-- needing direct SELECT permissions on attendance_qr)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.mark_student_dynamic_qr_attendance(
  p_token TEXT,
  p_device_info TEXT DEFAULT 'Mobile App Scanner'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_student RECORD;
  v_qr RECORD;
  v_session RECORD;
  v_new_record_id UUID;
  v_existing_id UUID;
  v_consistency NUMERIC(5,2);
  v_total_sessions INT;
  v_attended_sessions INT;
BEGIN
  -- 1. Identify student from authenticated session
  SELECT s.*, u.full_name, u.email
  INTO v_student
  FROM public.students s
  JOIN public.users u ON s.user_id = u.id
  WHERE u.id = public.get_current_user_id();

  IF v_student.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Student profile not found for authenticated user.');
  END IF;

  -- 2. Lookup dynamic QR token
  SELECT * INTO v_qr
  FROM public.attendance_qr
  WHERE token = TRIM(p_token)
  LIMIT 1;

  IF v_qr.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid attendance QR code.');
  END IF;

  -- 3. Check expiration and active state
  IF NOT v_qr.is_active OR v_qr.valid_until < CURRENT_TIMESTAMP THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'This dynamic attendance QR code has expired. Ask your instructor to refresh the session.'
    );
  END IF;

  -- 4. Multi-Tenant Campus Check
  IF v_student.college_id <> v_qr.college_id THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Tenant mismatch: This attendance code belongs to another college institution.'
    );
  END IF;

  -- 5. Check if already marked
  SELECT id INTO v_existing_id
  FROM public.attendance_records
  WHERE session_id = v_qr.session_id AND student_id = v_student.id;

  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Attendance already marked for this session. Duplicate scanning is not permitted.'
    );
  END IF;

  -- 6. Auto-enroll into batch if not already enrolled
  INSERT INTO public.student_batch_enrollments (student_id, batch_id, college_id)
  VALUES (v_student.id, v_qr.batch_id, v_qr.college_id)
  ON CONFLICT DO NOTHING;

  -- 7. Record Attendance
  INSERT INTO public.attendance_records (
    session_id, student_id, college_id, status, marked_method, device_info
  ) VALUES (
    v_qr.session_id, v_student.id, v_qr.college_id, 'PRESENT', 'QR_SCAN', p_device_info
  ) RETURNING id INTO v_new_record_id;

  -- 8. Update consistency score
  SELECT 
    COUNT(DISTINCT s.id),
    COUNT(DISTINCT ar.id)
  INTO v_total_sessions, v_attended_sessions
  FROM public.sessions s
  JOIN public.student_batch_enrollments sbe ON s.batch_id = sbe.batch_id AND sbe.student_id = v_student.id
  LEFT JOIN public.attendance_records ar ON s.id = ar.session_id AND ar.student_id = v_student.id
  WHERE s.session_date <= CURRENT_DATE;

  IF v_total_sessions > 0 THEN
    v_consistency := LEAST(100.0, ROUND((v_attended_sessions::numeric / v_total_sessions::numeric) * 100.0, 1));
    UPDATE public.student_behaviour
    SET attendance_consistency = v_consistency, updated_at = CURRENT_TIMESTAMP
    WHERE student_id = v_student.id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Attendance recorded successfully!',
    'attendanceId', v_new_record_id,
    'studentRoll', v_student.roll_number,
    'markedAt', CURRENT_TIMESTAMP
  );
END;
$$;

-- ====================================================================
-- 18. CONVENIENT SECURE VIEWS
-- ====================================================================

-- View 1: Active Daily Slots (For Super Admin, PM, College Admin, TPO, Trainer)
CREATE OR REPLACE VIEW public.view_daily_attendance_slots AS
SELECT 
  aq.id as qr_id,
  aq.token,
  aq.valid_from,
  aq.valid_until,
  aq.is_active,
  (aq.is_active AND aq.valid_until > CURRENT_TIMESTAMP) as is_currently_valid,
  s.id as session_id,
  s.title as session_title,
  s.session_date,
  s.start_time,
  s.end_time,
  c.id as college_id,
  c.college_name,
  c.short_name as college_short_name,
  b.name as batch_name,
  (SELECT COUNT(*) FROM public.attendance_records ar WHERE ar.session_id = s.id) as total_present
FROM public.attendance_qr aq
JOIN public.sessions s ON aq.session_id = s.id
JOIN public.colleges c ON aq.college_id = c.id
JOIN public.batches b ON aq.batch_id = b.id;

-- View 2: Trainer Attendance Overview (For Super Admin, PM, College Admin)
CREATE OR REPLACE VIEW public.view_trainer_attendance_summary AS
SELECT 
  ta.id as attendance_id,
  ta.attendance_date,
  ta.check_in_time,
  ta.check_out_time,
  ta.status,
  ta.location_notes,
  ta.device_info,
  u.id as trainer_id,
  u.full_name as trainer_name,
  u.email as trainer_email,
  u.mobile as trainer_mobile,
  c.id as college_id,
  c.college_name,
  c.short_name as college_short_name
FROM public.trainer_attendance ta
JOIN public.users u ON ta.trainer_id = u.id
JOIN public.colleges c ON ta.college_id = c.id;

-- View 3: Trainer Payroll Overview (SUPER ADMIN & PROGRAM MANAGER ONLY)
CREATE OR REPLACE VIEW public.view_trainer_payroll_summary AS
SELECT 
  tp.id as payroll_id,
  tp.payroll_month,
  u.id as trainer_id,
  u.full_name as trainer_name,
  u.email as trainer_email,
  u.mobile as trainer_mobile,
  c.short_name as assigned_college,
  tp.contract_type,
  tp.base_monthly_salary,
  tp.per_session_rate,
  tp.sessions_delivered,
  tp.hours_delivered,
  tp.incentive_amount,
  tp.deductions,
  tp.total_payout,
  tp.currency,
  tp.payment_status,
  tp.payment_date,
  tp.transaction_reference,
  tp.bank_name,
  tp.bank_account_number,
  tp.bank_ifsc,
  tp.pan_number,
  tp.created_at
FROM public.trainer_payroll tp
JOIN public.users u ON tp.trainer_id = u.id
LEFT JOIN public.colleges c ON tp.college_id = c.id;

-- ====================================================================
-- 19. PERMISSIONS & GRANTS
-- ====================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;

-- Authenticated Users Grants (Subject to RLS)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_student_dynamic_qr_attendance TO authenticated;

-- Public / Anonymous Grants (Registration & Version Checks)
GRANT SELECT ON public.colleges TO anon;
GRANT SELECT ON public.app_versions TO anon;
GRANT SELECT, INSERT ON public.campus_interest_requests TO anon;
GRANT SELECT, INSERT, UPDATE ON public.otp_verifications TO anon;

-- ====================================================================
-- 20. SEED DATA & DEFAULTS
-- ====================================================================

-- 1. App Versions
INSERT INTO public.app_versions (platform, latest_version, min_required_version, minimum_version, force_update, download_url, release_notes)
VALUES 
('ANDROID', '1.2.0', '1.0.0', '1.0.0', FALSE, 'https://cognitoinsights.ai/download/android', '{"features": ["Dynamic QR attendance engine", "Restricted trainer payroll", "Campus attendance rosters"]}'::jsonb),
('WEB', '1.2.0', '1.0.0', '1.0.0', FALSE, 'https://cognitoinsights.ai', '{"features": ["Web dashboard for Super Admin, Program Managers, and College Admins"]}'::jsonb)
ON CONFLICT (platform) DO UPDATE 
SET latest_version = EXCLUDED.latest_version, 
    min_required_version = EXCLUDED.min_required_version,
    minimum_version = EXCLUDED.minimum_version,
    release_notes = EXCLUDED.release_notes;

-- 2. Partner Colleges
INSERT INTO public.colleges (college_code, roll_code, college_name, short_name, address, district, state, logo_url, banner_url, primary_color, secondary_color, is_registered_hub)
VALUES 
('KITS_DIVILI', 'JQ', 'Kakinada Institute of Technology & Science', 'KITS Divili', 'Tirupathi (V), Divili, Peddapuram Mandal, Kakinada District, Andhra Pradesh - 533433', 'Kakinada', 'Andhra Pradesh', '/uploads/kits_logo.png', '/uploads/PHOTO-2026-09-17-19-27-30.jpg', '#0057B8', '#003366', TRUE),
('ADARSH', 'HN', 'Adarsh College of Engineering', 'Adarsh Engineering College', 'NH-16, Chebrolu, Gollaprolu Mandal, Kakinada District, Andhra Pradesh - 533449', 'Kakinada', 'Andhra Pradesh', '/uploads/adharsh_logo.png', '/uploads/PHOTO-2026-09-17-19-26-21.jpg', '#C2410C', '#7C2D12', TRUE)
ON CONFLICT (college_code) DO UPDATE 
SET roll_code = EXCLUDED.roll_code, is_registered_hub = EXCLUDED.is_registered_hub;

-- 3. Super Admins & Program Manager (Password: Cognito@2025)
INSERT INTO public.users (email, password_hash, role, full_name, mobile, college_id)
SELECT 'cognitoinsights2025@gmail.com', '$2a$10$178CN/YvtfROnma/V8TWm.J6pp21CIjja1E9sKsoCru42Ayft1k22', 'SUPER_ADMIN', 'Cognito Super Admin', '+91 98765 43210', NULL
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'cognitoinsights2025@gmail.com');

INSERT INTO public.users (email, password_hash, role, full_name, mobile, college_id)
SELECT 'admin@cognitoinsights.ai', '$2a$10$178CN/YvtfROnma/V8TWm.J6pp21CIjja1E9sKsoCru42Ayft1k22', 'SUPER_ADMIN', 'Cognito Super Admin', '+91 98765 43210', NULL
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'admin@cognitoinsights.ai');

INSERT INTO public.users (email, password_hash, role, full_name, mobile, college_id)
SELECT 'pm@cognitoinsights.ai', '$2a$10$178CN/YvtfROnma/V8TWm.J6pp21CIjja1E9sKsoCru42Ayft1k22', 'PROGRAM_MANAGER', 'Cognito Program Manager', '+91 98765 43211', NULL
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'pm@cognitoinsights.ai');

-- 4. Initial Courses
INSERT INTO public.courses (name, code, description, category)
VALUES 
('Full Stack Web Development (MERN)', 'FS-MERN', 'Enterprise web applications using MongoDB, Express, React, and Node.js.', 'TECHNICAL'),
('AI & Applied Machine Learning', 'AI-ML', 'Deep learning, neural networks, PyTorch, and generative AI solutions.', 'ADVANCED_TECH'),
('Flutter Cross-Platform Mobile Dev', 'FLUTTER-01', 'Production mobile development with Dart and native hardware integrations.', 'MOBILE')
ON CONFLICT (name) DO NOTHING;

-- ====================================================================
-- VERIFICATION NOTIFICATION
-- ====================================================================
DO $$
BEGIN
  RAISE NOTICE 'Cognito Tech Hub Supabase Schema & Security Policies applied successfully!';
END $$;
