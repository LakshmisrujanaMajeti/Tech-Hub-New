import os
import base64
import subprocess

def encode_image(path):
    if os.path.exists(path):
        with open(path, "rb") as f:
            data = base64.b64encode(f.read()).decode("utf-8")
            ext = path.split(".")[-1].lower()
            mime = "image/png" if ext == "png" else "image/jpeg"
            return f"data:{mime};base64,{data}"
    return ""

def generate_html():
    img_login = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/.tempmediaStorage/app_login_screen_ready.png')
    img_colleges = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/.tempmediaStorage/prod_emulator_adarsh_selected_correctly.png')
    img_form = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/.tempmediaStorage/screen_adarsh_step2.png')
    img_active = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/emulator_active_window_updated2.png')

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Adarsh College of Engineering - Student WhatsApp APK Installation & Registration Guide</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

  @page {{
    size: A4 portrait;
    margin: 12mm 14mm 12mm 14mm;
  }}

  * {{
    box-sizing: border-box;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }}

  body {{
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    color: #1E293B;
    background: #FFFFFF;
    line-height: 1.4;
    font-size: 8.8pt;
    margin: 0;
    padding: 0;
  }}

  .page {{
    page-break-after: always;
    position: relative;
    padding-bottom: 22px;
    min-height: 270mm;
  }}

  .page:last-child {{
    page-break-after: avoid;
  }}

  .page-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1.5px solid #E2E8F0;
    padding-bottom: 6px;
    margin-bottom: 12px;
    font-size: 7.5pt;
    color: #64748B;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    font-weight: 700;
  }}

  .page-header .brand {{
    color: #0F172A;
    font-weight: 800;
    display: flex;
    align-items: center;
    gap: 6px;
  }}

  .page-footer {{
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1px solid #E2E8F0;
    padding-top: 6px;
    font-size: 7pt;
    color: #94A3B8;
  }}

  h1 {{
    font-size: 19pt;
    font-weight: 800;
    color: #0F172A;
    line-height: 1.15;
    margin: 0 0 4px 0;
    letter-spacing: -0.4px;
  }}

  h2 {{
    font-size: 12pt;
    font-weight: 800;
    color: #0F172A;
    margin: 12px 0 8px 0;
    letter-spacing: -0.2px;
    display: flex;
    align-items: center;
    gap: 8px;
  }}

  h2::before {{
    content: "";
    display: inline-block;
    width: 4px;
    height: 14px;
    background: #2563EB;
    border-radius: 2px;
  }}

  h3 {{
    font-size: 9.5pt;
    font-weight: 700;
    color: #1E293B;
    margin: 8px 0 4px 0;
  }}

  p {{
    margin: 0 0 6px 0;
    color: #334155;
    font-size: 8.5pt;
  }}

  /* Badges */
  .badge {{
    display: inline-flex;
    align-items: center;
    padding: 2.5px 7px;
    border-radius: 9999px;
    font-size: 6.8pt;
    font-weight: 700;
    letter-spacing: 0.4px;
    text-transform: uppercase;
  }}

  .badge-wa {{ background: #DCF8C6; color: #075E54; border: 1px solid #A7F3D0; }}
  .badge-blue {{ background: #EFF6FF; color: #1D4ED8; border: 1px solid #BFDBFE; }}
  .badge-green {{ background: #ECFDF5; color: #047857; border: 1px solid #A7F3D0; }}
  .badge-amber {{ background: #FFFBEB; color: #B45309; border: 1px solid #FDE68A; }}
  .badge-dark {{ background: #0F172A; color: #F8FAFC; }}

  /* Grid Layouts */
  .grid-2 {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }}

  .grid-3 {{
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 10px;
  }}

  .grid-4 {{
    display: grid;
    grid-template-columns: 1fr 1fr 1fr 1fr;
    gap: 8px;
  }}

  .card {{
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 9px;
    padding: 9px 11px;
  }}

  .card-highlight {{
    background: #F0FDF4;
    border: 1.5px solid #86EFAC;
    border-radius: 9px;
    padding: 9px 11px;
  }}

  .card-alert {{
    background: #FFF7ED;
    border: 1.5px solid #FDBA74;
    border-radius: 9px;
    padding: 9px 11px;
  }}

  .step-box {{
    background: #FFFFFF;
    border: 1.5px solid #E2E8F0;
    border-radius: 9px;
    padding: 9px 11px;
    margin-bottom: 8px;
    position: relative;
  }}

  .step-box.active {{
    border-color: #3B82F6;
    background: #F8FAFC;
  }}

  .step-num {{
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: #2563EB;
    color: #FFFFFF;
    font-weight: 800;
    font-size: 7.5pt;
    margin-right: 6px;
    vertical-align: middle;
  }}

  .step-num-green {{
    background: #059669;
  }}

  .step-title {{
    font-weight: 700;
    color: #0F172A;
    font-size: 8.8pt;
    display: inline-block;
    vertical-align: middle;
  }}

  .phone-mockup {{
    background: #FFFFFF;
    border: 1.5px solid #CBD5E1;
    border-radius: 12px;
    padding: 4px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.06);
    text-align: center;
  }}

  .phone-mockup img {{
    width: 100%;
    height: auto;
    max-height: 235px;
    object-fit: contain;
    border-radius: 8px;
    display: block;
    margin: 0 auto;
  }}

  .caption {{
    font-size: 6.8pt;
    color: #64748B;
    font-weight: 600;
    margin-top: 4px;
    text-align: center;
  }}

  code {{
    font-family: 'JetBrains Mono', monospace;
    background: #F1F5F9;
    padding: 1px 4px;
    border-radius: 4px;
    font-size: 7.2pt;
    color: #0F172A;
    border: 1px solid #E2E8F0;
  }}

  ul {{
    margin: 4px 0 6px 14px;
    padding: 0;
  }}

  li {{
    font-size: 8.2pt;
    color: #334155;
    margin-bottom: 2px;
  }}

  .faq-q {{
    font-weight: 700;
    color: #0F172A;
    font-size: 8.2pt;
    margin-bottom: 2px;
  }}

  .faq-a {{
    font-size: 7.8pt;
    color: #475569;
    margin-bottom: 6px;
  }}
</style>
</head>
<body>

  <!-- ==================== PAGE 1: WHATSAPP APK INSTALLATION ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
        ADARSH COLLEGE OF ENGINEERING &bull; STUDENT HANDBOOK
      </div>
      <div>GUIDE REF: ADARSH-CTH-INSTALL-V2.4</div>
    </div>

    <!-- Title Header Banner -->
    <div style="background: linear-gradient(135deg, #064E3B 0%, #0F172A 100%); color: #FFFFFF; border-radius: 12px; padding: 18px 20px; margin-bottom: 12px;">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <span class="badge badge-wa" style="margin-bottom: 6px; font-weight: 800;">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor" style="margin-right: 4px;"><path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981z"/></svg>
            ADARSH CAMPUS WHATSAPP DISTRIBUTION
          </span>
          <h1 style="color: #FFFFFF; font-size: 19pt; margin: 4px 0 3px 0;">Adarsh Student Registration & Installation Guide</h1>
          <div style="font-size: 9.5pt; color: #A7F3D0; font-weight: 500;">
            How to Install <code style="background: rgba(255,255,255,0.2); color: #FFFFFF; border: none;">app-release.apk</code> from WhatsApp & Register Your Adarsh Student Account
          </div>
        </div>
        <div style="text-align: right; font-size: 7.2pt; color: #94A3B8;">
          <div style="font-weight: 800; color: #F8FAFC; font-size: 8.5pt;">VERSION 2.4.0</div>
          <div>COLLEGE: ADARSH (HN)</div>
          <div>FILE SIZE: 74.4 MB</div>
          <div>HOURS: 09:00 AM – 04:00 PM</div>
        </div>
      </div>
    </div>

    <!-- Quick Info Cards -->
    <div class="grid-4" style="margin-bottom: 10px;">
      <div class="card" style="text-align: center; padding: 6px;">
        <div style="font-weight: 800; font-size: 10pt; color: #065F46;">WhatsApp APK</div>
        <div style="font-size: 6.5pt; color: #64748B; font-weight: 600;">SOURCE FILE</div>
      </div>
      <div class="card" style="text-align: center; padding: 6px;">
        <div style="font-weight: 800; font-size: 10pt; color: #1D4ED8;">Roll Code: HN</div>
        <div style="font-size: 6.5pt; color: #64748B; font-weight: 600;">ADARSH CODE</div>
      </div>
      <div class="card" style="text-align: center; padding: 6px;">
        <div style="font-weight: 800; font-size: 10pt; color: #047857;">09:00 AM – 04:00 PM</div>
        <div style="font-size: 6.5pt; color: #64748B; font-weight: 600;">DAILY WORKING HOURS</div>
      </div>
      <div class="card" style="text-align: center; padding: 6px;">
        <div style="font-weight: 800; font-size: 10pt; color: #B45309;">Zero 24-Hr Lock</div>
        <div style="font-size: 6.5pt; color: #64748B; font-weight: 600;">FRESH DAILY RESET</div>
      </div>
    </div>

    <h2>PART 1: Installing app-release.apk from WhatsApp</h2>
    <p>
      The Adarsh Training & Placement Officer (TPO) and Faculty Coordinators have shared the official release APK file named <strong><code>app-release.apk</code></strong> in your department WhatsApp groups. Follow these steps on your Android smartphone:
    </p>

    <!-- Step Boxes -->
    <div class="step-box">
      <span class="step-num">1</span>
      <span class="step-title">Locate & Download the APK in WhatsApp</span>
      <p style="margin: 4px 0 0 26px; font-size: 8pt; color: #475569;">
        Open your Adarsh College / Class WhatsApp group. Find the file named <strong><code>app-release.apk</code></strong> (around 74.4 MB) sent by your coordinator. Tap the download icon <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> and wait for the download to finish.
      </p>
    </div>

    <div class="step-box">
      <span class="step-num">2</span>
      <span class="step-title">Tap the Downloaded File</span>
      <p style="margin: 4px 0 0 26px; font-size: 8pt; color: #475569;">
        Once downloaded, tap on <strong><code>app-release.apk</code></strong>. Android package installer will launch automatically.
      </p>
    </div>

    <div class="step-box active" style="border-color: #F59E0B; background: #FFFBEB;">
      <span class="step-num" style="background: #D97706;">3</span>
      <span class="step-title" style="color: #92400E;">Enable "Allow from this source" (Android Security Prompt)</span>
      <p style="margin: 4px 0 0 26px; font-size: 8pt; color: #78350F;">
        Because you are installing directly from WhatsApp, Android will show: <br>
        <em>"For your security, your phone is not allowed to install unknown apps from this source."</em><br>
        &bull; Tap <strong>SETTINGS</strong> on that pop-up window.<br>
        &bull; Turn the toggle switch <strong>"Allow from this source"</strong> to <strong style="color: #065F46;">ON (Blue/Green)</strong>.<br>
        &bull; Tap the back button <strong style="font-size: 9pt;">&larr;</strong> to return to WhatsApp.
      </p>
    </div>

    <div class="step-box active" style="border-color: #10B981; background: #ECFDF5;">
      <span class="step-num step-num-green">4</span>
      <span class="step-title" style="color: #065F46;">Google Play Protect Notice (Tap "More details" &rarr; "Install anyway")</span>
      <p style="margin: 4px 0 0 26px; font-size: 8pt; color: #047857;">
        If Google Play Protect displays a message saying <em>"Unrecognized app"</em> or <em>"Blocked by Play Protect"</em>:<br>
        &bull; Tap <strong>More details</strong> (small text underneath the message).<br>
        &bull; Tap <strong>"Install anyway"</strong>.<br>
        <em>Note: This appears because the APK is distributed directly within campus WhatsApp groups rather than through the public Play Store. The application is completely safe, official, and certified for Adarsh students.</em>
      </p>
    </div>

    <div class="step-box">
      <span class="step-num">5</span>
      <span class="step-title">Tap "Install" & Wait for Completion</span>
      <p style="margin: 4px 0 0 26px; font-size: 8pt; color: #475569;">
        Tap <strong>INSTALL</strong> at the bottom right. Android will install the app. Once finished, tap <strong>OPEN</strong> to launch <strong>Cognito Tech Hub</strong>!
      </p>
    </div>

    <div class="card-alert" style="margin-top: 6px;">
      <div style="display: flex; align-items: center; gap: 6px;">
        <strong style="color: #9A3412; font-size: 8.2pt;">CRITICAL CAMERA PERMISSION:</strong>
        <span style="font-size: 7.8pt; color: #7C2D12;">When prompted by Android on first camera scan, select <strong>"While using the app"</strong>. Camera access is mandatory to scan classroom attendance QR codes.</span>
      </div>
    </div>

    <div class="page-footer">
      <div>Adarsh College of Engineering &bull; Student WhatsApp Installation & Registration Guide</div>
      <div>Page 1 of 4</div>
    </div>
  </div>

  <!-- ==================== PAGE 2: STUDENT REGISTRATION ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">ADARSH COLLEGE OF ENGINEERING &bull; STUDENT REGISTRATION WORKFLOW</div>
      <div>GUIDE REF: ADARSH-CTH-INSTALL-V2.4</div>
    </div>

    <h2>PART 2: Step-by-Step Adarsh Student Account Registration</h2>
    <p>
      Every Adarsh student must complete a one-time self-registration to link their profile to the Adarsh nominal register and enable verifiable QR attendance tracking:
    </p>

    <!-- 3 Phone Mockups Row -->
    <div class="grid-3" style="margin-bottom: 10px;">
      <div class="phone-mockup">
        <img src="{img_login}" alt="Tap Register as Student">
        <div class="caption"><strong>Step A:</strong> Tap "Register as Student" on Login.</div>
      </div>
      <div class="phone-mockup">
        <img src="{img_colleges}" alt="Select Adarsh College">
        <div class="caption"><strong>Step B:</strong> Select "Adarsh College of Engineering" (HN).</div>
      </div>
      <div class="phone-mockup">
        <img src="{img_form}" alt="Enter Adarsh Student Details">
        <div class="caption"><strong>Step C:</strong> Enter Roll (21HN1A...), Branch & Year.</div>
      </div>
    </div>

    <!-- Registration Detailed Steps -->
    <div class="step-box">
      <span class="step-num">1</span>
      <span class="step-title">Start Registration</span>
      <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #475569;">
        Open the app. On the main login page, scroll to the bottom and tap <strong>"Register as Student"</strong>.
      </p>
    </div>

    <div class="step-box active" style="border-color: #3B82F6;">
      <span class="step-num">2</span>
      <span class="step-title" style="color: #1D4ED8;">Select Your College: Adarsh College of Engineering (HN)</span>
      <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #1E3A8A;">
        In the search bar, type <strong>Adarsh</strong> or tap <strong>"Adarsh College of Engineering" (Roll Code: HN)</strong>.<br>
        A blue checkmark will confirm your selection. Then tap <strong>"Continue with Adarsh Engineering College"</strong>.
      </p>
    </div>

    <div class="step-box">
      <span class="step-num">3</span>
      <span class="step-title">Fill Academic & Personal Details (Step 2 of 2)</span>
      <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #475569;">
        Complete the registration fields accurately for Adarsh College:
      </p>
      <div class="grid-2" style="margin: 4px 0 0 26px;">
        <ul style="margin: 0; padding-left: 12px;">
          <li><strong>Full Name:</strong> Enter your official name as registered on campus.</li>
          <li><strong>Adarsh Roll Number:</strong> Must start with <code>21HN...</code> or <code>22HN...</code> (e.g. <code>21HN1A5401</code>).</li>
          <li><strong>Department / Branch:</strong> CSE, ECE, MECH, CIVIL, AIDS, IT.</li>
        </ul>
        <ul style="margin: 0; padding-left: 12px;">
          <li><strong>Year & Section:</strong> Current academic year (e.g. 3rd Year, Section A).</li>
          <li><strong>Mobile & Email:</strong> Enter your 10-digit mobile number and student email.</li>
          <li><strong>Password:</strong> Create a secure password you will remember for daily login.</li>
        </ul>
      </div>
    </div>

    <div class="step-box active" style="border-color: #10B981; background: #ECFDF5;">
      <span class="step-num step-num-green">4</span>
      <span class="step-title" style="color: #065F46;">Submit & Finish Registration</span>
      <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #047857;">
        Tap <strong>"Proceed to Verification / Complete Registration"</strong>. Your account is immediately linked to the Adarsh institutional database. You can now log in right away!
      </p>
    </div>

    <div class="page-footer">
      <div>Adarsh College of Engineering &bull; Student WhatsApp Installation & Registration Guide</div>
      <div>Page 2 of 4</div>
    </div>
  </div>

  <!-- ==================== PAGE 3: DAILY ATTENDANCE ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">ADARSH COLLEGE OF ENGINEERING &bull; ATTENDANCE WORKFLOW (09:00 AM – 04:00 PM)</div>
      <div>GUIDE REF: ADARSH-CTH-INSTALL-V2.4</div>
    </div>

    <h2>PART 3: Daily Attendance Workflow (09:00 AM – 04:00 PM IST)</h2>
    <p>
      Attendance marking in Cognito Tech Hub is strictly enforced within daily operating hours to ensure authenticity and prevent proxy submissions:
    </p>

    <div class="grid-2" style="margin-bottom: 10px;">
      <div>
        <div class="card-highlight" style="margin-bottom: 8px;">
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <strong style="color: #15803D; font-size: 9pt;">ADARSH ATTENDANCE WORKING HOURS</strong>
            <span class="badge badge-green">STRICT WINDOW</span>
          </div>
          <div style="font-size: 13pt; font-weight: 800; color: #065F46; margin: 4px 0;">09:00 AM &ndash; 04:00 PM IST</div>
          <p style="font-size: 7.8pt; color: #166534; margin: 0;">
            Attendance is accepted strictly during this 7-hour daily working window.
          </p>
        </div>

        <div class="step-box">
          <span class="step-num">1</span>
          <span class="step-title">Log in to Student Dashboard</span>
          <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #475569;">
            Enter your Adarsh Roll Number (e.g. <code>21HN1A5401</code>) and Password &rarr; Tap <strong>LOG IN</strong>.
          </p>
        </div>

        <div class="step-box">
          <span class="step-num">2</span>
          <span class="step-title">Check Classroom Session Card</span>
          <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #475569;">
            Your dashboard will show today's classroom slot (e.g. <em>Morning Technical Slot</em>) and assigned faculty trainer.
          </p>
        </div>

        <div class="step-box active" style="border-color: #3B82F6;">
          <span class="step-num">3</span>
          <span class="step-title" style="color: #1D4ED8;">Tap "SCAN ATTENDANCE QR"</span>
          <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #1E3A8A;">
            Point your camera at the trainer's projected smart-board QR code. When scanned, your phone vibrates and confirms:
            <br>
            <strong style="color: #15803D;">&check; TODAY'S ATTENDANCE COMPLETED</strong>
          </p>
        </div>

        <div class="step-box" style="border-color: #F59E0B; background: #FFFBEB;">
          <span class="step-num" style="background: #D97706;">4</span>
          <span class="step-title" style="color: #92400E;">Zero 24-Hour Wait Lockout!</span>
          <p style="margin: 3px 0 0 26px; font-size: 8pt; color: #78350F;">
            You do <strong>NOT</strong> have to wait 24 hours to mark tomorrow! Even if you marked attendance late in the afternoon at 3:50 PM, the system unlocks freshly tomorrow morning at 09:00 AM sharp!
          </p>
        </div>
      </div>

      <div class="phone-mockup">
        <img src="{img_active}" alt="Student Dashboard Active Verified Attendance">
        <div class="caption">Figure: Verified Attendance completion banner during active hours (09:00 AM – 04:00 PM).</div>
      </div>
    </div>

    <h3>What Happens After 04:00 PM?</h3>
    <div class="card-alert">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
        <strong style="color: #9A3412; font-size: 8.5pt;">AFTER 04:00 PM &bull; SCANNER AUTOMATICALLY TURNS OFF</strong>
        <span class="badge badge-amber">TIMED OUT</span>
      </div>
      <p style="font-size: 8pt; color: #7C2D12; margin: 0;">
        At 04:00:00 PM IST every day, the attendance scanning bar and scan button are <strong>completely hidden</strong>. The app displays an amber timeout notification:
        <br>
        <em>"Daily attendance hours (09:00 AM – 04:00 PM) have ended. Scanner is closed. Attendance bar reopens tomorrow morning at 09:00 AM."</em>
      </p>
    </div>

    <div class="page-footer">
      <div>Adarsh College of Engineering &bull; Student WhatsApp Installation & Registration Guide</div>
      <div>Page 3 of 4</div>
    </div>
  </div>

  <!-- ==================== PAGE 4: TROUBLESHOOTING & DOWNLOADS ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">ADARSH COLLEGE OF ENGINEERING &bull; TROUBLESHOOTING & DIRECT DOWNLOADS</div>
      <div>GUIDE REF: ADARSH-CTH-INSTALL-V2.4</div>
    </div>

    <h2>PART 4: WhatsApp Installation Troubleshooting & FAQs</h2>

    <div class="card" style="margin-bottom: 8px;">
      <div class="faq-q">Q1: WhatsApp says "Can't open file" when I tap app-release.apk. What should I do?</div>
      <div class="faq-a">
        <strong>Solution:</strong> Some Android versions block opening APKs directly from inside WhatsApp chat. Open your phone's built-in <strong>"Files"</strong> or <strong>"File Manager"</strong> app &rarr; Go to <strong>Downloads</strong> or <strong>WhatsApp &gt; Media &gt; WhatsApp Documents</strong> &rarr; Tap <code>app-release.apk</code> to install.
      </div>

      <div class="faq-q">Q2: Google Play Protect displays a red or orange warning saying "Blocked by Play Protect".</div>
      <div class="faq-a">
        <strong>Solution:</strong> Tap the small text that says <strong>"More details"</strong> &rarr; then tap <strong>"Install anyway"</strong>. This is normal for all campus-distributed enterprise APKs. The app is 100% verified and free of malware.
      </div>

      <div class="faq-q">Q3: It says "App not installed" after tapping Install.</div>
      <div class="faq-a">
        <strong>Solution:</strong> (a) Check your phone storage and ensure at least 250 MB free space. (b) If an older version of the app exists on your phone, uninstall it first, then tap <code>app-release.apk</code> again.
      </div>

      <div class="faq-q">Q4: The camera screen is completely black or shows a permission error when scanning QR.</div>
      <div class="faq-a">
        <strong>Solution:</strong> Go to your phone <strong>Settings &rarr; Apps &rarr; Cognito Tech Hub &rarr; Permissions &rarr; Camera</strong> &rarr; Set to <strong>"Allow only while using the app"</strong>.
      </div>

      <div class="faq-q">Q5: It says "Roll number already registered" when I try to register.</div>
      <div class="faq-a">
        <strong>Solution:</strong> Your roll number is already in the system. Return to the main login screen and log in with your Roll Number (e.g. <code>21HN1A5401</code>) and password. If you forgot your password, contact the Adarsh TPO office or your trainer.
      </div>
    </div>

    <h2>Direct Alternative Download Links</h2>
    <p>If the APK file is deleted or lost from your WhatsApp chat, download it directly using any mobile browser:</p>

    <div style="background: #EFF6FF; border: 1.5px dashed #3B82F6; border-radius: 9px; padding: 8px 12px; margin-bottom: 8px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 3px;">
        <strong style="color: #1D4ED8; font-size: 8.5pt;">GLOBAL HTTPS DOWNLOAD (CLOUDFLARE)</strong>
        <span class="badge badge-blue">ALL NETWORKS &bull; 4G/5G</span>
      </div>
      <div style="font-size: 8pt; word-break: break-all; font-weight: 700;">
        <a href="https://placed-settlement-overview-virginia.trycloudflare.com/uploads/app-release.apk" style="color: #1D4ED8; text-decoration: none;">
          https://placed-settlement-overview-virginia.trycloudflare.com/uploads/app-release.apk
        </a>
      </div>
    </div>

    <div style="background: #F8FAFC; border: 1.5px dashed #94A3B8; border-radius: 9px; padding: 8px 12px; margin-bottom: 12px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 3px;">
        <strong style="color: #0F172A; font-size: 8.5pt;">LOCAL CAMPUS LAN DOWNLOAD (ON-PREMISE WI-FI)</strong>
        <span class="badge badge-dark">CAMPUS WI-FI</span>
      </div>
      <div style="font-size: 8pt; word-break: break-all; font-weight: 700;">
        <a href="http://192.168.6.200:5050/uploads/app-release.apk" style="color: #0F172A; text-decoration: none;">
          http://192.168.6.200:5050/uploads/app-release.apk
        </a>
      </div>
    </div>

    <!-- Official Support Card -->
    <div style="background: linear-gradient(135deg, #0F172A 0%, #1E3A8A 100%); color: #FFFFFF; border-radius: 10px; padding: 12px 16px; text-align: center;">
      <div style="font-weight: 800; font-size: 10pt; color: #FFFFFF; margin-bottom: 2px;">
        Adarsh College of Engineering & Technology (Autonomous)
      </div>
      <div style="font-size: 7.8pt; color: #CBD5E1;">
        Training & Placement Cell &bull; Cognito Tech Hub Academic Platform
      </div>
      <div style="font-size: 7.2pt; color: #94A3B8; margin-top: 4px;">
        For registration assistance, contact the Adarsh TPO Office or Department Placement Coordinators.
      </div>
    </div>

    <div class="page-footer">
      <div>Adarsh College of Engineering &bull; Student WhatsApp Installation & Registration Guide</div>
      <div>Page 4 of 4</div>
    </div>
  </div>

</body>
</html>
"""
    return html

def main():
    html_content = generate_html()
    html_path = "/tmp/cognito_tech_hub_registration_guide.html"
    pdf_dest1 = "/Users/satyaalugolu/Desktop/Tech Hub/Cognito_Tech_Hub_WhatsApp_Installation_and_Registration_Guide.pdf"
    pdf_dest2 = "/Users/satyaalugolu/Desktop/Tech Hub/backend/uploads/Cognito_Tech_Hub_WhatsApp_Installation_and_Registration_Guide.pdf"
    pdf_dest3 = "/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/Cognito_Tech_Hub_WhatsApp_Installation_and_Registration_Guide.pdf"

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"Wrote HTML to {html_path} ({len(html_content)} bytes)")

    cmd = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "--headless",
        "--disable-gpu",
        f"--print-to-pdf={pdf_dest1}",
        "--no-pdf-header-footer",
        html_path
    ]
    print("Running Chrome headless to generate PDF...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    print("Chrome output:", res.stdout, res.stderr)

    if os.path.exists(pdf_dest1):
        size = os.path.getsize(pdf_dest1)
        print(f"Generated PDF: {pdf_dest1} ({size} bytes)")
        import shutil
        shutil.copyfile(pdf_dest1, pdf_dest2)
        shutil.copyfile(pdf_dest1, pdf_dest3)
        print(f"Copied to: {pdf_dest2} and {pdf_dest3}")
    else:
        print("Error: PDF was not generated!")

if __name__ == "__main__":
    main()
