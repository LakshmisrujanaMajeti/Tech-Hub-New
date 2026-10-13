import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getStudentAttendance();
      setState(() => _attendanceData = data);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _attendanceData['summary'] ?? {};
    final overall = summary['overallPercentage'] ?? 0;
    final present = summary['presentCount'] ?? 0;
    final absent = summary['absentCount'] ?? 0;
    final total = summary['totalSessions'] ?? 0;
    final subjects = (_attendanceData['subjects'] as List?) ?? [];

    return Scaffold(
      backgroundColor: CognitoColors.background,
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overall Percentage Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [CognitoColors.darkBlue, CognitoColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: CognitoColors.primary.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'OVERALL ATTENDANCE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$overall',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                '%',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    total == 0
                                        ? 'New Enrollment • Fresh Record'
                                        : (overall >= 75 ? 'Meets Placement Eligibility (≥75%)' : 'Needs Improvement (<75%)'),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Counts Grid
                    Row(
                      children: [
                        Expanded(
                          child: _statCard('Present', '$present', CognitoColors.success, Icons.check_circle_outline),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard('Absent', '$absent', CognitoColors.danger, Icons.cancel_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard('Total Sessions', '$total', CognitoColors.darkBlue, Icons.calendar_today_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Subject Breakdown
                    const Text(
                      'Program & Subject Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                    ),
                    const SizedBox(height: 12),

                    if (subjects.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CognitoColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.event_available_outlined, size: 44, color: CognitoColors.textSecondary),
                            SizedBox(height: 12),
                            Text(
                              'No Attendance Records Yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: CognitoColors.textDark),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Your classroom session attendance will begin recording and reflecting here once marked by your course trainers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      )
                    else
                      ...subjects.map((sub) {
                      final name = sub['subject'] ?? 'Subject';
                      final pct = (sub['percentage'] ?? 90).toInt();
                      final att = sub['attended'] ?? 0;
                      final tot = sub['total'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CognitoColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                                  ),
                                ),
                                Text(
                                  '$pct%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: pct >= 80 ? CognitoColors.primary : CognitoColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$att of $tot sessions attended',
                              style: const TextStyle(color: CognitoColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                minHeight: 7,
                                backgroundColor: CognitoColors.lightBlue,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  pct >= 80 ? CognitoColors.primary : CognitoColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // Attendance History & Session Log
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attendance History & Session Log',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            '${((_attendanceData['history'] as List?) ?? []).length} Logged',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Builder(builder: (_) {
                      final history = ((_attendanceData['history'] as List?) ?? []);
                      if (history.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: CognitoColors.border),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 36, color: CognitoColors.textSecondary),
                              SizedBox(height: 10),
                              Text(
                                'No Check-in History Recorded Yet',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: CognitoColors.textDark),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Scan the dynamic QR code displayed during your scheduled classroom hours (09:00 AM - 04:00 PM) to record attendance history.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: CognitoColors.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: history.map((record) {
                          final title = record['session_title'] ?? record['title'] ?? 'Technical Hub Training Session';
                          final markedAt = (record['marked_at'] ?? record['session_date'] ?? '').toString();
                          final status = (record['status'] ?? 'PRESENT').toString().toUpperCase();
                          final isPresent = status == 'PRESENT';
                          final method = (record['method'] ?? 'QR_SCAN').toString().toUpperCase();

                          String formattedDate = markedAt;
                          String formattedTime = '';
                          if (markedAt.contains('T')) {
                            final parts = markedAt.split('T');
                            formattedDate = parts[0];
                            if (parts.length > 1) {
                              formattedTime = parts[1].length >= 8 ? parts[1].substring(0, 8) : parts[1];
                            }
                          } else if (markedAt.contains(' ')) {
                            final parts = markedAt.split(' ');
                            formattedDate = parts[0];
                            if (parts.length > 1) formattedTime = parts[1];
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isPresent ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPresent ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: isPresent ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: CognitoColors.textDark),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(
                                            formattedDate + (formattedTime.isNotEmpty ? ' • $formattedTime' : ''),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: isPresent ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      method == 'QR_SCAN' ? '⚡ QR Verified' : method,
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CognitoColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
