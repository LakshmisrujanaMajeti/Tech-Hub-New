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
    img_student_home = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/emulator_active_window_updated2.png')
    img_tpo = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/emulator_tpo_portal_screen.png')
    img_student_att = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/screen_student_clean_attendance.png')
    img_student_beh = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/screen_student_clean_behaviour.png')
    img_trainer_portal = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/screen_trainer_portal.png')
    img_trainer_qr = encode_image('/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/screen_trainer_daily_qr_fresh.png')

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Cognito Tech Hub - Comprehensive Platform & Application Specification</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

  @page {{
    size: A4 portrait;
    margin: 14mm 14mm 14mm 14mm;
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
    line-height: 1.45;
    font-size: 9pt;
    margin: 0;
    padding: 0;
  }}

  .page {{
    page-break-after: always;
    position: relative;
    padding-bottom: 24px;
  }}

  .page:last-child {{
    page-break-after: avoid;
  }}

  /* Header & Footer Rules */
  .page-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1.5px solid #E2E8F0;
    padding-bottom: 8px;
    margin-bottom: 16px;
    font-size: 7.5pt;
    color: #64748B;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    font-weight: 600;
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

  /* Typography */
  h1 {{
    font-size: 22pt;
    font-weight: 800;
    color: #0F172A;
    line-height: 1.15;
    margin: 0 0 6px 0;
    letter-spacing: -0.5px;
  }}

  h2 {{
    font-size: 13pt;
    font-weight: 800;
    color: #0F172A;
    margin: 14px 0 8px 0;
    letter-spacing: -0.2px;
    display: flex;
    align-items: center;
    gap: 8px;
  }}

  h2::before {{
    content: "";
    display: inline-block;
    width: 4px;
    height: 15px;
    background: #3B82F6;
    border-radius: 2px;
  }}

  h3 {{
    font-size: 10pt;
    font-weight: 700;
    color: #1E293B;
    margin: 10px 0 4px 0;
  }}

  p {{
    margin: 0 0 8px 0;
    color: #334155;
    font-size: 8.8pt;
  }}

  /* Badges & Pills */
  .badge {{
    display: inline-flex;
    align-items: center;
    padding: 3px 8px;
    border-radius: 9999px;
    font-size: 7pt;
    font-weight: 700;
    letter-spacing: 0.4px;
    text-transform: uppercase;
  }}

  .badge-blue {{ background: #EFF6FF; color: #1D4ED8; border: 1px solid #BFDBFE; }}
  .badge-green {{ background: #ECFDF5; color: #047857; border: 1px solid #A7F3D0; }}
  .badge-amber {{ background: #FFFBEB; color: #B45309; border: 1px solid #FDE68A; }}
  .badge-purple {{ background: #F5F3FF; color: #6D28D9; border: 1px solid #DDD6FE; }}
  .badge-dark {{ background: #0F172A; color: #F8FAFC; }}

  /* Grids & Cards */
  .grid-2 {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
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
    border-radius: 10px;
    padding: 10px 12px;
  }}

  .card-highlight {{
    background: #F0FDF4;
    border: 1.5px solid #86EFAC;
    border-radius: 10px;
    padding: 10px 12px;
  }}

  .card-alert {{
    background: #FFF7ED;
    border: 1.5px solid #FDBA74;
    border-radius: 10px;
    padding: 10px 12px;
  }}

  .card-navy {{
    background: #0F172A;
    color: #F8FAFC;
    border-radius: 12px;
    padding: 16px 18px;
  }}

  .card-navy h2, .card-navy h3, .card-navy p {{
    color: #F8FAFC;
  }}

  .stat-card {{
    background: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 8px;
    padding: 8px 10px;
    text-align: center;
  }}

  .stat-value {{
    font-size: 14pt;
    font-weight: 800;
    color: #0F172A;
    line-height: 1.1;
  }}

  .stat-label {{
    font-size: 6.8pt;
    font-weight: 600;
    color: #64748B;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-top: 2px;
  }}

  /* Tables */
  table {{
    width: 100%;
    border-collapse: collapse;
    margin: 8px 0;
    font-size: 8pt;
  }}

  th {{
    background: #F1F5F9;
    color: #334155;
    font-weight: 700;
    text-align: left;
    padding: 6px 8px;
    border: 1px solid #E2E8F0;
    font-size: 7.2pt;
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }}

  td {{
    padding: 6px 8px;
    border: 1px solid #E2E8F0;
    color: #334155;
    vertical-align: top;
  }}

  tr:nth-child(even) td {{
    background: #F8FAFC;
  }}

  code {{
    font-family: 'JetBrains Mono', monospace;
    background: #F1F5F9;
    padding: 1px 4px;
    border-radius: 4px;
    font-size: 7.5pt;
    color: #0F172A;
    border: 1px solid #E2E8F0;
  }}

  .phone-mockup {{
    background: #FFFFFF;
    border: 1.5px solid #CBD5E1;
    border-radius: 14px;
    padding: 4px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.06);
    text-align: center;
  }}

  .phone-mockup img {{
    width: 100%;
    height: auto;
    max-height: 250px;
    object-fit: contain;
    border-radius: 10px;
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

  ul {{
    margin: 4px 0 8px 16px;
    padding: 0;
  }}

  li {{
    font-size: 8.5pt;
    color: #334155;
    margin-bottom: 3px;
  }}

  .flow-step {{
    background: #F8FAFC;
    border-left: 3px solid #3B82F6;
    padding: 6px 10px;
    margin-bottom: 6px;
    border-radius: 0 6px 6px 0;
  }}

  .flow-step strong {{
    color: #0F172A;
    font-size: 8.5pt;
  }}

  .download-box {{
    background: #EFF6FF;
    border: 1.5px dashed #3B82F6;
    border-radius: 10px;
    padding: 10px 14px;
    margin-top: 10px;
  }}

  .download-box a {{
    color: #1D4ED8;
    text-decoration: none;
    font-weight: 700;
    word-break: break-all;
  }}
</style>
</head>
<body>

  <!-- ==================== PAGE 1: COVER & EXECUTIVE SUMMARY ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#2563EB" stroke-width="2.5"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
        COGNITO TECH HUB &bull; PLATFORM SPECIFICATION
      </div>
      <div>DOC REF: CTH-SPEC-2026-V2.4</div>
    </div>

    <div style="background: linear-gradient(135deg, #0F172A 0%, #1E3A8A 100%); color: #FFFFFF; border-radius: 14px; padding: 22px 24px; margin-bottom: 16px;">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <span class="badge badge-blue" style="background: rgba(255,255,255,0.15); color: #93C5FD; border-color: rgba(255,255,255,0.25); margin-bottom: 8px;">
            ENTERPRISE CAMPUS ACADEMIC SYSTEM
          </span>
          <h1 style="color: #FFFFFF; font-size: 24pt; margin: 6px 0 4px 0;">Cognito Tech Hub</h1>
          <div style="font-size: 11pt; color: #CBD5E1; font-weight: 500;">
            Autonomous Campus Technical Training, Verifiable Attendance & Placement Management Platform
          </div>
        </div>
        <div style="text-align: right; font-size: 7.5pt; color: #94A3B8;">
          <div style="font-weight: 800; color: #F8FAFC; font-size: 9pt;">RELEASE v2.4.0</div>
          <div>DATE: September 2026</div>
          <div>STATUS: STABLE &bull; LIVE ON CAMPUS</div>
          <div>DISTRIBUTION: OFFICIAL ENTERPRISE</div>
        </div>
      </div>

      <div style="margin-top: 16px; padding-top: 14px; border-top: 1px solid rgba(255,255,255,0.15); display: flex; gap: 16px; font-size: 7.8pt;">
        <div><strong style="color: #93C5FD;">Publisher:</strong> Cognito Insights Private Limited</div>
        <div><strong style="color: #93C5FD;">Mobile Engine:</strong> Flutter 3 / Android Native</div>
        <div><strong style="color: #93C5FD;">Cloud Core:</strong> Node.js TypeScript REST API</div>
        <div><strong style="color: #93C5FD;">Database:</strong> Supabase PostgreSQL (Multi-Tenant)</div>
      </div>
    </div>

    <!-- Core Highlights Metric Cards -->
    <div class="grid-4" style="margin-bottom: 14px;">
      <div class="stat-card" style="border-top: 3px solid #2563EB;">
        <div class="stat-value" style="color: #2563EB;">09:00 - 16:00</div>
        <div class="stat-label">Daily Attendance Hours</div>
      </div>
      <div class="stat-card" style="border-top: 3px solid #10B981;">
        <div class="stat-value" style="color: #10B981;">0 Seconds</div>
        <div class="stat-label">Rolling Lockout (Eliminated)</div>
      </div>
      <div class="stat-card" style="border-top: 3px solid #8B5CF6;">
        <div class="stat-value" style="color: #8B5CF6;">100% Isolated</div>
        <div class="stat-label">Institutional Data Privacy</div>
      </div>
      <div class="stat-card" style="border-top: 3px solid #F59E0B;">
        <div class="stat-value" style="color: #F59E0B;">74.4 MB</div>
        <div class="stat-label">Production Release APK</div>
      </div>
    </div>

    <h2>1. Executive Overview</h2>
    <p>
      <strong>Cognito Tech Hub</strong> is a purpose-built, enterprise-grade educational ecosystem engineered to modernize and digitize technical skill-building, corporate placement bootcamps, and classroom attendance tracking across autonomous and accredited engineering colleges.
    </p>
    <p>
      Traditional educational management systems often suffer from fragmented manual paper rolls, vulnerable proxy attendance, cross-department data spillage, and inflexible 24-hour rolling locks that frustrate students who attended afternoon sessions and are blocked the following morning. Cognito Tech Hub solves these challenges through an end-to-end synchronized architecture combining a high-performance Flutter mobile application, role-restricted administrative dashboards, and a hardened backend API.
    </p>

    <div class="grid-2" style="margin-top: 10px;">
      <div class="card">
        <h3 style="color: #1D4ED8; margin-top: 0;">Institutional Value Proposition</h3>
        <ul>
          <li><strong>Autonomous Campus Portals:</strong> Dedicated, strictly isolated portals for College Admins and Training & Placement Officers (TPO).</li>
          <li><strong>Verifiable Presence:</strong> Dynamic, cryptographically time-stamped QR codes clamped strictly to daily classroom hours.</li>
          <li><strong>Nominal Register Automation:</strong> Instant department filtering (CSE, ECE, MECH, CIVIL, AIDS, IT) with one-click nominal export.</li>
          <li><strong>Holistic Analytics:</strong> 360-degree student evaluation tracking technical attendance, punctuality, and learning behaviour.</li>
        </ul>
      </div>

      <div class="card">
        <h3 style="color: #047857; margin-top: 0;">Student & Trainer Empowerment</h3>
        <ul>
          <li><strong>Zero-Friction Marking:</strong> Fast camera-based QR scanning with instant database synchronization and visual confirmation.</li>
          <li><strong>Clean Daily Window:</strong> Attendance opens freshly each day at 09:00 AM IST without any rolling 24-hour penalty.</li>
          <li><strong>Curated Study Handouts:</strong> Instant offline-friendly access to syllabus materials, code notebooks, and lecture notes.</li>
          <li><strong>Digital Identity Verification:</strong> Official institutional photo ID card with verifiable QR code and department metadata.</li>
        </ul>
      </div>
    </div>

    <div class="page-footer">
      <div>Cognito Tech Hub &bull; Confidential Official Specification</div>
      <div>Page 1 of 6</div>
    </div>
  </div>

  <!-- ==================== PAGE 2: ARCHITECTURE & SECURITY ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">COGNITO TECH HUB &bull; SYSTEM ARCHITECTURE & SECURITY</div>
      <div>DOC REF: CTH-SPEC-2026-V2.4</div>
    </div>

    <h2>2. System Architecture & Multi-Tenant Isolation</h2>
    <p>
      The platform follows a modern, decoupled multi-tier architecture designed for horizontal scalability, zero-trust network transmission, and complete institutional data confidentiality.
    </p>

    <div class="card-navy" style="margin: 10px 0;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <span class="badge badge-blue" style="background: #1D4ED8; color: #FFFFFF;">HIGH-LEVEL TOPOLOGY</span>
        <span style="font-size: 7pt; color: #94A3B8;">END-TO-END SECURE FLOW</span>
      </div>
      <div style="font-family: 'JetBrains Mono', monospace; font-size: 7.2pt; line-height: 1.6; color: #E2E8F0;">
        [ Flutter Mobile Client ] &bull; Students &bull; Trainers &bull; Institutional Admins &bull; TPOs<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&bull; (HTTPS / TLS 1.3 / Cloudflare Zero Trust Tunnel)<br>
        [ Reverse Proxy & API Gateway ] &bull; Rate Limiting &bull; Tenant Resolution Middleware &bull; CORS<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&bull; (JWT Bearer Token with Embedded Institutional Claims)<br>
        [ Node.js / Express Core ] &bull; Attendance Engine &bull; Analytics &bull; Roster &bull; Materials<br>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&bull; (Strict Tenant Scope: WHERE college_id = auth_college_id)<br>
        [ Supabase PostgreSQL 15 ] &bull; Multi-Tenant Database &bull; Row-Level Security &bull; Temporal Indices
      </div>
    </div>

    <h3>Technology Matrix</h3>
    <table>
      <thead>
        <tr>
          <th>Layer</th>
          <th>Technology</th>
          <th>Version</th>
          <th>Key Architectural Function</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Mobile Application</strong></td>
          <td>Flutter / Dart</td>
          <td>3.x / 3.29</td>
          <td>Cross-platform native UI, QR scanner camera integration, offline-aware cache, adaptive responsive layouts (supporting compact 320px screens up to large tablets).</td>
        </tr>
        <tr>
          <td><strong>Backend API Core</strong></td>
          <td>Node.js / Express / TypeScript</td>
          <td>20 LTS / 5.x</td>
          <td>Type-safe REST API server, temporal window calculation, cryptographic QR token verification, JWT authentication, and automated audit logging.</td>
        </tr>
        <tr>
          <td><strong>Relational Database</strong></td>
          <td>PostgreSQL / Supabase</td>
          <td>15.x</td>
          <td>Multi-tenant schema, strict foreign-key integrity, indexed attendance timestamps with `Asia/Kolkata` time zone casting.</td>
        </tr>
        <tr>
          <td><strong>Edge & Tunneling</strong></td>
          <td>Cloudflare Zero Trust</td>
          <td>Managed</td>
          <td>Encrypted outbound tunnel protecting backend origins, DDoS mitigation, public HTTPS termination (`*.trycloudflare.com`), and low-latency asset delivery.</td>
        </tr>
      </tbody>
    </table>

    <h2>3. Institutional Confidentiality & Tenant Isolation Guarantees</h2>
    <p>
      In educational consortiums and multi-campus setups, cross-institutional data leakage is a critical compliance violation. Cognito Tech Hub enforces <strong>Zero Data Bleed</strong> between partner colleges:
    </p>

    <div class="grid-2" style="margin-top: 8px;">
      <div class="card">
        <h3 style="margin-top: 0; color: #0F172A;">1. Token-Derived Identity Resolution</h3>
        <p style="font-size: 8pt;">
          College Admins and TPOs have their institutional <code>college_id</code> signed directly into their cryptographic JWT session. Any attempt by client requests to pass spoofed <code>?college_id=...</code> query parameters is immediately intercepted and overridden by the backend tenant middleware.
        </p>
      </div>
      <div class="card">
        <h3 style="margin-top: 0; color: #0F172A;">2. Roster & Nominal Roll Isolation</h3>
        <p style="font-size: 8pt;">
          Adarsh Engineering College administrators can only query students with <code>college_id = 'ADARSH'</code> (e.g. Roll 21HN1A5401). External campus administrators can only view their own registered campus rosters. Multi-campus cross-listing is strictly prohibited at the query level.
        </p>
      </div>
      <div class="card">
        <h3 style="margin-top: 0; color: #0F172A;">3. Scoped Faculty & Trainer Allocation</h3>
        <p style="font-size: 8pt;">
          Trainers assigned to an institution are scoped solely to that campus. Faculty allocations and evaluations for other universities remain completely inaccessible.
        </p>
      </div>
      <div class="card">
        <h3 style="margin-top: 0; color: #0F172A;">4. Campus Notice Broadcast Isolation</h3>
        <p style="font-size: 8pt;">
          Notices posted by an institutional TPO are broadcast strictly to students enrolled in that specific institution. Institutional announcements never leak across campus boundaries.
        </p>
      </div>
    </div>

    <div class="page-footer">
      <div>Cognito Tech Hub &bull; Confidential Official Specification</div>
      <div>Page 2 of 6</div>
    </div>
  </div>

  <!-- ==================== PAGE 3: ATTENDANCE ENGINE ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">COGNITO TECH HUB &bull; ATTENDANCE OPERATING ENGINE</div>
      <div>DOC REF: CTH-SPEC-2026-V2.4</div>
    </div>

    <h2>4. The Daily Attendance Engine (09:00 AM – 04:00 PM IST)</h2>
    <p>
      The core innovation in the latest release is the strict daily working hours attendance window and the total elimination of rolling 24-hour lockouts.
    </p>

    <div class="card-highlight" style="margin-bottom: 12px;">
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <strong style="color: #15803D; font-size: 9.5pt;">CORE BUSINESS RULE SPECIFICATION</strong>
        <span class="badge badge-green">STRICT ENFORCEMENT</span>
      </div>
      <p style="margin: 6px 0 0 0; font-size: 8.3pt; color: #166534;">
        &bull; <strong>Operating Window:</strong> Attendance is strictly active between <strong>09:00:00 AM</strong> and <strong>04:00:00 PM IST</strong>.<br>
        &bull; <strong>Day-Scoped Calendar Reset:</strong> Attendance uniqueness is strictly evaluated against the calendar date <code>(marked_at AT TIME ZONE 'Asia/Kolkata')::DATE = CURRENT_DATE</code>. No 24-hour rolling delay.<br>
        &bull; <strong>After 04:00 PM:</strong> The attendance scanning bar is completely hidden; students receive an amber timeout notification.<br>
        &bull; <strong>Next Morning 09:00 AM:</strong> The attendance bar reopens automatically for the new calendar day.
      </p>
    </div>

    <div class="grid-2" style="margin-bottom: 12px;">
      <div>
        <h3>Dynamic 3-State Lifecycle</h3>
        <div class="flow-step">
          <strong>1. NOT_OPEN_YET (Before 09:00 AM)</strong><br>
          <span style="font-size: 7.8pt; color: #64748B;">Displays an indigo card: <em>"Attendance Opens at 09:00 AM. Scanner activates at 09:00 AM."</em> QR button is hidden.</span>
        </div>
        <div class="flow-step" style="border-left-color: #10B981;">
          <strong>2. OPEN (09:00 AM to 04:00 PM IST)</strong><br>
          <span style="font-size: 7.8pt; color: #64748B;">Active window. Unmarked students see <strong>"SCAN ATTENDANCE QR"</strong>. Marked students see <strong>"TODAY'S ATTENDANCE COMPLETED"</strong>.</span>
        </div>
        <div class="flow-step" style="border-left-color: #F59E0B;">
          <strong>3. TIMED_OUT (04:00 PM Onward)</strong><br>
          <span style="font-size: 7.8pt; color: #64748B;">The attendance bar and scan button are hidden. Displays amber card: <em>"Attendance bar reopens tomorrow morning at 09:00 AM."</em></span>
        </div>

        <h3 style="margin-top: 10px;">Backend Clamping Security</h3>
        <p style="font-size: 8pt;">
          Even if a trainer or administrator generates a classroom QR slot late in the afternoon (e.g., at 03:30 PM with a 2-hour duration), the backend function <code>clampSlotExpiryTo4PM()</code> automatically clamps the slot expiration to <strong>04:00:00 PM IST sharp</strong>. No QR token remains valid after 4:00 PM.
        </p>
      </div>

      <div class="phone-mockup">
        <img src="{img_student_home}" alt="Student Dashboard Live Active Attendance">
        <div class="caption">Figure 1: Live Student Dashboard during 09:00 AM – 04:00 PM IST window showing verified attendance completion.</div>
      </div>
    </div>

    <h3>Technical Implementation Details</h3>
    <table>
      <thead>
        <tr>
          <th>Component</th>
          <th>Implementation Code</th>
          <th>Behavior</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><code>timeWindow.ts</code></td>
          <td><code>isWithinAttendanceWindow(now)</code></td>
          <td>Evaluates current Indian Standard Time (UTC+05:30). Returns <code>true</code> strictly when hour &ge; 9 and hour &lt; 16.</td>
        </tr>
        <tr>
          <td><code>attendance.routes.ts</code></td>
          <td><code>POST /api/attendance/mark</code></td>
          <td>Rejects submissions outside 9AM-4PM with <code>400 Bad Request</code> and message <em>"Attendance is closed. Working hours are 09:00 AM to 04:00 PM."</em></td>
        </tr>
        <tr>
          <td><code>student_dashboard_screen.dart</code></td>
          <td><code>Timer.periodic(30s)</code></td>
          <td>Real-time 30-second timer re-evaluates the window. At 04:00:00 PM, the screen transitions automatically without requiring app restart.</td>
        </tr>
      </tbody>
    </table>

    <div class="page-footer">
      <div>Cognito Tech Hub &bull; Confidential Official Specification</div>
      <div>Page 3 of 6</div>
    </div>
  </div>

  <!-- ==================== PAGE 4: STUDENT PORTAL ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">COGNITO TECH HUB &bull; STUDENT USER EXPERIENCE</div>
      <div>DOC REF: CTH-SPEC-2026-V2.4</div>
    </div>

    <h2>5. Student Mobile App Experience</h2>
    <p>
      The student application is built for intuitive single-tap navigation, verifiable accountability, and immediate access to academic and placement resources.
    </p>

    <div class="grid-3" style="margin-bottom: 12px;">
      <div class="phone-mockup">
        <img src="{img_student_home}" alt="Student Home">
        <div class="caption">Fig 2.1: Classroom Session Card</div>
      </div>
      <div class="phone-mockup">
        <img src="{img_student_att}" alt="Attendance Tab">
        <div class="caption">Fig 2.2: Attendance Analytics Tab</div>
      </div>
      <div class="phone-mockup">
        <img src="{img_student_beh}" alt="Behaviour Tab">
        <div class="caption">Fig 2.3: Behavioral Metrics Tab</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="card">
        <h3 style="margin-top: 0; color: #1D4ED8;">Student Navigation Hubs</h3>
        <ul>
          <li><strong>Home Hub (Tab 0):</strong> Displays active classroom slot, assigned trainer details, today's attendance badge, and institutional affiliation notice.</li>
          <li><strong>Attendance Hub (Tab 1):</strong> Complete month-wise attendance register, aggregate percentage score, presence consistency streak, and verified session logs.</li>
          <li><strong>Study Hub (Tab 2):</strong> Digital repository of lecture handouts, PDF notes, coding reference sheets, and curriculum slide decks.</li>
          <li><strong>Behaviour Hub (Tab 3):</strong> Real-time feedback from trainers scoring classroom punctuality, technical problem solving, teamwork, and engagement.</li>
          <li><strong>Profile Hub (Tab 4):</strong> Official digital Student Identity Card with roll number, branch, academic year, and college affiliation emblem.</li>
        </ul>
      </div>

      <div class="card">
        <h3 style="margin-top: 0; color: #047857;">Security & Device Safeguards</h3>
        <ul>
          <li><strong>Hardware Camera Scanner:</strong> Embedded native camera barcode scanner utilizing ML-powered autofocus and edge detection.</li>
          <li><strong>Anti-Proxy Lock:</strong> One mark per student per calendar day. Scans are cryptographically signed with the authenticated user ID and device timestamp.</li>
          <li><strong>Network Resiliency:</strong> Automatic retry with exponential backoff on flaky campus Wi-Fi or low cellular coverage.</li>
          <li><strong>Responsive Ergonomics:</strong> Tested and validated to render flawlessly on compact 320x640 screens without text wrapping or layout overflow.</li>
        </ul>
      </div>
    </div>

    <div class="page-footer">
      <div>Cognito Tech Hub &bull; Confidential Official Specification</div>
      <div>Page 4 of 6</div>
    </div>
  </div>

  <!-- ==================== PAGE 5: FACULTY & TPO PORTALS ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">COGNITO TECH HUB &bull; FACULTY & INSTITUTIONAL PORTALS</div>
      <div>DOC REF: CTH-SPEC-2026-V2.4</div>
    </div>

    <h2>6. Faculty Trainer Portal</h2>
    <p>
      Trainers and technical instructors use a dedicated, role-authorized interface to manage sessions, project dynamic QR tokens, review attendance in real time, and upload learning handouts.
    </p>

    <div class="grid-2" style="margin-bottom: 12px;">
      <div>
        <h3>Key Trainer Capabilities</h3>
        <ul>
          <li><strong>Dynamic QR Token Generator:</strong> Creates time-bounded attendance QR codes projected on classroom smart-screens or projector displays.</li>
          <li><strong>Operating Hours Templates:</strong> Built-in standardized slots aligned with official hours:
            <ul>
              <li>Morning Technical Slot (09:00 AM – 01:00 PM)</li>
              <li>Afternoon Hands-on Slot (01:00 PM – 04:00 PM)</li>
              <li>Full Day Intensive Bootcamp (09:00 AM – 04:00 PM)</li>
            </ul>
          </li>
          <li><strong>Manual Attendance Override:</strong> Allows instructors to manually mark or excuse students experiencing hardware/camera issues.</li>
          <li><strong>End-of-Day (EOD) Reports:</strong> Summary of topics taught, student turnout rate, and assignment milestones logged directly to college management.</li>
        </ul>
      </div>

      <div class="phone-mockup">
        <img src="{img_trainer_qr}" alt="Trainer QR Generator">
        <div class="caption">Figure 3: Trainer Dynamic Classroom QR Code Generator with real-time countdown timer.</div>
      </div>
    </div>

    <h2>7. Institutional TPO & College Admin Portal</h2>
    <p>
      The Training & Placement Officer (TPO) and College Admin interface provides confidential oversight of all enrolled students, assigned instructors, and placement readiness metrics.
    </p>

    <div class="grid-2" style="margin-top: 8px;">
      <div class="phone-mockup">
        <img src="{img_tpo}" alt="TPO Institutional Dashboard">
        <div class="caption">Figure 4: TPO Institutional Dashboard strictly isolated to campus roster and faculty.</div>
      </div>

      <div>
        <h3>Institutional Portal Modules</h3>
        <ul>
          <li><strong>"My Campus" Overview (Tab 0):</strong> Campus emblem, total student count enrolled at this institution, active campus batches, and assigned faculty roster.</li>
          <li><strong>Department Nominal Register (Tab 1):</strong> Quick departmental filtering chips (<code>CSE</code>, <code>ECE</code>, <code>MECH</code>, <code>CIVIL</code>, <code>AIDS</code>, <code>IT</code>) with individual student attendance percentages and contact records.</li>
          <li><strong>Faculty Roster (Tab 2):</strong> Institutional view of assigned technical trainers and their classroom evaluation metrics.</li>
          <li><strong>Campus Notice Board:</strong> Instant broadcast tool to deliver important campus announcements and placement drive schedules.</li>
          <li><strong>Export Nominal Roll:</strong> One-click export of complete student nominal registers to CSV or Excel for university compliance audits.</li>
        </ul>
      </div>
    </div>

    <div class="page-footer">
      <div>Cognito Tech Hub &bull; Confidential Official Specification</div>
      <div>Page 5 of 6</div>
    </div>
  </div>

  <!-- ==================== PAGE 6: DEPLOYMENT & DOWNLOAD ==================== -->
  <div class="page">
    <div class="page-header">
      <div class="brand">COGNITO TECH HUB &bull; DEPLOYMENT & DOWNLOAD GUIDE</div>
      <div>DOC REF: CTH-SPEC-2026-V2.4</div>
    </div>

    <h2>8. Technical & Build Specifications</h2>
    <table>
      <thead>
        <tr>
          <th>Parameter</th>
          <th>Specification</th>
          <th>Notes</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Application Name</strong></td>
          <td>Cognito Tech Hub</td>
          <td>Official partner app for autonomous campus technical training.</td>
        </tr>
        <tr>
          <td><strong>Package Identifier</strong></td>
          <td><code>com.cognitoinsights.techhub.cognito_techhub</code></td>
          <td>Unique Android Application ID.</td>
        </tr>
        <tr>
          <td><strong>Target Operating System</strong></td>
          <td>Android 5.0 (API 21) up to Android 15 (API 35)</td>
          <td>Broad device compatibility across student smartphones.</td>
        </tr>
        <tr>
          <td><strong>Release Artifact</strong></td>
          <td><code>app-release.apk</code> (74.4 MB)</td>
          <td>Compiled with full optimization, icon tree-shaking (98.6% reduction), and release ProGuard rules.</td>
        </tr>
        <tr>
          <td><strong>Backend Port & Host</strong></td>
          <td>Port <code>5050</code> &bull; <code>http://192.168.6.200:5050</code></td>
          <td>Node.js TypeScript runtime.</td>
        </tr>
        <tr>
          <td><strong>Cloud Tunnel</strong></td>
          <td>Cloudflare Zero Trust (Outbound HTTPS)</td>
          <td>Encrypted edge proxy terminating at <code>*.trycloudflare.com</code>.</td>
        </tr>
      </tbody>
    </table>

    <h2>9. Production Download & Installation Links</h2>
    <p>
      The verified release APK and all associated backend services are live and available for immediate download and deployment:
    </p>

    <div class="download-box">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
        <strong style="color: #1D4ED8; font-size: 9pt;">DIRECT RELEASE APK DOWNLOAD (HTTPS CLOUDFLARE)</strong>
        <span class="badge badge-blue">RECOMMENDED &bull; SECURE</span>
      </div>
      <div style="margin-bottom: 8px;">
        <a href="https://placed-settlement-overview-virginia.trycloudflare.com/uploads/app-release.apk">
          https://placed-settlement-overview-virginia.trycloudflare.com/uploads/app-release.apk
        </a>
      </div>
      <div style="font-size: 7.8pt; color: #475569;">
        Accessible from any Android mobile browser worldwide. Download and tap to install (enable "Install unknown apps" if prompted).
      </div>
    </div>

    <div class="download-box" style="background: #F8FAFC; border-color: #94A3B8; margin-top: 8px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
        <strong style="color: #0F172A; font-size: 8.5pt;">LOCAL CAMPUS LAN DOWNLOAD (ON-PREMISE)</strong>
        <span class="badge badge-dark">CAMPUS NETWORK</span>
      </div>
      <div style="margin-bottom: 4px;">
        <a href="http://192.168.6.200:5050/uploads/app-release.apk" style="color: #0F172A;">
          http://192.168.6.200:5050/uploads/app-release.apk
        </a>
      </div>
      <div style="font-size: 7.5pt; color: #64748B;">
        Direct high-speed LAN download when connected to the campus Wi-Fi network.
      </div>
    </div>

    <h2>10. Installation & Setup Instructions</h2>
    <div class="grid-3" style="margin-top: 8px;">
      <div class="card">
        <strong>Step 1: Download</strong>
        <p style="font-size: 7.8pt; margin-top: 3px;">
          Open the download link in Chrome or any mobile browser on your Android device. The 74.4 MB APK will download directly.
        </p>
      </div>
      <div class="card">
        <strong>Step 2: Install</strong>
        <p style="font-size: 7.8pt; margin-top: 3px;">
          Tap the downloaded file. When prompted by Android, grant permission to "Install Unknown Apps" for your browser.
        </p>
      </div>
      <div class="card">
        <strong>Step 3: Login</strong>
        <p style="font-size: 7.8pt; margin-top: 3px;">
          Launch Cognito Tech Hub. Log in with your assigned institutional roll number/email and password to access your dashboard.
        </p>
      </div>
    </div>

    <div style="margin-top: 20px; padding: 12px; background: #F1F5F9; border-radius: 8px; font-size: 7.5pt; color: #475569; text-align: center;">
      <strong>Cognito Tech Hub &bull; Cognito Insights Private Limited</strong><br>
      Confidential Enterprise Documentation &bull; For Campus Distribution &bull; All Rights Reserved &copy; 2026
    </div>

    <div class="page-footer">
      <div>Cognito Tech Hub &bull; Confidential Official Specification</div>
      <div>Page 6 of 6</div>
    </div>
  </div>

</body>
</html>
"""
    return html

def main():
    html_content = generate_html()
    html_path = "/tmp/cognito_tech_hub_app_description.html"
    pdf_dest1 = "/Users/satyaalugolu/Desktop/Tech Hub/Cognito_Tech_Hub_App_Description.pdf"
    pdf_dest2 = "/Users/satyaalugolu/Desktop/Tech Hub/backend/uploads/Cognito_Tech_Hub_App_Description.pdf"
    pdf_dest3 = "/Users/satyaalugolu/.gemini/antigravity-ide/brain/2b8c0e6a-05d9-4dbe-bf54-758a9085d448/Cognito_Tech_Hub_App_Description.pdf"

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
        # Copy to destinations
        import shutil
        shutil.copyfile(pdf_dest1, pdf_dest2)
        shutil.copyfile(pdf_dest1, pdf_dest3)
        print(f"Copied to: {pdf_dest2} and {pdf_dest3}")
    else:
        print("Error: PDF was not generated!")

if __name__ == "__main__":
    main()
