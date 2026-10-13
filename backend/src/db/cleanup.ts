import { pool } from './pool.js';

async function cleanupTestData() {
  console.log('\n🧹 Purging test transactions and dummy student accounts from Cognito Tech Hub...');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Purge attendance records
    const attRes = await client.query('DELETE FROM attendance_records');
    console.log(`- Cleared ${attRes.rowCount} test attendance records.`);

    // 2. Purge active & past QR codes
    const qrRes = await client.query('DELETE FROM attendance_qr');
    console.log(`- Cleared ${qrRes.rowCount} attendance QR tokens.`);

    // 3. Purge student behaviour evaluation records
    const behRes = await client.query('DELETE FROM student_behaviour');
    console.log(`- Cleared ${behRes.rowCount} student behaviour records.`);

    // 4. Purge student batch enrollments
    const enrRes = await client.query('DELETE FROM student_batch_enrollments');
    console.log(`- Cleared ${enrRes.rowCount} student batch enrollments.`);

    // 5. Purge dummy students
    const stuRes = await client.query('DELETE FROM students');
    console.log(`- Cleared ${stuRes.rowCount} dummy student profiles.`);

    // 6. Purge user accounts with role 'STUDENT'
    const usrRes = await client.query("DELETE FROM users WHERE role = 'STUDENT'");
    console.log(`- Cleared ${usrRes.rowCount} student user accounts.`);

    // 7. Purge audit logs
    const auditRes = await client.query('DELETE FROM audit_logs');
    console.log(`- Cleared ${auditRes.rowCount} test audit log entries.`);

    // 8. Purge OTP verifications
    const otpRes = await client.query('DELETE FROM otp_verifications');
    console.log(`- Cleared ${otpRes.rowCount} OTP verification records.`);

    // 9. Reset session status to UPCOMING
    const sessRes = await client.query("UPDATE sessions SET status = 'UPCOMING'");
    console.log(`- Reset ${sessRes.rowCount} classroom sessions to UPCOMING status.`);

    await client.query('COMMIT');
    console.log('✅ Test data cleanup completed successfully.\n');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error purging test data:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

cleanupTestData();
