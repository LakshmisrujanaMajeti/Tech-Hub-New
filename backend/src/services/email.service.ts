import { Resend } from 'resend';
import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

const resendApiKey = process.env.RESEND_API_KEY || '';
const resend = resendApiKey ? new Resend(resendApiKey) : null;
const fromEmail = process.env.RESEND_FROM_EMAIL || 'Cognito Tech Hub <noreply@techhub.cognitoinsights.ai>';

// Gmail SMTP configuration (if provided in .env: SMTP_USER and SMTP_PASS)
const smtpUser = process.env.SMTP_USER || process.env.GMAIL_USER || '';
const smtpPass = process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '';

let smtpTransporter: any = null;
if (smtpUser && smtpPass) {
  smtpTransporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });
  console.log(`[EMAIL] Configured Direct Gmail SMTP via: ${smtpUser}`);
}

export async function sendOtpEmail(email: string, otp: string): Promise<boolean> {
  console.log(`\n========================================`);
  console.log(`[AUTH-OTP] Generated 6-Digit OTP for ${email}: ${otp}`);
  console.log(`========================================\n`);

  const htmlContent = `
    <div style="font-family: Arial, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; border-radius: 12px; background-color: #FFFFFF;">
      <div style="text-align: center; margin-bottom: 24px;">
        <h1 style="color: #0057B8; margin: 0; font-size: 26px;">Cognito Tech Hub</h1>
        <p style="color: #64748B; margin-top: 6px; font-size: 14px;">Cognito Insights Private Limited</p>
      </div>
      <div style="background-color: #EAF4FF; border-radius: 8px; padding: 20px; text-align: center; margin-bottom: 20px;">
        <p style="color: #0F172A; font-size: 14px; margin-bottom: 8px;">Your 6-digit registration verification code is:</p>
        <span style="display: inline-block; font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #0057B8;">${otp}</span>
        <p style="color: #64748B; font-size: 12px; margin-top: 8px;">Valid for 10 minutes. Do not share this OTP with anyone.</p>
      </div>
      <p style="color: #64748B; font-size: 13px; line-height: 1.6;">
        If you did not request this verification code, please ignore this email.
      </p>
      <hr style="border: none; border-top: 1px solid #E2E8F0; margin: 24px 0;" />
      <p style="text-align: center; color: #94A3B8; font-size: 11px;">
        © ${new Date().getFullYear()} Cognito Insights Private Limited. All rights reserved.
      </p>
    </div>
  `;

  // 1. Try Direct Gmail SMTP Transporter first if configured
  if (smtpTransporter) {
    try {
      await smtpTransporter.sendMail({
        from: `"Cognito Tech Hub" <${smtpUser}>`,
        to: email,
        subject: 'Your Cognito Tech Hub Verification Code',
        html: htmlContent,
      });
      console.log(`[GMAIL SMTP SUCCESS] Email delivered directly to ${email}`);
      return true;
    } catch (smtpErr) {
      console.warn('[GMAIL SMTP ERROR]', smtpErr);
    }
  }

  // 2. Try Resend API
  if (resend) {
    try {
      const { data, error } = await resend.emails.send({
        from: fromEmail,
        to: [email],
        subject: 'Your Cognito Tech Hub Verification Code',
        html: htmlContent,
      });

      if (error) {
        console.warn('[RESEND RESTRICTION]', error.message);
        return true;
      }

      console.log('[RESEND SUCCESS] Email dispatched with ID:', data?.id);
      return true;
    } catch (err) {
      console.error('[RESEND DISPATCH ERROR]', err);
      return true;
    }
  }

  return true;
}
