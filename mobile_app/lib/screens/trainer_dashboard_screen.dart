import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'login_screen.dart';

class TrainerDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const TrainerDashboardScreen({super.key, required this.userProfile});

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  int _selectedTab = 0; // 0: Sessions, 1: My Students, 2: Daily QR, 3: Materials, 4: EOD Reports
  bool _isLoading = true;
  bool _isMarkingAttendance = false;

  List<dynamic> _sessions = [];
  Map<String, dynamic>? _attendanceToday;
  Map<String, dynamic>? _trainerProfile;
  List<dynamic> _dailyReports = [];
  List<dynamic> _materials = [];
  List<dynamic> _quizzes = [];
  String _quizFilter = 'ALL'; // 'ALL', 'PUBLISHED', 'DRAFT'

  // Scoped Students
  List<dynamic> _scopedStudents = [];
  Map<String, dynamic> _scopedSummary = {};
  String _studentSearchQuery = '';
  String _studentBranchFilter = 'ALL';

  void _openExternalUrl(String url) async {
    if (url.trim().isEmpty) return;
    final cleanUrl = url.trim().startsWith('http://') || url.trim().startsWith('https://')
        ? url.trim()
        : 'https://${url.trim()}';
    final uri = Uri.parse(cleanUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open external link.')),
      );
    }
  }

  String _formatQuizDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute $ampm';
    } catch (_) {
      return dateStr.toString().split('T').first;
    }
  }

  // Daily QR Slot
  List<dynamic> _todaySlots = [];
  Map<String, dynamic>? _activeQrSlot;
  Timer? _slotCountdownTimer;
  int _slotSecondsRemaining = 0;
  bool _isGeneratingSlot = false;
  String _selectedSlotName = 'Morning Technical Slot (09:00 AM - 01:00 PM)';
  String _selectedSlotDuration = '30';

  @override
  void initState() {
    super.initState();
    _loadAllTrainerData();
  }

  @override
  void dispose() {
    _slotCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllTrainerData() async {
    setState(() => _isLoading = true);
    try {
      final collegeId = widget.userProfile['college_id'] ??
          widget.userProfile['collegeId'] ??
          widget.userProfile['college']?['id'];
      final results = await Future.wait([
        ApiService.getTodaySessions(),
        ApiService.getTrainerAttendanceToday(),
        ApiService.getTrainerProfile(),
        ApiService.getTrainerDailyReports(),
        ApiService.getMaterials(),
        ApiService.getTrainerScopedStudents(),
        ApiService.getTodayAttendanceSlots(collegeId: collegeId),
        ApiService.getQuizzes(),
      ]);

      if (mounted) {
        setState(() {
          _sessions = results[0] as List<dynamic>;
          _attendanceToday = results[1] as Map<String, dynamic>?;
          _trainerProfile = results[2] as Map<String, dynamic>?;
          _dailyReports = results[3] as List<dynamic>;
          _materials = results[4] as List<dynamic>;

          final studentsRes = results[5] as Map<String, dynamic>;
          _scopedStudents = studentsRes['students'] ?? [];
          _scopedSummary = studentsRes['summary'] ?? {};

          _todaySlots = results[6] as List<dynamic>;
          // QR is generated/displayed only when the trainer explicitly clicks GENERATE or Show QR

          _quizzes = results[7] as List<dynamic>;

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startSlotTimer() {
    _slotCountdownTimer?.cancel();
    if (_activeQrSlot == null) return;

    final expiresAtStr = _activeQrSlot!['validUntil'] ??
        _activeQrSlot!['valid_until'] ??
        _activeQrSlot!['expires_at'] ??
        _activeQrSlot!['expiresAt'];

    final durationMins = int.tryParse(_selectedSlotDuration) ?? 30;

    if (expiresAtStr != null) {
      final expiresAt = DateTime.tryParse(expiresAtStr.toString());
      if (expiresAt != null) {
        final diff = expiresAt.toUtc().difference(DateTime.now().toUtc()).inSeconds;
        _slotSecondsRemaining = diff > 0 ? diff : durationMins * 60;
      } else {
        _slotSecondsRemaining = durationMins * 60;
      }
    } else {
      _slotSecondsRemaining = durationMins * 60;
    }

    _slotCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_slotSecondsRemaining > 0) {
          _slotSecondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _generateDailySlotQr() async {
    setState(() => _isGeneratingSlot = true);
    try {
      final durationMins = int.tryParse(_selectedSlotDuration) ?? 30;
      final collegeId = widget.userProfile['college_id'] ?? widget.userProfile['collegeId'];

      final slotRes = await ApiService.generateAttendanceSlotQr({
        'slotName': _selectedSlotName,
        'validityMinutes': durationMins,
        'collegeId': collegeId,
      });

      if (!mounted) return;
      setState(() {
        _activeQrSlot = slotRes['slot'];
        _isGeneratingSlot = false;
      });
      _startSlotTimer();

      // Refresh today slots list
      final slots = await ApiService.getTodayAttendanceSlots(collegeId: collegeId);
      if (mounted) {
        setState(() => _todaySlots = slots);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(slotRes['message'] ?? 'Classroom QR Attendance code generated! Valid for $durationMins mins.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingSlot = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate slot: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: CognitoColors.danger,
        ),
      );
    }
  }

  Future<void> _handleMarkAttendance() async {
    setState(() => _isMarkingAttendance = true);
    try {
      final result = await ApiService.markTrainerAttendance(
        deviceInfo: 'Cognito Mobile Engine (Android/iOS)',
        locationNotes: 'Campus Technical Lab Instruction Session',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Attendance marked successfully as PRESENT!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _loadAllTrainerData();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance Notice: ${err.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: CognitoColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMarkingAttendance = false);
    }
  }

  Future<void> _handleMarkStudentManual(Map<String, dynamic> st) async {
    final studentId = (st['student_id'] ?? st['id'])?.toString();
    final studentName = st['full_name'] ?? 'Student';
    final roll = (st['roll_number'] ?? '').toString();
    if (studentId == null) return;

    // Optimistic UI state update
    setState(() {
      st['attendance_status'] = 'PRESENT';
      st['today_status'] = 'PRESENT';
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      st['check_in_time'] = timeStr;
      st['marked_time'] = timeStr;

      final pCount = _scopedStudents.where((s) => s['attendance_status'] == 'PRESENT' || s['today_status'] == 'PRESENT').length;
      _scopedSummary['presentToday'] = pCount;
      _scopedSummary['totalPresent'] = pCount;
      _scopedSummary['notMarkedToday'] = _scopedStudents.length - pCount;
    });

    try {
      final res = await ApiService.markManualAttendance(
        studentId: studentId,
        rollNumber: roll,
        status: 'PRESENT',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Marked $studentName as PRESENT!'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadAllTrainerData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance updated: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _loadAllTrainerData();
    }
  }

  Future<void> _handleMarkAllPresent() async {
    final unmarkedIds = _scopedStudents
        .where((s) => s['attendance_status'] != 'PRESENT' && s['today_status'] != 'PRESENT')
        .map((s) => (s['student_id'] ?? s['id']).toString())
        .toList();

    if (unmarkedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All enrolled students in this session are already marked PRESENT!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark All as Present?'),
        content: Text('Record verified presence for ${unmarkedIds.length} students in today\'s session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Mark All Present'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistic UI state update
    setState(() {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      for (final s in _scopedStudents) {
        s['attendance_status'] = 'PRESENT';
        s['today_status'] = 'PRESENT';
        s['check_in_time'] ??= timeStr;
        s['marked_time'] ??= timeStr;
      }
      _scopedSummary['presentToday'] = _scopedStudents.length;
      _scopedSummary['totalPresent'] = _scopedStudents.length;
      _scopedSummary['notMarkedToday'] = 0;
    });

    try {
      final res = await ApiService.markManualAttendanceBulk(studentIds: unmarkedIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Successfully marked attendance!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _loadAllTrainerData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk attendance updated: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _loadAllTrainerData();
    }
  }

  void _showStudentProfileModal(String studentId) {
    if (studentId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: ApiService.getStudentProfile(studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: CognitoColors.primary),
                  ),
                );
              }

              final data = snapshot.data;
              final student = data?['student'] as Map<String, dynamic>?;
              final attendance = data?['attendance'] as Map<String, dynamic>?;
              final history = (attendance?['history'] as List<dynamic>?) ?? [];

              if (student == null) {
                return const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Student details unavailable.')));
              }

              final name = student['full_name'] ?? 'Student Profile';
              final roll = student['roll_number'] ?? '';
              final college = student['college_name'] ?? '';
              final fullCollege = student['full_college_name'] ?? college;
              final branch = student['branch'] ?? '';
              final year = student['year'] ?? '';
              final sec = student['section'] ?? '';
              final email = student['email'] ?? '';
              final mobile = student['mobile'] ?? 'Not Provided';
              final aadhar = student['aadhar_id'] ?? 'Not Linked';
              final address = student['address'] ?? 'Not Specified';
              final dob = student['date_of_birth']?.toString().split('T').first ?? 'Not Specified';
              final gender = student['gender'] ?? 'Not Specified';

              final attPercent = attendance?['attendancePercentage']?.toString() ?? '90';
              final totalSess = attendance?['totalSessions']?.toString() ?? '0';
              final presentSess = attendance?['presentCount']?.toString() ?? '0';
              final absentSess = attendance?['absentCount']?.toString() ?? '0';

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: CognitoColors.primary.withOpacity(0.1),
                        child: Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CognitoColors.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                            const SizedBox(height: 2),
                            Text('$roll • $branch • $year ($sec)', style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(fullCollege, style: const TextStyle(fontSize: 12, color: CognitoColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTrainerStudentMetric('Overall Rate', '$attPercent%', const Color(0xFF16A34A)),
                        _buildTrainerStudentMetric('Total', totalSess, CognitoColors.primary),
                        _buildTrainerStudentMetric('Present', presentSess, const Color(0xFF0F766E)),
                        _buildTrainerStudentMetric('Absent', absentSess, const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Personal & Academic Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                  const SizedBox(height: 10),
                  _buildTrainerStudentRow('Email Address', email, Icons.email_outlined),
                  _buildTrainerStudentRow('Contact Phone', mobile, Icons.phone_outlined),
                  _buildTrainerStudentRow('Date of Birth', dob, Icons.cake_outlined),
                  _buildTrainerStudentRow('Gender Identity', gender, Icons.person_outline),
                  _buildTrainerStudentRow('Aadhar Number', aadhar, Icons.badge_outlined),
                  _buildTrainerStudentRow('Residential Address', address, Icons.home_outlined),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Attendance Records', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                      Text('${history.length} Sessions Logged', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('No attendance recorded for this student yet.', style: TextStyle(color: Colors.grey, fontSize: 12))),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, hIdx) {
                        final h = history[hIdx];
                        final hStatus = (h['status'] ?? 'PRESENT').toString().toUpperCase();
                        final isP = hStatus == 'PRESENT';
                        final sessionTitle = h['session_title'] ?? 'Technical Session';
                        final sessionDate = h['session_date'] ?? '';
                        final markedAt = h['marked_at'] ?? '';
                        final method = h['method'] ?? 'QR_SCAN';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sessionTitle, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                                  const SizedBox(height: 2),
                                  Text('$sessionDate • $markedAt ($method)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isP ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hStatus,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isP ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleMarkStudentManual(student);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Mark Student Present Today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerStudentMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTrainerStudentRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _showSubmitEodReportModal() {
    final assignments = (_trainerProfile?['assignments'] as List?) ?? [];
    final firstAssn = assignments.isNotEmpty ? assignments[0] : null;

    final defaultCourse = firstAssn?['course_name'] ?? 'Java Full Stack';
    final courseController = TextEditingController(text: defaultCourse);
    final topicsController = TextEditingController();
    final studentsPresentController = TextEditingController(text: '45');
    final challengesController = TextEditingController();
    final planController = TextEditingController();

    String selectedYear = (firstAssn?['target_years'] != null && (firstAssn['target_years'] as List).isNotEmpty)
        ? firstAssn['target_years'][0]
        : '3rd Year';

    String selectedBranch = (firstAssn?['target_branches'] != null && (firstAssn['target_branches'] as List).isNotEmpty)
        ? firstAssn['target_branches'][0]
        : 'CSE';

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_rounded, color: CognitoColors.primary, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Submit EOD Daily Report',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: CognitoColors.textSecondary),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Daily session review submitted to Super Admin & Program Managers.',
                  style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text('Course Track / Subject *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: courseController,
                  decoration: const InputDecoration(hintText: 'e.g. Java Full Stack'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Year *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedYear,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                            items: const [
                              DropdownMenuItem(value: '1st Year', child: Text('1st Year')),
                              DropdownMenuItem(value: '2nd Year', child: Text('2nd Year')),
                              DropdownMenuItem(value: '3rd Year', child: Text('3rd Year')),
                              DropdownMenuItem(value: '4th Year', child: Text('4th Year')),
                            ],
                            onChanged: (val) => setModalState(() => selectedYear = val ?? selectedYear),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Branch *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedBranch,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                            items: const [
                              DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                              DropdownMenuItem(value: 'AI&DS', child: Text('AI&DS')),
                              DropdownMenuItem(value: 'AIML', child: Text('AIML')),
                              DropdownMenuItem(value: 'CSE(DS)', child: Text('CSE(DS)')),
                              DropdownMenuItem(value: 'EEE', child: Text('EEE')),
                              DropdownMenuItem(value: 'ECE', child: Text('ECE')),
                              DropdownMenuItem(value: 'Agri', child: Text('Agri')),
                              DropdownMenuItem(value: 'Mechanical', child: Text('Mechanical')),
                              DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                              DropdownMenuItem(value: 'Others', child: Text('Others')),
                            ],
                            onChanged: (val) => setModalState(() => selectedBranch = val ?? selectedBranch),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Students Present in Session *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: studentsPresentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Number of attendees'),
                ),
                const SizedBox(height: 14),
                const Text('Topics Covered Today *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: topicsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Completed Java Collection Framework, practical lab on ArrayList and HashMap with student coding drills.',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Lab Activities & Challenges Faced', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: challengesController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Any lab system doubts, syntax hurdles, or network issues encountered'),
                ),
                const SizedBox(height: 14),
                const Text('Tomorrow\'s Planned Curriculum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: planController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'e.g. Streams API, Lambda Expressions, and Mini Project setup'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final topics = topicsController.text.trim();
                            if (topics.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Topics covered today cannot be empty.')),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.submitTrainerDailyReport({
                                'courseName': courseController.text.trim(),
                                'targetYear': selectedYear,
                                'targetBranch': selectedBranch,
                                'topicsCovered': topics,
                                'studentsPresent': int.tryParse(studentsPresentController.text.trim()) ?? 0,
                                'challengesFaced': challengesController.text.trim(),
                                'tomorrowPlan': planController.text.trim(),
                              });
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadAllTrainerData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('EOD Report submitted successfully to management!'),
                                  backgroundColor: Color(0xFF16A34A),
                                ),
                              );
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: CognitoColors.danger),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('SUBMIT END-OF-DAY REPORT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // UPLOAD STUDY MATERIAL (INTERNAL DEVICE STORAGE PICKER)
  // ==========================================
  void _showUploadMaterialModal() {
    final assignments = (_trainerProfile?['assignments'] as List?) ?? [];
    final firstAssn = assignments.isNotEmpty ? assignments[0] : null;

    final defaultCourse = firstAssn?['course_name'] ?? 'Java Full Stack';
    final titleController = TextEditingController();
    final courseController = TextEditingController(text: defaultCourse);
    final descController = TextEditingController();

    String selectedYear = (firstAssn?['target_years'] != null && (firstAssn['target_years'] as List).isNotEmpty)
        ? firstAssn['target_years'][0]
        : '3rd Year';

    String selectedBranch = (firstAssn?['target_branches'] != null && (firstAssn['target_branches'] as List).isNotEmpty)
        ? firstAssn['target_branches'][0]
        : 'CSE';

    PlatformFile? pickedFile;
    String? pickedFilePath;
    bool isPickingFile = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CognitoColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: CognitoColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Local Study Material',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                          ),
                          Text(
                            'Select document from phone storage (.pdf, .pptx, .docx)',
                            style: TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: CognitoColors.textSecondary),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Device Internal Storage File Picker Box
                const Text('Choose Local Document *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: isPickingFile
                      ? null
                      : () async {
                          setModalState(() => isPickingFile = true);
                          try {
                            final files = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'ppt', 'pptx', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip'],
                            );
                            if (files.isNotEmpty && files.first.path != null) {
                              setModalState(() {
                                pickedFile = files.first;
                                pickedFilePath = pickedFile!.path;
                                if (titleController.text.trim().isEmpty) {
                                  titleController.text = pickedFile!.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                                }
                              });
                            }
                          } catch (err) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('File selection error: $err'), backgroundColor: CognitoColors.danger),
                              );
                            }
                          } finally {
                            setModalState(() => isPickingFile = false);
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pickedFile != null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: pickedFile != null ? const Color(0xFF16A34A) : Colors.grey.shade300,
                        width: pickedFile != null ? 1.5 : 1,
                      ),
                    ),
                    child: pickedFile == null
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              isPickingFile
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.folder_open_rounded, color: CognitoColors.primary, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                isPickingFile ? 'Opening Storage...' : 'Tap to Pick Document from Storage',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: CognitoColors.primary, fontSize: 13),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.description_rounded, color: Color(0xFF16A34A), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pickedFile!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${((pickedFile!.lengthSync() ?? File(pickedFilePath!).lengthSync()) / (1024 * 1024)).toStringAsFixed(2)} MB • ${(pickedFile!.extension ?? 'DOC').toUpperCase()}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    pickedFile = null;
                                    pickedFilePath = null;
                                  });
                                },
                                child: const Text('Change', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Material Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: 'e.g. Module 3: Multithreading & Executors Notes'),
                ),
                const SizedBox(height: 14),

                const Text('Course Track *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: courseController,
                  decoration: const InputDecoration(hintText: 'e.g. Java Full Stack'),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Year *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedYear,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                            items: const [
                              DropdownMenuItem(value: '1st Year', child: Text('1st Year')),
                              DropdownMenuItem(value: '2nd Year', child: Text('2nd Year')),
                              DropdownMenuItem(value: '3rd Year', child: Text('3rd Year')),
                              DropdownMenuItem(value: '4th Year', child: Text('4th Year')),
                            ],
                            onChanged: (val) => setModalState(() => selectedYear = val ?? selectedYear),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Branch *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedBranch,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                            items: const [
                              DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                              DropdownMenuItem(value: 'AI&DS', child: Text('AI&DS')),
                              DropdownMenuItem(value: 'AIML', child: Text('AIML')),
                              DropdownMenuItem(value: 'CSE(DS)', child: Text('CSE(DS)')),
                              DropdownMenuItem(value: 'EEE', child: Text('EEE')),
                              DropdownMenuItem(value: 'ECE', child: Text('ECE')),
                              DropdownMenuItem(value: 'Agri', child: Text('Agri')),
                              DropdownMenuItem(value: 'Mechanical', child: Text('Mechanical')),
                              DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                              DropdownMenuItem(value: 'Others', child: Text('Others')),
                            ],
                            onChanged: (val) => setModalState(() => selectedBranch = val ?? selectedBranch),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Brief Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Key notes, lab reference sheets, code snippets, etc.'),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Material title is required.')),
                              );
                              return;
                            }
                            if (pickedFilePath == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please choose a document file from your device storage.')),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.uploadMaterialFile(
                                filePath: pickedFilePath!,
                                fields: {
                                  'title': title,
                                  'courseName': courseController.text.trim(),
                                  'targetYear': selectedYear,
                                  'targetBranch': selectedBranch,
                                  'targetBranches': selectedBranch,
                                  'description': descController.text.trim(),
                                },
                              );
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadAllTrainerData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Study Material published to target students!'),
                                  backgroundColor: Color(0xFF16A34A),
                                ),
                              );
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e'), backgroundColor: CognitoColors.danger),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('PUBLISH MATERIAL TO STUDENTS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainerName = widget.userProfile['full_name'] ??
        widget.userProfile['fullName'] ??
        _trainerProfile?['full_name'] ??
        _trainerProfile?['profile']?['full_name'] ??
        'Faculty Trainer';

    final collegeName = _trainerProfile?['college_name'] ??
        _trainerProfile?['profile']?['college_name'] ??
        _scopedSummary['collegeName'] ??
        widget.userProfile['college_name'] ??
        widget.userProfile['collegeName'] ??
        widget.userProfile['college']?['name'] ??
        widget.userProfile['college']?['shortName'] ??
        'Adarsh College of Engineering';

    final isAdarsh = collegeName.toString().toLowerCase().contains('adarsh');
    final isKits = collegeName.toString().toLowerCase().contains('kits');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: CognitoColors.primary.withOpacity(0.08),
              child: Image.asset(
                isAdarsh
                    ? 'assets/images/adharsh_logo.png'
                    : isKits
                        ? 'assets/images/kits_logo.png'
                        : 'assets/images/adharsh_logo.png',
                errorBuilder: (_, __, ___) => const Icon(Icons.school, color: CognitoColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trainerName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Faculty Portal • $collegeName',
                    style: const TextStyle(fontSize: 10, color: CognitoColors.primary, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CognitoColors.primary),
            tooltip: 'Reload',
            onPressed: _loadAllTrainerData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (idx) => setState(() => _selectedTab = idx),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: CognitoColors.primary,
          unselectedItemColor: Colors.grey.shade500,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Sessions'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'My Students'),
            BottomNavigationBarItem(icon: Icon(Icons.psychology_rounded), label: 'Daily Quiz'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_rounded), label: 'Daily QR'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Materials'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'EOD Reports'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CognitoColors.primary))
          : Stack(
              fit: StackFit.expand,
              children: [
                // Institutional Watermark in background
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.04,
                        child: Image.asset(
                          isAdarsh
                              ? 'assets/images/adharsh_logo.png'
                              : isKits
                                  ? 'assets/images/kits_logo.png'
                                  : 'assets/images/adharsh_logo.png',
                          width: 320,
                          height: 320,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),

                RefreshIndicator(
                  onRefresh: _loadAllTrainerData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mandatory Daily Attendance Card
                        _buildAttendanceStatusCard(),
                        const SizedBox(height: 16),

                        // Tab Content
                        if (_selectedTab == 0) ...[
                          _buildSessionsTab(),
                        ] else if (_selectedTab == 1) ...[
                          _buildMyStudentsTab(),
                        ] else if (_selectedTab == 2) ...[
                          _buildDailyQuizTab(),
                        ] else if (_selectedTab == 3) ...[
                          _buildDailyQrSlotTab(),
                        ] else if (_selectedTab == 4) ...[
                          _buildMaterialsTab(),
                        ] else ...[
                          _buildEodReportsTab(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAttendanceStatusCard() {
    final isCheckedIn = _attendanceToday?['checkedIn'] == true;
    final attData = _attendanceToday?['attendance'];

    if (isCheckedIn) {
      final time = attData != null && attData['check_in_time'] != null
          ? attData['check_in_time'].toString().substring(11, 16)
          : 'Today';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Faculty Attendance Logged: PRESENT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Checked in at $time • Status: Logged in Campus Tech Hub',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.access_time_filled_rounded, color: Colors.amber.shade900, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mandatory Daily Faculty Check-In',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mark technical attendance upon arriving at the campus tech hub.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isMarkingAttendance ? null : _handleMarkAttendance,
              icon: _isMarkingAttendance
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.fingerprint_rounded, size: 18),
              label: const Text('MARK DAILY ATTENDANCE NOW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: SESSIONS
  // ==========================================
  Widget _buildSessionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'TRAINER FACULTY SESSION',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 28),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Classroom Attendance Hub',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Project dynamic time-bound QR code for students to scan on their Cognito Tech Hub app.',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'TODAY\'S SCHEDULED SESSIONS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CognitoColors.textSecondary, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),

        if (_sessions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No classroom sessions scheduled for today.', style: TextStyle(color: CognitoColors.textSecondary, fontSize: 13)),
            ),
          )
        else
          ..._sessions.map((sess) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            sess['title'] ?? 'Technical Session',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: CognitoColors.textDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sess['status'] ?? 'SCHEDULED',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${sess['batch_name'] ?? 'Batch'} • ${sess['start_time'] ?? '09:00 AM'} - ${sess['end_time'] ?? '11:00 AM'}',
                      style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  // ==========================================
  // TAB 1: MY SCOPED STUDENTS & ATTENDANCE
  // ==========================================
  Widget _buildMyStudentsTab() {
    final total = _scopedStudents.length;
    final present = _scopedStudents.where((s) => (s['attendance_status'] == 'PRESENT' || s['today_status'] == 'PRESENT')).length;
    final notMarked = total - present;

    final filtered = _scopedStudents.where((s) {
      final matchesSearch = _studentSearchQuery.isEmpty ||
          (s['full_name'] ?? '').toString().toLowerCase().contains(_studentSearchQuery.toLowerCase()) ||
          (s['roll_number'] ?? '').toString().toLowerCase().contains(_studentSearchQuery.toLowerCase());
      final studentBranch = (s['branch'] ?? '').toString();
      final matchesBranch = _matchesBranchFilter(studentBranch, _studentBranchFilter);
      return matchesSearch && matchesBranch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Session Students',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                  ),
                  Text(
                    '$total Enrolled in Track',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _handleMarkAllPresent,
              icon: const Icon(Icons.done_all_rounded, size: 15),
              label: const Text('Mark All Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Students strictly scoped to your assigned batches, course track, and target branches.',
          style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 14),

        // Attendance Quick Summary Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Students', style: TextStyle(fontSize: 10, color: CognitoColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Present Today', style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$present', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Not Marked', style: TextStyle(fontSize: 10, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$notMarked', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Search Bar & Branch Filter Chips
        TextField(
          onChanged: (val) => setState(() => _studentSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search by student name or roll number...',
            hintStyle: const TextStyle(fontSize: 12.5),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
        const SizedBox(height: 10),

        // Branch Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['ALL', 'CSE', 'ECE', 'EEE', 'Mechanical', 'Civil', 'AI & DS', 'AI & ML'].map((b) {
              final isSel = _studentBranchFilter == b;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(b, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                  selected: isSel,
                  selectedColor: CognitoColors.primary,
                  labelStyle: TextStyle(color: isSel ? Colors.white : CognitoColors.textDark),
                  backgroundColor: Colors.white,
                  onSelected: (selected) => setState(() => _studentBranchFilter = b),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Student Roster
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No students found matching current filter.', style: TextStyle(color: CognitoColors.textSecondary, fontSize: 13)),
            ),
          )
        else
          ...filtered.map((st) {
            final isPresent = st['attendance_status'] == 'PRESENT' || st['today_status'] == 'PRESENT';
            final checkInTime = st['check_in_time'] != null
                ? st['check_in_time'].toString().substring(11, 16)
                : st['marked_time'];

            return GestureDetector(
              onTap: () => _showStudentProfileModal((st['id'] ?? st['student_id'] ?? '').toString()),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isPresent ? const Color(0xFFBBF7D0) : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      child: Text(
                        (st['full_name'] ?? 'S').substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isPresent ? const Color(0xFF16A34A) : CognitoColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  st['roll_number'] ?? 'N/A',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: CognitoColors.primary, letterSpacing: 0.3),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${st['branch'] ?? 'CSE'} • ${st['year'] ?? '2nd Year'}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            st['full_name'] ?? 'Student',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (st['course_name'] != null || st['batch_name'] != null)
                            Text(
                              '${st['course_name'] ?? st['batch_name']}',
                              style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isPresent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                                SizedBox(width: 4),
                                Text(
                                  'PRESENT',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                            if (checkInTime != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                checkInTime,
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _handleMarkStudentManual(st),
                        icon: const Icon(Icons.check_rounded, size: 14),
                        label: const Text('Mark Present', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  bool _matchesBranchFilter(String branch, String filter) {
    if (filter == 'ALL') return true;
    final b = branch.toUpperCase().replaceAll(' ', '').replaceAll('&', '');
    final f = filter.toUpperCase().replaceAll(' ', '').replaceAll('&', '');
    if (b == f) return true;
    if ((f == 'MECHANICAL' || f == 'MECH') && (b == 'MECH' || b == 'MECHANICAL')) return true;
    if (f == 'CIVIL' && b == 'CIVIL') return true;
    if ((f == 'AIDS' || f == 'AI&DS' || f == 'AIANDDS') && (b == 'AIDS' || b == 'AI&DS' || b == 'AIANDDS')) return true;
    if ((f == 'AIML' || f == 'AI&ML' || f == 'AIANDML') && (b == 'AIML' || b == 'AI&ML' || b == 'AIANDML')) return true;
    return b.contains(f) || f.contains(b);
  }

  // ==========================================
  // TAB 2: DAILY QR ATTENDANCE SLOT GENERATOR
  // ==========================================
  Widget _buildDailyQrSlotTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dynamic Classroom Attendance QR',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
        ),
        const SizedBox(height: 3),
        const Text(
          'Generate a dynamic, time-bound QR code for this session. Students scan on their mobile app to verify attendance.',
          style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Generator Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Slot Title / Session Track', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedSlotName,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: 'Morning Technical Slot (09:00 AM - 01:00 PM)', child: Text('Morning Slot (09:00 AM - 01:00 PM)')),
                  DropdownMenuItem(value: 'Afternoon Practical Slot (01:00 PM - 04:00 PM)', child: Text('Afternoon Slot (01:00 PM - 04:00 PM)')),
                  DropdownMenuItem(value: 'Full Day Hands-on Coding Slot (09:00 AM - 04:00 PM)', child: Text('Full Day Slot (09:00 AM - 04:00 PM)')),
                  DropdownMenuItem(value: 'Special Placement Assessment Slot', child: Text('Special Assessment Slot')),
                ],
                onChanged: (val) => setState(() => _selectedSlotName = val ?? _selectedSlotName),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Validity Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedSlotDuration,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          items: const [
                            DropdownMenuItem(value: '15', child: Text('15 Minutes')),
                            DropdownMenuItem(value: '30', child: Text('30 Minutes (Recommended)')),
                            DropdownMenuItem(value: '60', child: Text('1 Hour')),
                            DropdownMenuItem(value: '120', child: Text('2 Hours')),
                          ],
                          onChanged: (val) => setState(() => _selectedSlotDuration = val ?? '30'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingSlot ? null : _generateDailySlotQr,
                  icon: _isGeneratingSlot
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.qr_code_2_rounded, size: 20),
                  label: const Text('GENERATE SESSION ATTENDANCE QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CognitoColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live Active QR Code Display
        if (_activeQrSlot != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CognitoColors.primary.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: CognitoColors.primary.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _slotSecondsRemaining > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _slotSecondsRemaining > 0 ? 'ACTIVE LIVE QR' : 'SLOT EXPIRED',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _slotSecondsRemaining > 0 ? const Color(0xFF16A34A) : CognitoColors.danger,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: _slotSecondsRemaining > 60 ? CognitoColors.primary : CognitoColors.danger),
                        const SizedBox(width: 4),
                        Text(
                          '${(_slotSecondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_slotSecondsRemaining % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _slotSecondsRemaining > 60 ? CognitoColors.primary : CognitoColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _activeQrSlot!['slot_name'] ?? _activeQrSlot!['slotName'] ?? 'Technical Session Slot',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Render High-Contrast QR Code
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: QrImageView(
                      data: _activeQrSlot!['token'] ?? _activeQrSlot!['qr_data'] ?? _activeQrSlot!['qrData'] ?? 'INVALID',
                      version: QrVersions.auto,
                      size: 210,
                      gapless: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // High-Visibility Prominent Token Display Card for Manual Student Entry
                Builder(
                  builder: (context) {
                    final tokenCode = _activeQrSlot!['token'] ??
                        _activeQrSlot!['slot_code'] ??
                        _activeQrSlot!['slotCode'] ??
                        'COG-HUB';

                    return InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: tokenCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Attendance Token "$tokenCode" copied to clipboard!'),
                            backgroundColor: const Color(0xFF16A34A),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: CognitoColors.primary.withOpacity(0.35), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: CognitoColors.primary.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'SESSION ATTENDANCE TOKEN CODE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: CognitoColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        tokenCode,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: CognitoColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.copy_rounded, size: 16, color: CognitoColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap to copy • Students can scan QR above or simply enter this token code manually in their app to mark attendance',
                              style: TextStyle(
                                fontSize: 11,
                                color: CognitoColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text(
                  'No Live QR Active',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Click "GENERATE SESSION ATTENDANCE QR" above to create and display a live QR code for students to scan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: CognitoColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Today's Generated Slots List
        const Text(
          'TODAY\'S GENERATED SLOTS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CognitoColors.textSecondary, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),

        if (_todaySlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No attendance slots generated yet today.', style: TextStyle(color: CognitoColors.textSecondary, fontSize: 12)),
            ),
          )
        else
          ..._todaySlots.map((slot) {
            final isCur = _activeQrSlot != null && (_activeQrSlot!['id'] == slot['id']);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isCur ? CognitoColors.primary : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_rounded, color: isCur ? CognitoColors.primary : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slot['slot_name'] ?? 'Slot', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                          'Code: ${slot['slot_code']} • Scans: ${slot['total_scans'] ?? 0}',
                          style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!isCur)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _activeQrSlot = slot;
                        });
                        _startSlotTimer();
                      },
                      child: const Text('Show QR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // TAB 3: STUDY MATERIALS
  // ==========================================
  Widget _buildMaterialsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Study Materials & Notes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            ElevatedButton.icon(
              onPressed: _showUploadMaterialModal,
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: const Text('Upload Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CognitoColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload documents (.pdf, .pptx, .docx) from your phone storage for your target students.',
          style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_materials.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('No study materials uploaded yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark)),
                  const SizedBox(height: 4),
                  const Text('Tap "+ Upload Notes" above to publish PPTs or PDF guides to your students.', style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                ],
              ),
            ),
          )
        else
          ..._materials.map((mat) {
            final type = mat['file_type'] ?? 'PDF';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: CognitoColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        type.toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: CognitoColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mat['title'] ?? 'Study Notes',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${mat['course_name'] ?? 'Track'} • ${mat['target_year'] ?? 'All Years'} (${mat['target_branch'] ?? 'All Branches'})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                        ),
                        if (mat['description'] != null && mat['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            mat['description'],
                            style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // TAB 4: EOD REPORTS
  // ==========================================
  Widget _buildEodReportsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'End-of-Day (EOD) Reports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            ElevatedButton.icon(
              onPressed: _showSubmitEodReportModal,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Submit Report', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CognitoColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Daily reports review topics covered, students present, and tomorrow\'s roadmap.',
          style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_dailyReports.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('No EOD reports submitted yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark)),
                  const SizedBox(height: 4),
                  const Text('Tap "+ Submit Report" above at the conclusion of your instruction session.', style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                ],
              ),
            ),
          )
        else
          ..._dailyReports.map((rep) {
            final date = rep['report_date'] != null ? rep['report_date'].toString().substring(0, 10) : 'Today';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rep['course_name'] ?? 'Course Session',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          date,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${rep['target_year'] ?? 'Year'} • ${rep['target_branch'] ?? 'Branch'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Attendees: ${rep['students_present'] ?? 0}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  const Text('Topics Covered:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                  const SizedBox(height: 2),
                  Text(rep['topics_covered'] ?? 'N/A', style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                  if (rep['challenges_faced'] != null && rep['challenges_faced'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Challenges / Lab Doubts:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                    Text(rep['challenges_faced'], style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                  ],
                  if (rep['tomorrow_plan'] != null && rep['tomorrow_plan'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Tomorrow\'s Agenda:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    Text(rep['tomorrow_plan'], style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // TAB 2: DAILY QUIZ & ASSESSMENT MANAGEMENT
  // ==========================================
  Widget _buildDailyQuizTab() {
    final publishedCount = _quizzes.where((q) => q['is_published'] == true).length;
    final draftCount = _quizzes.where((q) => q['is_published'] != true).length;
    final totalSubs = _quizzes.fold<int>(0, (sum, q) => sum + ((q['submission_count'] as int?) ?? 0));

    final filteredQuizzes = _quizzes.where((q) {
      if (_quizFilter == 'PUBLISHED') return q['is_published'] == true;
      if (_quizFilter == 'DRAFT') return q['is_published'] != true;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Assessment Quizzes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create 15-20 min post-class quizzes or upload Google Form tests.',
                    style: TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Action Buttons (Open Full Mobile Screen Preparation Pages)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateMcqQuizScreen(
                        trainerProfile: _trainerProfile,
                        userProfile: widget.userProfile,
                        onQuizCreated: _loadAllTrainerData,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.post_add_rounded, size: 16),
                label: const Text('+ Prepare MCQ Paper', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CognitoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateGoogleFormQuizScreen(
                        trainerProfile: _trainerProfile,
                        userProfile: widget.userProfile,
                        onQuizCreated: _loadAllTrainerData,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('+ Google Form Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Interactive KPI Summary Cards
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _quizFilter = 'ALL'),
                  borderRadius: BorderRadius.circular(12),
                  child: _buildQuizKpiItem(
                    'Total Papers',
                    '${_quizzes.length}',
                    CognitoColors.primary,
                    Icons.description_rounded,
                    isSelected: _quizFilter == 'ALL',
                  ),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _quizFilter = 'PUBLISHED'),
                  borderRadius: BorderRadius.circular(12),
                  child: _buildQuizKpiItem(
                    'Live to Students',
                    '$publishedCount',
                    const Color(0xFF16A34A),
                    Icons.check_circle_rounded,
                    isSelected: _quizFilter == 'PUBLISHED',
                  ),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _quizFilter = 'DRAFT'),
                  borderRadius: BorderRadius.circular(12),
                  child: _buildQuizKpiItem(
                    'Drafts',
                    '$draftCount',
                    const Color(0xFFD97706),
                    Icons.edit_note_rounded,
                    isSelected: _quizFilter == 'DRAFT',
                  ),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              Expanded(
                child: InkWell(
                  onTap: _showAllSubmissionsModal,
                  borderRadius: BorderRadius.circular(12),
                  child: _buildQuizKpiItem(
                    'Submissions',
                    '$totalSubs',
                    const Color(0xFF0284C7),
                    Icons.group_rounded,
                    isSelected: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick Filter Tabs Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChoiceChip('All Papers (${_quizzes.length})', 'ALL'),
              const SizedBox(width: 6),
              _buildFilterChoiceChip('Live to Students ($publishedCount)', 'PUBLISHED'),
              const SizedBox(width: 6),
              _buildFilterChoiceChip('Drafts ($draftCount)', 'DRAFT'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // List of Created Quizzes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _quizFilter == 'DRAFT'
                  ? 'DRAFT QUESTION PAPERS ($draftCount)'
                  : _quizFilter == 'PUBLISHED'
                      ? 'LIVE PUBLISHED PAPERS ($publishedCount)'
                      : 'ALL PREPARED PAPERS (${_quizzes.length})',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CognitoColors.textSecondary, letterSpacing: 0.8),
            ),
            if (_quizFilter != 'ALL')
              GestureDetector(
                onTap: () => setState(() => _quizFilter = 'ALL'),
                child: const Text('Show All', style: TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (filteredQuizzes.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _quizFilter == 'DRAFT'
                        ? Icons.edit_note_rounded
                        : _quizFilter == 'PUBLISHED'
                            ? Icons.sensors_off_rounded
                            : Icons.quiz_outlined,
                    size: 44,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _quizFilter == 'DRAFT'
                        ? 'No draft papers found.'
                        : _quizFilter == 'PUBLISHED'
                            ? 'No question papers published live.'
                            : 'No question papers prepared yet.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _quizFilter == 'DRAFT'
                        ? 'All your prepared question papers are currently published live to students, or prepare a new paper and click "Save as Draft".'
                        : _quizFilter == 'PUBLISHED'
                            ? 'Switch to the "Drafts" tab to publish one of your saved papers to students.'
                            : 'Tap "+ Prepare MCQ Paper" above to create a randomized test for your students.',
                    style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (_quizFilter != 'ALL') ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _quizFilter = 'ALL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CognitoColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('View All Papers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ...filteredQuizzes.map((quiz) {
            final isPub = quiz['is_published'] == true;
            final isGoogleForm = quiz['quiz_type'] == 'GOOGLE_FORM';
            final subsCount = quiz['submission_count'] ?? 0;
            final avgScore = quiz['average_score'] ?? 0;
            final avgPct = quiz['average_percentage'] ?? 0;
            final qCount = (quiz['questions'] as List?)?.length ?? 0;
            final durationMins = quiz['duration_minutes'] ?? 15;
            final totalMarks = (quiz['questions'] as List?)?.length ?? quiz['total_marks'] ?? 1;

            final dateStr = isPub
                ? 'Published: ${_formatQuizDate(quiz['published_at'] ?? quiz['created_at'])}'
                : 'Saved as Draft: ${_formatQuizDate(quiz['created_at'] ?? quiz['updated_at'])}';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isPub ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Status & Type Badges (Responsive Wrap layout)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPub ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPub ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPub ? Icons.sensors_rounded : Icons.edit_document,
                                size: 12,
                                color: isPub ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPub ? 'PUBLISHED (LIVE TO STUDENTS)' : 'DRAFT (SAVED IN DRAFTS)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isPub ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isGoogleForm ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isGoogleForm ? 'GOOGLE FORM' : 'CUSTOM MCQ',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isGoogleForm ? const Color(0xFF7C3AED) : CognitoColors.primary,
                                ),
                              ),
                            ),
                            if (!isPub) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _openEditQuizScreen(quiz),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 13, color: Color(0xFFD97706)),
                                      SizedBox(width: 2),
                                      Text('Edit', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Published / Saved Date Row
                    Row(
                      children: [
                        Icon(
                          isPub ? Icons.event_available_rounded : Icons.schedule_rounded,
                          size: 13,
                          color: isPub ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPub ? const Color(0xFF166534) : const Color(0xFF92400E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title & Description
                    Text(
                      quiz['title'] ?? 'Daily Assessment',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CognitoColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${quiz['course_name'] ?? 'Track'} • ${quiz['target_year'] ?? 'All Years'} (${quiz['target_branch'] ?? 'All Branches'})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                    ),
                    if (quiz['description'] != null && quiz['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        quiz['description'],
                        style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Metrics Strip - Fully responsive columns with scale-down text
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildQuizMiniMetric('Timer', '$durationMins Mins')),
                          Container(width: 1, height: 20, color: Colors.grey.shade300),
                          Expanded(
                            child: _buildQuizMiniMetric(
                              'Questions',
                              isGoogleForm ? 'Google Form' : '$qCount Qs ($totalMarks M)',
                            ),
                          ),
                          Container(width: 1, height: 20, color: Colors.grey.shade300),
                          Expanded(child: _buildQuizMiniMetric('Submissions', '$subsCount')),
                          if (subsCount > 0) ...[
                            Container(width: 1, height: 20, color: Colors.grey.shade300),
                            Expanded(
                              child: _buildQuizMiniMetric(
                                isGoogleForm ? 'Status' : 'Avg Score',
                                isGoogleForm ? '$subsCount Done' : '$avgScore ($avgPct%)',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action Controls
                    Column(
                      children: [
                        if (isPub) ...[
                          // For PUBLISHED papers: NO edit option! Only Unpublish
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _handleTogglePublishQuiz(quiz['id'], true),
                              icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Unpublish Paper', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ] else ...[
                          // For DRAFT papers: Give Edit Paper & Publish options
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openEditQuizScreen(quiz),
                                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Edit Paper', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleTogglePublishQuiz(quiz['id'], false),
                                  icon: const Icon(Icons.send_rounded, size: 15),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Publish Paper to Students', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // View Submissions & Leaderboard (Full Mobile Screen)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openQuizSubmissionsScreen(quiz),
                                icon: const Icon(Icons.leaderboard_rounded, size: 15),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isGoogleForm ? 'View Submissions ($subsCount)' : 'Results ($subsCount)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Delete Option
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                              tooltip: 'Delete Question Paper',
                              onPressed: () => _handleDeleteQuiz(quiz['id']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFilterChoiceChip(String label, String value) {
    final isSel = _quizFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
          color: isSel ? Colors.white : CognitoColors.textDark,
        ),
      ),
      selected: isSel,
      selectedColor: CognitoColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSel ? CognitoColors.primary : Colors.grey.shade300),
      onSelected: (_) => setState(() => _quizFilter = value),
    );
  }

  Widget _buildQuizKpiItem(String label, String value, Color color, IconData icon, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? color : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : CognitoColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizMiniMetric(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: CognitoColors.textSecondary),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MODAL: VIEW ALL STUDENT SUBMISSIONS ACROSS ALL QUIZZES
  // ==========================================
  void _showAllSubmissionsModal() {
    final searchController = TextEditingController();
    String selectedQuizFilter = 'ALL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.96,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: FutureBuilder<List<dynamic>>(
              future: ApiService.getAllQuizSubmissions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: CognitoColors.primary)));
                }

                final allSubs = snapshot.data ?? [];
                final query = searchController.text.trim().toLowerCase();

                final filteredSubs = allSubs.where((s) {
                  final name = (s['student_name'] ?? '').toString().toLowerCase();
                  final roll = (s['roll_number'] ?? '').toString().toLowerCase();
                  final qId = (s['quiz_id'] ?? '').toString();
                  final matchesQuery = query.isEmpty || name.contains(query) || roll.contains(query);
                  final matchesQuiz = selectedQuizFilter == 'ALL' || qId == selectedQuizFilter;
                  return matchesQuery && matchesQuiz;
                }).toList();

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('All Student Submissions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                              const SizedBox(height: 2),
                              Text(
                                '${allSubs.length} Total Submissions Across All Papers',
                                style: const TextStyle(fontSize: 12, color: CognitoColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter By Quiz Dropdown (if multiple quizzes exist)
                    if (_quizzes.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedQuizFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          labelText: 'Filter by Question Paper',
                        ),
                        items: [
                          const DropdownMenuItem(value: 'ALL', child: Text('All Question Papers', style: TextStyle(fontSize: 12.5))),
                          ..._quizzes.map((q) => DropdownMenuItem(
                                value: q['id'].toString(),
                                child: Text(q['title'] ?? 'Quiz', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                              )),
                        ],
                        onChanged: (val) => setModalState(() => selectedQuizFilter = val ?? 'ALL'),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Search input
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search student name or roll number...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  searchController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const Divider(height: 20),

                    if (filteredSubs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.pending_actions_rounded, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                query.isNotEmpty ? 'No student matched "$query"' : 'No students have submitted any quizzes yet.',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Once students attempt quizzes from their portal, verified scores, date & time will appear here.',
                                style: TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(filteredSubs.length, (idx) {
                        final s = filteredSubs[idx];
                        final score = s['score'] ?? 0;
                        final totalMarks = s['total_marks'] ?? 1;
                        final pct = (s['percentage'] ?? (totalMarks > 0 ? (score / totalMarks * 100).round() : 0)).toDouble();
                        final isAuto = s['is_auto_submitted'] == true;
                        final timeSpent = s['time_taken_seconds'] ?? 0;
                        final mins = timeSpent ~/ 60;
                        final secs = timeSpent % 60;
                        final subDate = s['submitted_date'] ?? '';
                        final subTime = s['submitted_time'] ?? '';
                        final tabSwitches = s['tab_switch_count'] ?? 0;
                        final review = (s['review_breakdown'] as List<dynamic>?) ?? [];

                        final matchingQuiz = _quizzes.firstWhere((q) => q['id'] == s['quiz_id'], orElse: () => null);
                        final quizTitle = matchingQuiz?['title'] ?? s['quiz_title'] ?? 'Assessment Quiz';
                        final isSubGoogleForm = (s['quiz_type'] == 'GOOGLE_FORM') ||
                            (matchingQuiz?['quiz_type'] == 'GOOGLE_FORM') ||
                            (s['google_form_url'] != null && s['google_form_url'].toString().isNotEmpty);

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            if (isSubGoogleForm) {
                              _showGoogleFormSubmissionDialog(s, matchingQuiz ?? s);
                            } else if (review.isNotEmpty) {
                              _showStudentAnswerSheetDialog(s, quizTitle);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
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
                                // Rank Badge
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: idx == 0 ? const Color(0xFFFEF3C7) : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '#${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: idx == 0 ? const Color(0xFFD97706) : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              s['student_name'] ?? 'Student',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: isSubGoogleForm ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isSubGoogleForm ? 'GOOGLE FORM' : 'MCQ',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: isSubGoogleForm ? const Color(0xFF7C3AED) : CognitoColors.primary,
                                              ),
                                            ),
                                          ),
                                          if ((s['roll_number'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                s['roll_number'],
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        quizTitle,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${s['branch'] ?? 'Branch'} (${s['year'] ?? '2nd Year'})' +
                                            (subDate.isNotEmpty ? ' • 📅 $subDate at $subTime' : ''),
                                        style: const TextStyle(fontSize: 10.5, color: CognitoColors.textSecondary),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            '⏱️ ${mins > 0 ? "${mins}m " : ""}${secs}s',
                                            style: TextStyle(fontSize: 10, color: isAuto ? const Color(0xFFD97706) : Colors.grey.shade700, fontWeight: FontWeight.w600),
                                          ),
                                          if (tabSwitches > 0) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '⚠️ $tabSwitches Switch${tabSwitches > 1 ? "es" : ""}',
                                                style: const TextStyle(fontSize: 9.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 6),
                                          Text(
                                            isSubGoogleForm ? '• View Form Details 👁️' : (review.isNotEmpty ? '• View Sheet 👁️' : ''),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isSubGoogleForm ? const Color(0xFF7C3AED) : CognitoColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Score Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (isSubGoogleForm || pct >= 50) ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: (isSubGoogleForm || pct >= 50) ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        isSubGoogleForm ? '✓ Done' : '$score / $totalMarks',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: (isSubGoogleForm || pct >= 50) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                      Text(
                                        isSubGoogleForm ? 'Completed' : '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9.5,
                                          color: (isSubGoogleForm || pct >= 50) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VIEW QUIZ SUBMISSIONS FULL SCREEN
  // ==========================================
  void _openQuizSubmissionsScreen(dynamic quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSubmissionsScreen(
          quiz: Map<String, dynamic>.from(quiz),
          trainerProfile: _trainerProfile,
          userProfile: widget.userProfile,
          onRefreshNeeded: _loadAllTrainerData,
        ),
      ),
    );
  }

  void _showGoogleFormSubmissionDialog(dynamic submission, dynamic quiz) {
    final name = submission['student_name'] ?? 'Student';
    final roll = submission['roll_number'] ?? '';
    final branch = submission['branch'] ?? 'Branch';
    final year = submission['year'] ?? '2nd Year';
    final quizTitle = quiz?['title'] ?? submission['quiz_title'] ?? 'Google Form Test';
    final courseName = quiz?['course_name'] ?? submission['course_name'] ?? 'Technical Session';
    final formUrl = (quiz?['google_form_url'] ?? submission['google_form_url'] ?? '').toString();
    final timeSpent = submission['time_taken_seconds'] ?? 0;
    final mins = timeSpent ~/ 60;
    final secs = timeSpent % 60;
    final subDate = submission['submitted_date'] ?? 'Today';
    final subTime = submission['submitted_time'] ?? '';
    final tabSwitches = submission['tab_switch_count'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_rounded, color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name ($roll)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                  const SizedBox(height: 2),
                  Text('$branch • $year', style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.quiz_outlined, size: 14, color: CognitoColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          quizTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: CognitoColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(courseName, style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Submitted via Google Forms',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                        ),
                        Text(
                          'Submitted on $subDate at $subTime',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('Time Taken', style: TextStyle(fontSize: 10, color: CognitoColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text('${mins > 0 ? "${mins}m " : ""}${secs}s', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tabSwitches > 0 ? const Color(0xFFFEF2F2) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tabSwitches > 0 ? const Color(0xFFFECACA) : Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('Tab Switches', style: TextStyle(fontSize: 10, color: CognitoColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          tabSwitches > 0 ? '$tabSwitches Switch${tabSwitches > 1 ? "es" : ""}' : '0 (None)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: tabSwitches > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (formUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openExternalUrl(formUrl),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Open Google Form Responses / Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: CognitoColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStudentAnswerSheetDialog(dynamic submission, String quizTitle) {
    final name = submission['student_name'] ?? 'Student';
    final roll = submission['roll_number'] ?? '';
    final score = submission['score'] ?? 0;
    final totalMarks = submission['total_marks'] ?? 10;
    final pct = submission['percentage'] ?? 0;
    final review = (submission['review_breakdown'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name ($roll)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Score: $score / $totalMarks ($pct%) • $quizTitle', style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: review.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, idx) {
              final r = review[idx];
              final isCorr = r['is_correct'] == true;
              final qText = r['question_text'] ?? 'Question ${idx + 1}';
              final stuAns = r['student_answer'] ?? 'NOT_ATTEMPTED';
              final corrOpt = r['correct_option'] ?? '';
              final explanation = r['explanation'] ?? '';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorr ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCorr ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(isCorr ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorr ? const Color(0xFF16A34A) : const Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Q${idx + 1}. $qText', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Student Answer: $stuAns', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCorr ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                        const SizedBox(width: 10),
                        if (!isCorr) Text('Correct Key: $corrOpt', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ],
                    ),
                    if (explanation.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note: $explanation', style: const TextStyle(fontSize: 10, color: CognitoColors.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _openEditQuizScreen(dynamic quiz) {
    final isGoogleForm = quiz['quiz_type'] == 'GOOGLE_FORM';
    if (isGoogleForm) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateGoogleFormQuizScreen(
            editingQuiz: Map<String, dynamic>.from(quiz),
            trainerProfile: _trainerProfile,
            userProfile: widget.userProfile,
            onQuizCreated: _loadAllTrainerData,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateMcqQuizScreen(
            editingQuiz: Map<String, dynamic>.from(quiz),
            trainerProfile: _trainerProfile,
            userProfile: widget.userProfile,
            onQuizCreated: _loadAllTrainerData,
          ),
        ),
      );
    }
  }

  Future<void> _handleTogglePublishQuiz(String quizId, bool currentStatus) async {
    final targetStatus = !currentStatus;
    final qIdx = _quizzes.indexWhere((q) => q['id'] == quizId);
    if (qIdx != -1) {
      setState(() {
        _quizzes[qIdx]['is_published'] = targetStatus;
        _quizzes[qIdx]['status'] = targetStatus ? 'PUBLISHED' : 'DRAFT';
      });
    }

    try {
      final res = await ApiService.togglePublishQuiz(quizId, isPublished: targetStatus);
      final updatedQuizzes = await ApiService.getQuizzes();
      if (mounted) {
        setState(() {
          _quizzes = updatedQuizzes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Quiz status updated!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (qIdx != -1 && mounted) {
        setState(() {
          _quizzes[qIdx]['is_published'] = currentStatus;
          _quizzes[qIdx]['status'] = currentStatus ? 'PUBLISHED' : 'DRAFT';
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: CognitoColors.danger),
      );
    }
  }

  Future<void> _handleDeleteQuiz(String quizId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question Paper?'),
        content: const Text('This will remove this quiz and any associated student submissions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: CognitoColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1. Optimistic removal from UI for instant 0ms feedback
    final deletedQuizIndex = _quizzes.indexWhere((q) => q['id'] == quizId);
    dynamic deletedQuiz;
    if (deletedQuizIndex != -1) {
      deletedQuiz = _quizzes[deletedQuizIndex];
      setState(() {
        _quizzes.removeAt(deletedQuizIndex);
      });
    }

    try {
      final res = await ApiService.deleteQuiz(quizId);
      // Fast refresh of quizzes list only (no heavy 8-module reload)
      final updatedQuizzes = await ApiService.getQuizzes();
      if (mounted) {
        setState(() {
          _quizzes = updatedQuizzes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Question paper deleted successfully.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      // Revert optimistic removal if deletion failed
      if (deletedQuiz != null && mounted) {
        setState(() {
          _quizzes.insert(deletedQuizIndex, deletedQuiz);
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: CognitoColors.danger),
      );
    }
  }
}

// ============================================================================
// FULL MOBILE SCREEN: QUIZ SUBMISSIONS ROSTER & RESULTS
// ============================================================================
class QuizSubmissionsScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final Map<String, dynamic>? trainerProfile;
  final Map<String, dynamic>? userProfile;
  final VoidCallback? onRefreshNeeded;

  const QuizSubmissionsScreen({
    super.key,
    required this.quiz,
    this.trainerProfile,
    this.userProfile,
    this.onRefreshNeeded,
  });

  @override
  State<QuizSubmissionsScreen> createState() => _QuizSubmissionsScreenState();
}

class _QuizSubmissionsScreenState extends State<QuizSubmissionsScreen> {
  late Map<String, dynamic> _quiz;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic>? _quizData;
  List<dynamic> _allSubmissions = [];
  int _totalMarks = 10;
  bool _isTogglingPublish = false;

  @override
  void initState() {
    super.initState();
    _quiz = Map<String, dynamic>.from(widget.quiz);
    _totalMarks = _quiz['total_marks'] ?? ((_quiz['questions'] as List?)?.length ?? 10);
    _allSubmissions = (_quiz['submissions'] as List<dynamic>?) ?? [];
    _isLoading = _allSubmissions.isEmpty;
    _loadSubmissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadSubmissions() async {
    if (_allSubmissions.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final quizId = _quiz['id']?.toString() ?? '';
      final res = await ApiService.getQuizSubmissions(quizId);
      if (mounted) {
        setState(() {
          _quizData = res;
          _allSubmissions = (res['submissions'] as List<dynamic>?) ?? [];
          _totalMarks = res['total_marks'] ?? _quiz['total_marks'] ?? 10;
          if (res.containsKey('is_results_published')) {
            _quiz['is_results_published'] = res['is_results_published'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load submissions: $e'), backgroundColor: CognitoColors.danger),
        );
      }
    }
  }

  Future<void> _togglePublishResults(bool publish) async {
    final quizId = _quiz['id']?.toString() ?? '';
    setState(() => _isTogglingPublish = true);
    try {
      await ApiService.publishQuizResults(quizId, isPublished: publish);
      if (mounted) {
        setState(() {
          _quiz['is_results_published'] = publish;
          _isTogglingPublish = false;
        });
        widget.onRefreshNeeded?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(publish ? '✅ Test scores published live to student portal!' : 'Quiz scores hidden from student portal.'),
            backgroundColor: publish ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTogglingPublish = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: CognitoColors.danger),
        );
      }
    }
  }

  void _showGoogleFormDialog(dynamic submission) {
    final name = submission['student_name'] ?? 'Student';
    final roll = submission['roll_number'] ?? '';
    final branch = submission['branch'] ?? 'Branch';
    final year = submission['year'] ?? '2nd Year';
    final quizTitle = _quiz['title'] ?? submission['quiz_title'] ?? 'Google Form Test';
    final courseName = _quiz['course_name'] ?? submission['course_name'] ?? 'Technical Session';
    final formUrl = (_quiz['google_form_url'] ?? submission['google_form_url'] ?? '').toString();
    final timeSpent = submission['time_taken_seconds'] ?? 0;
    final mins = timeSpent ~/ 60;
    final secs = timeSpent % 60;
    final subDate = submission['submitted_date'] ?? 'Today';
    final subTime = submission['submitted_time'] ?? '';
    final tabSwitches = submission['tab_switch_count'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_rounded, color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name ($roll)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                  const SizedBox(height: 2),
                  Text('$branch • $year', style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.quiz_outlined, size: 14, color: CognitoColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          quizTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: CognitoColors.textDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(courseName, style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Submitted via Google Forms',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                        ),
                        Text(
                          'Submitted on $subDate at $subTime',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('Time Taken', style: TextStyle(fontSize: 10, color: CognitoColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text('${mins > 0 ? "${mins}m " : ""}${secs}s', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tabSwitches > 0 ? const Color(0xFFFEF2F2) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tabSwitches > 0 ? const Color(0xFFFECACA) : Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        const Text('Tab Switches', style: TextStyle(fontSize: 10, color: CognitoColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          tabSwitches > 0 ? '$tabSwitches Switch${tabSwitches > 1 ? "es" : ""}' : '0 (None)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: tabSwitches > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (formUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openExternalUrl(formUrl),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Open Google Form Responses / Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: CognitoColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAnswerSheetDialog(dynamic submission, String quizTitle) {
    final name = submission['student_name'] ?? 'Student';
    final roll = submission['roll_number'] ?? '';
    final score = submission['score'] ?? 0;
    final totalMarks = submission['total_marks'] ?? _totalMarks;
    final pct = submission['percentage'] ?? (totalMarks > 0 ? (score / totalMarks * 100).round() : 0);
    final review = (submission['review_breakdown'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name ($roll)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Score: $score / $totalMarks ($pct%) • $quizTitle', style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: review.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, idx) {
              final r = review[idx];
              final isCorr = r['is_correct'] == true;
              final qText = r['question_text'] ?? 'Question ${idx + 1}';
              final stuAns = r['student_answer'] ?? 'NOT_ATTEMPTED';
              final corrOpt = r['correct_option'] ?? '';
              final explanation = r['explanation'] ?? '';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorr ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCorr ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(isCorr ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorr ? const Color(0xFF16A34A) : const Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Q${idx + 1}. $qText', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Student Answer: $stuAns', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCorr ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                        const SizedBox(width: 10),
                        if (!isCorr) Text('Correct Key: $corrOpt', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ],
                    ),
                    if (explanation.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note: $explanation', style: const TextStyle(fontSize: 10, color: CognitoColors.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizTitle = _quiz['title'] ?? 'Assessment Results';
    final query = _searchController.text.trim().toLowerCase();
    final subs = query.isEmpty
        ? _allSubmissions
        : _allSubmissions.where((s) {
            final name = (s['student_name'] ?? '').toString().toLowerCase();
            final roll = (s['roll_number'] ?? '').toString().toLowerCase();
            return name.contains(query) || roll.contains(query);
          }).toList();

    final isGoogleFormQuiz = (_quiz['quiz_type'] == 'GOOGLE_FORM') ||
        (_quiz['google_form_url'] != null && _quiz['google_form_url'].toString().isNotEmpty) ||
        (_quizData?['quiz_type'] == 'GOOGLE_FORM');
    final formUrl = (_quiz['google_form_url'] ?? _quizData?['google_form_url'] ?? '').toString();
    final isResultsPublished = (_quiz['is_results_published'] == true || _quizData?['is_results_published'] == true);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: CognitoColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quizTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Student Results & Roster (${_allSubmissions.length} Submissions)',
              style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CognitoColors.primary),
            tooltip: 'Refresh Submissions',
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CognitoColors.primary))
          : RefreshIndicator(
              onRefresh: _loadSubmissions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Google Form Banner OR Publish Results Banner
                  if (isGoogleFormQuiz)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.description_rounded, color: Color(0xFF7C3AED), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Google Form Assessment',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B21B6)),
                                ),
                                Text(
                                  'Students submitted on Google Forms. Verified submissions below.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          if (formUrl.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _openExternalUrl(formUrl),
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: const Text('Open Form', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isResultsPublished ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isResultsPublished ? const Color(0xFF93C5FD) : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isResultsPublished ? Icons.verified_rounded : Icons.visibility_off_rounded,
                            color: isResultsPublished ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isResultsPublished ? 'Scores Published to Students' : 'Scores Hidden from Students',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isResultsPublished ? const Color(0xFF1E40AF) : const Color(0xFF166534),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isResultsPublished
                                      ? 'Students can view their scores & answer sheet in portal.'
                                      : 'Tap button to reveal scores & answer keys to students.',
                                  style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isResultsPublished)
                            OutlinedButton.icon(
                              onPressed: _isTogglingPublish ? null : () => _togglePublishResults(false),
                              icon: const Icon(Icons.visibility_off_outlined, size: 14),
                              label: const Text('Unpublish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                side: const BorderSide(color: Color(0xFFD97706)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _isTogglingPublish ? null : () => _togglePublishResults(true),
                              icon: _isTogglingPublish
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.campaign_rounded, size: 15),
                              label: const Text('Publish Results', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // 2. Search input
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search student name or roll number...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                  const Divider(height: 24),

                  // 3. Submissions list
                  if (subs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(36),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.pending_actions_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              query.isNotEmpty ? 'No student matched "$query"' : 'No students have submitted this quiz yet.',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Once students complete the test from their portal, verified scores and details will appear here in real-time.',
                              style: TextStyle(fontSize: 11.5, color: CognitoColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(subs.length, (idx) {
                      final s = subs[idx];
                      final isGoogleFormSub = (isGoogleFormQuiz) ||
                          (s['quiz_type'] == 'GOOGLE_FORM') ||
                          (s['google_form_url'] != null && s['google_form_url'].toString().isNotEmpty);
                      final score = s['score'] ?? 0;
                      final subTotalMarks = s['total_marks'] ?? _totalMarks;
                      final pct = isGoogleFormSub
                          ? 100.0
                          : (s['percentage'] ?? (subTotalMarks > 0 ? (score / subTotalMarks * 100).round() : 0)).toDouble();
                      final isAuto = s['is_auto_submitted'] == true;
                      final timeSpent = s['time_taken_seconds'] ?? 0;
                      final mins = timeSpent ~/ 60;
                      final secs = timeSpent % 60;
                      final subDate = s['submitted_date'] ?? '';
                      final subTime = s['submitted_time'] ?? '';
                      final tabSwitches = s['tab_switch_count'] ?? 0;
                      final review = (s['review_breakdown'] as List<dynamic>?) ?? [];

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (isGoogleFormSub) {
                            _showGoogleFormDialog(s);
                          } else if (review.isNotEmpty) {
                            _showAnswerSheetDialog(s, quizTitle);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
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
                              // Rank Badge
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: idx == 0 ? const Color(0xFFFEF3C7) : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '#${idx + 1}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: idx == 0 ? const Color(0xFFD97706) : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s['student_name'] ?? 'Student',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if ((s['roll_number'] ?? '').toString().isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              s['roll_number'],
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${s['branch'] ?? 'Branch'} (${s['year'] ?? '2nd Year'})' +
                                          (subDate.isNotEmpty ? ' • 📅 $subDate at $subTime' : ''),
                                      style: const TextStyle(fontSize: 10.5, color: CognitoColors.textSecondary),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          '⏱️ ${mins > 0 ? "${mins}m " : ""}${secs}s',
                                          style: TextStyle(fontSize: 10, color: isAuto ? const Color(0xFFD97706) : Colors.grey.shade700, fontWeight: FontWeight.w600),
                                        ),
                                        if (tabSwitches > 0) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '⚠️ $tabSwitches Switch${tabSwitches > 1 ? "es" : ""}',
                                              style: const TextStyle(fontSize: 9.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 6),
                                        Text(
                                          isGoogleFormSub ? '• View Form Details 👁️' : (review.isNotEmpty ? '• View Sheet 👁️' : ''),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isGoogleFormSub ? const Color(0xFF7C3AED) : CognitoColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Score Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (isGoogleFormSub || pct >= 50) ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (isGoogleFormSub || pct >= 50) ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      isGoogleFormSub ? '✓ Done' : '$score / $subTotalMarks',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: (isGoogleFormSub || pct >= 50) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                    Text(
                                      isGoogleFormSub ? 'Completed' : '${pct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9.5,
                                        color: (isGoogleFormSub || pct >= 50) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// FULL MOBILE SCREEN: PREPARE & EDIT MCQ QUESTION PAPER
// ============================================================================
class CreateMcqQuizScreen extends StatefulWidget {
  final Map<String, dynamic>? editingQuiz;
  final Map<String, dynamic>? trainerProfile;
  final Map<String, dynamic>? userProfile;
  final VoidCallback onQuizCreated;

  const CreateMcqQuizScreen({
    super.key,
    this.editingQuiz,
    this.trainerProfile,
    this.userProfile,
    required this.onQuizCreated,
  });

  @override
  State<CreateMcqQuizScreen> createState() => _CreateMcqQuizScreenState();
}

class _CreateMcqQuizScreenState extends State<CreateMcqQuizScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _courseController;
  late TextEditingController _customDurationController;

  late String _selectedYear;
  String _selectedBranch = 'ALL';
  int _durationMins = 15;
  bool _isCustomDuration = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    final defaultCourseName = widget.trainerProfile?['assignments']?[0]?['course_name'] ?? 'Python Full stack';

    String defaultYear = '2nd Year';
    final assignments = widget.trainerProfile?['assignments'] as List<dynamic>?;
    if (assignments != null && assignments.isNotEmpty) {
      final ty = assignments[0]['target_years'] as List<dynamic>?;
      if (ty != null && ty.isNotEmpty) {
        defaultYear = ty[0].toString();
      }
    }

    if (widget.editingQuiz != null) {
      final eq = widget.editingQuiz!;
      _titleController = TextEditingController(text: eq['title']?.toString() ?? '');
      _descController = TextEditingController(text: eq['description']?.toString() ?? '');
      _courseController = TextEditingController(
        text: eq['course_name']?.toString() ?? eq['courseName']?.toString() ?? defaultCourseName,
      );

      _selectedYear = eq['target_year']?.toString() ?? eq['targetYear']?.toString() ?? defaultYear;
      _selectedBranch = eq['target_branch']?.toString() ?? eq['targetBranch']?.toString() ?? 'ALL';

      final d = eq['duration_minutes'] ?? eq['durationMinutes'];
      if (d != null) {
        _durationMins = int.tryParse(d.toString()) ?? 15;
      } else {
        _durationMins = 15;
      }
      _customDurationController = TextEditingController(text: _durationMins.toString());
      if (![5, 10, 15, 20, 30, 45, 60, 90, 120].contains(_durationMins)) {
        _isCustomDuration = true;
      }

      // Populate existing questions
      final rawQuestions = eq['questions'] as List<dynamic>?;
      if (rawQuestions != null && rawQuestions.isNotEmpty) {
        for (final q in rawQuestions) {
          final qMap = q is Map<String, dynamic> ? q : Map<String, dynamic>.from(q as Map);
          final opts = qMap['options'] as List<dynamic>? ?? [];

          String optAText = '';
          String optBText = '';
          String optCText = '';
          String optDText = '';

          for (final o in opts) {
            final optId = o['id']?.toString().toUpperCase();
            final optText = o['text']?.toString() ?? '';
            if (optId == 'A') optAText = optText;
            if (optId == 'B') optBText = optText;
            if (optId == 'C') optCText = optText;
            if (optId == 'D') optDText = optText;
          }

          if (optAText.isEmpty && qMap['optA'] != null) optAText = qMap['optA'].toString();
          if (optBText.isEmpty && qMap['optB'] != null) optBText = qMap['optB'].toString();
          if (optCText.isEmpty && qMap['optC'] != null) optCText = qMap['optC'].toString();
          if (optDText.isEmpty && qMap['optD'] != null) optDText = qMap['optD'].toString();

          final correctOpt = qMap['correct_option']?.toString().toUpperCase() ??
              qMap['correctOption']?.toString().toUpperCase() ??
              qMap['answer']?.toString().toUpperCase();

          _questions.add({
            'question_text': TextEditingController(text: qMap['question_text']?.toString() ?? qMap['questionText']?.toString() ?? ''),
            'optA': TextEditingController(text: optAText),
            'optB': TextEditingController(text: optBText),
            'optC': TextEditingController(text: optCText),
            'optD': TextEditingController(text: optDText),
            'correct_option': correctOpt,
            'marks': int.tryParse(qMap['marks']?.toString() ?? '1') ?? 1,
            'explanation': TextEditingController(text: qMap['explanation']?.toString() ?? ''),
          });
        }
      }
    } else {
      _titleController = TextEditingController(text: '$defaultCourseName Daily Assessment');
      _descController = TextEditingController(text: 'Post-class concept review and assessment. Questions are randomized.');
      _courseController = TextEditingController(text: defaultCourseName);
      _customDurationController = TextEditingController(text: '15');
      _selectedYear = defaultYear;
    }

    // Default to at least 1 question if list is still empty
    if (_questions.isEmpty) {
      _addQuestion();
    }
  }

  void _addQuestion([int? atIndex]) {
    final newQ = {
      'question_text': TextEditingController(),
      'optA': TextEditingController(),
      'optB': TextEditingController(),
      'optC': TextEditingController(),
      'optD': TextEditingController(),
      'correct_option': null,
      'marks': 1,
      'explanation': TextEditingController(),
    };
    setState(() {
      if (atIndex != null && atIndex >= 0 && atIndex <= _questions.length) {
        _questions.insert(atIndex, newQ);
      } else {
        _questions.add(newQ);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _courseController.dispose();
    _customDurationController.dispose();
    for (final q in _questions) {
      (q['question_text'] as TextEditingController?)?.dispose();
      (q['optA'] as TextEditingController?)?.dispose();
      (q['optB'] as TextEditingController?)?.dispose();
      (q['optC'] as TextEditingController?)?.dispose();
      (q['optD'] as TextEditingController?)?.dispose();
      (q['explanation'] as TextEditingController?)?.dispose();
    }
    super.dispose();
  }

  Widget _buildOptionRow(String label, TextEditingController controller, bool isCorrect, VoidCallback onSelect) {
    return Row(
      children: [
        GestureDetector(
          onTap: onSelect,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCorrect ? const Color(0xFF16A34A) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCorrect ? const Color(0xFF16A34A) : Colors.grey.shade400,
                width: isCorrect ? 2 : 1.2,
              ),
              boxShadow: [
                if (isCorrect)
                  BoxShadow(
                    color: const Color(0xFF16A34A).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Center(
              child: isCorrect
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Option $label text',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: isCorrect
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                          SizedBox(width: 4),
                          Text('Key', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSaveQuiz(bool isPublishNow) async {
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : '${_courseController.text.trim().isNotEmpty ? _courseController.text.trim() : "Python Full stack"} Assessment Quiz';

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one question.')));
      return;
    }

    final formattedQuestions = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final qNum = i + 1;
      final qText = (q['question_text'] as TextEditingController).text.trim();
      final optA = (q['optA'] as TextEditingController).text.trim();
      final optB = (q['optB'] as TextEditingController).text.trim();
      final optC = (q['optC'] as TextEditingController).text.trim();
      final optD = (q['optD'] as TextEditingController).text.trim();
      final correctOpt = q['correct_option']?.toString().toUpperCase();

      if (isPublishNow) {
        if (qText.isEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Question $qNum: Text Missing'),
              content: Text('Please enter the question text for Question $qNum before publishing.'),
              actions: [
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
          return;
        }

        if (optA.isEmpty || optB.isEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Question $qNum: Options Missing'),
              content: Text('Please provide at least Option A and Option B for Question $qNum.'),
              actions: [
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
          return;
        }

        if (correctOpt == null || correctOpt.isEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Question $qNum: Answer Key Required'),
              content: Text('Please tap on circle A, B, C, or D to select the correct answer key for Question $qNum.'),
              actions: [
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
          return;
        }
      }

      final finalOptA = optA.isNotEmpty ? optA : 'Option A';
      final finalOptB = optB.isNotEmpty ? optB : 'Option B';
      final finalOptC = optC.isNotEmpty ? optC : 'Option C';
      final finalOptD = optD.isNotEmpty ? optD : 'Option D';
      final finalCorrectOpt = correctOpt ?? 'A';

      final optionsList = [
        {'id': 'A', 'text': finalOptA},
        {'id': 'B', 'text': finalOptB},
        {'id': 'C', 'text': finalOptC},
        {'id': 'D', 'text': finalOptD},
      ];

      formattedQuestions.add({
        'id': 'q_${i + 1}',
        'question_text': qText.isNotEmpty ? qText : 'Question $qNum',
        'options': optionsList,
        'correct_option': finalCorrectOpt,
        'marks': q['marks'] ?? 1,
        'explanation': (q['explanation'] as TextEditingController).text.trim(),
      });
    }

    if (isPublishNow) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Publish Test Live?'),
          content: const Text('Once published, this question paper will be immediately available to students allotted to you.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Publish Now'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final finalDuration = _isCustomDuration ? (int.tryParse(_customDurationController.text.trim()) ?? 15) : _durationMins;

    setState(() => _isSubmitting = true);

    try {
      final quizPayload = {
        'title': title,
        'description': _descController.text.trim(),
        'courseName': _courseController.text.trim(),
        'targetYear': _selectedYear,
        'targetBranch': _selectedBranch,
        'durationMinutes': finalDuration,
        'totalMarks': formattedQuestions.length,
        'quizType': 'CUSTOM_MCQ',
        'isPublished': isPublishNow,
        'questions': formattedQuestions,
      };

      Map<String, dynamic> res;
      if (widget.editingQuiz != null && widget.editingQuiz!['id'] != null) {
        res = await ApiService.updateQuiz(widget.editingQuiz!['id'].toString(), quizPayload);
      } else {
        res = await ApiService.createQuiz(quizPayload);
      }

      if (!mounted) return;
      widget.onQuizCreated();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (isPublishNow ? 'Question paper published live!' : 'Question paper saved as draft!')),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Save Failed'),
          content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalDuration = _isCustomDuration ? (int.tryParse(_customDurationController.text.trim()) ?? _durationMins) : _durationMins;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: CognitoColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingQuiz != null ? 'Edit MCQ Question Paper' : 'Prepare MCQ Question Paper',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            Text(
              widget.editingQuiz != null ? 'Modify questions, options & answer keys' : 'Randomized Concept Quiz Builder',
              style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: CognitoColors.primary),
            tooltip: 'Add Question',
            onPressed: () => _addQuestion(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: ASSESSMENT BASIC SETTINGS
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 18, color: CognitoColors.primary),
                            SizedBox(width: 8),
                            Text('Assessment Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                          ],
                        ),
                        const Divider(height: 18),

                        const Text('Quiz Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(hintText: 'e.g. Python Loops & Conditional Statements Quiz'),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Duration *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      if (!_isCustomDuration)
                                        GestureDetector(
                                          onTap: () => setState(() => _isCustomDuration = true),
                                          child: const Text('Custom ⏱', style: TextStyle(fontSize: 10.5, color: CognitoColors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (!_isCustomDuration)
                                    DropdownButtonFormField<int>(
                                      value: [5, 10, 15, 20, 30, 45, 60, 90, 120].contains(_durationMins) ? _durationMins : 15,
                                      isExpanded: true,
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                      items: const [
                                        DropdownMenuItem(value: 5, child: Text('5 Mins', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 10, child: Text('10 Mins', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 15, child: Text('15 Mins', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 20, child: Text('20 Mins', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 30, child: Text('30 Mins', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 45, child: Text('45 Mins', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 60, child: Text('60 Mins', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: -1, child: Text('Custom...', overflow: TextOverflow.ellipsis, style: TextStyle(color: CognitoColors.primary, fontWeight: FontWeight.bold))),
                                      ],
                                      onChanged: (val) {
                                        if (val == -1) {
                                          setState(() {
                                            _isCustomDuration = true;
                                            _customDurationController.text = _durationMins.toString();
                                          });
                                        } else {
                                          setState(() {
                                            _durationMins = val ?? 15;
                                            _customDurationController.text = _durationMins.toString();
                                          });
                                        }
                                      },
                                    )
                                  else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _customDurationController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              hintText: 'Mins',
                                              suffixText: 'mins',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            onChanged: (val) {
                                              final parsed = int.tryParse(val.trim());
                                              if (parsed != null && parsed > 0) {
                                                _durationMins = parsed;
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.list_alt_rounded, size: 20, color: CognitoColors.primary),
                                          tooltip: 'Preset options',
                                          onPressed: () => setState(() => _isCustomDuration = false),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Target Year *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _selectedYear,
                                    isExpanded: true,
                                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                    items: const [
                                      DropdownMenuItem(value: 'ALL', child: Text('All Years', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '1st Year', child: Text('1st Year', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '2nd Year', child: Text('2nd Year', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '3rd Year', child: Text('3rd Year', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '4th Year', child: Text('4th Year', overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (val) => setState(() => _selectedYear = val ?? '2nd Year'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Target Branch *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _selectedBranch,
                                    isExpanded: true,
                                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                    items: const [
                                      DropdownMenuItem(value: 'ALL', child: Text('All Branches', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'CSE', child: Text('CSE', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'AI&DS', child: Text('AI&DS', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'AIML', child: Text('AIML', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'ECE', child: Text('ECE', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'EEE', child: Text('EEE', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'MECH', child: Text('MECH', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'CIVIL', child: Text('CIVIL', overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (val) => setState(() => _selectedBranch = val ?? 'ALL'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Course Track', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _courseController,
                                    decoration: const InputDecoration(
                                      hintText: 'Course name',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const Text('Instructions / Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _descController,
                          maxLines: 2,
                          decoration: const InputDecoration(hintText: 'Brief instructions for students...'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // OVERVIEW BAR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: CognitoColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Duration: $finalDuration Mins',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_questions.length} Question${_questions.length > 1 ? 's' : ''} • ${_questions.length} Mark${_questions.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SECTION 2: QUESTIONS BUILDER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUESTIONS (${_questions.length})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CognitoColors.textSecondary, letterSpacing: 0.8),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _addQuestion(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Question', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CognitoColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // List of Question Cards
                  ...List.generate(_questions.length, (idx) {
                    final q = _questions[idx];
                    final hasSelectedAnswer = q['correct_option'] != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasSelectedAnswer ? const Color(0xFF86EFAC) : Colors.grey.shade300,
                          width: hasSelectedAnswer ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: CognitoColors.primary.withOpacity(0.1),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Question ${idx + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CognitoColors.textDark),
                                  ),
                                  const SizedBox(width: 8),
                                  if (hasSelectedAnswer)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Key: Option ${q['correct_option']}',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'No Answer Selected',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                      ),
                                    ),
                                ],
                              ),
                              if (_questions.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                  onPressed: () => setState(() => _questions.removeAt(idx)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: q['question_text'] as TextEditingController,
                            maxLines: 2,
                            decoration: const InputDecoration(hintText: 'Enter question text...'),
                          ),
                          const SizedBox(height: 12),

                          // Option selector header
                          Row(
                            children: [
                              const Text('Options & Select Correct Key:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                              const SizedBox(width: 6),
                              Text('(Tap circle to select key)', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          const SizedBox(height: 8),

                          _buildOptionRow('A', q['optA'], q['correct_option'] == 'A', () => setState(() => q['correct_option'] = 'A')),
                          const SizedBox(height: 8),
                          _buildOptionRow('B', q['optB'], q['correct_option'] == 'B', () => setState(() => q['correct_option'] = 'B')),
                          const SizedBox(height: 8),
                          _buildOptionRow('C', q['optC'], q['correct_option'] == 'C', () => setState(() => q['correct_option'] = 'C')),
                          const SizedBox(height: 8),
                          _buildOptionRow('D', q['optD'], q['correct_option'] == 'D', () => setState(() => q['correct_option'] = 'D')),
                          const SizedBox(height: 12),

                          TextField(
                            controller: q['explanation'] as TextEditingController,
                            decoration: const InputDecoration(
                              hintText: 'Explanation / Solution hint (optional)',
                              prefixIcon: Icon(Icons.lightbulb_outline_rounded, size: 16),
                            ),
                          ),

                          // Add next question right below
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
                            ),
                            child: InkWell(
                              onTap: () => _addQuestion(idx + 1),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_circle_outline_rounded, size: 16, color: CognitoColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      idx == _questions.length - 1 ? '+ Add Next Question (Question ${idx + 2})' : '+ Insert Question After Q${idx + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: CognitoColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Fixed Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _handleSaveQuiz(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.editingQuiz != null ? 'Save Draft' : 'Save as Draft',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _handleSaveQuiz(true),
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isSubmitting
                                ? 'Saving...'
                                : (widget.editingQuiz != null && widget.editingQuiz!['is_published'] == true
                                    ? 'Update & Publish'
                                    : 'Publish Paper Live'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FULL MOBILE SCREEN: GOOGLE FORM ASSESSMENT TEST LINK & EDITOR
// ============================================================================
class CreateGoogleFormQuizScreen extends StatefulWidget {
  final Map<String, dynamic>? editingQuiz;
  final Map<String, dynamic>? trainerProfile;
  final Map<String, dynamic>? userProfile;
  final VoidCallback onQuizCreated;

  const CreateGoogleFormQuizScreen({
    super.key,
    this.editingQuiz,
    this.trainerProfile,
    this.userProfile,
    required this.onQuizCreated,
  });

  @override
  State<CreateGoogleFormQuizScreen> createState() => _CreateGoogleFormQuizScreenState();
}

class _CreateGoogleFormQuizScreenState extends State<CreateGoogleFormQuizScreen> {
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  late TextEditingController _descController;
  late TextEditingController _courseController;

  late String _selectedYear;
  String _selectedBranch = 'ALL';
  int _durationMins = 20;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final defaultCourseName = widget.trainerProfile?['assignments']?[0]?['course_name'] ?? 'Python Full stack';

    String defaultYear = '2nd Year';
    final assignments = widget.trainerProfile?['assignments'] as List<dynamic>?;
    if (assignments != null && assignments.isNotEmpty) {
      final ty = assignments[0]['target_years'] as List<dynamic>?;
      if (ty != null && ty.isNotEmpty) {
        defaultYear = ty[0].toString();
      }
    }

    if (widget.editingQuiz != null) {
      final eq = widget.editingQuiz!;
      _titleController = TextEditingController(text: eq['title']?.toString() ?? '');
      _urlController = TextEditingController(text: eq['google_form_url']?.toString() ?? eq['googleFormUrl']?.toString() ?? '');
      _descController = TextEditingController(text: eq['description']?.toString() ?? '');
      _courseController = TextEditingController(
        text: eq['course_name']?.toString() ?? eq['courseName']?.toString() ?? defaultCourseName,
      );
      _selectedYear = eq['target_year']?.toString() ?? eq['targetYear']?.toString() ?? defaultYear;
      _selectedBranch = eq['target_branch']?.toString() ?? eq['targetBranch']?.toString() ?? 'ALL';
      final d = eq['duration_minutes'] ?? eq['durationMinutes'];
      _durationMins = d != null ? (int.tryParse(d.toString()) ?? 20) : 20;
    } else {
      _titleController = TextEditingController(text: '$defaultCourseName Google Form Test');
      _urlController = TextEditingController();
      _descController = TextEditingController(text: 'Google Form test link. Submit within 20 mins.');
      _courseController = TextEditingController(text: defaultCourseName);
      _selectedYear = defaultYear;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(bool isPublishNow) async {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test title is required.')));
      return;
    }
    if (isPublishNow && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Form link is required to publish.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final quizPayload = {
        'title': title,
        'description': _descController.text.trim(),
        'courseName': _courseController.text.trim(),
        'targetYear': _selectedYear,
        'targetBranch': _selectedBranch,
        'durationMinutes': _durationMins,
        'quizType': 'GOOGLE_FORM',
        'googleFormUrl': url,
        'isPublished': isPublishNow,
      };

      Map<String, dynamic> res;
      if (widget.editingQuiz != null && widget.editingQuiz!['id'] != null) {
        res = await ApiService.updateQuiz(widget.editingQuiz!['id'].toString(), quizPayload);
      } else {
        res = await ApiService.createQuiz(quizPayload);
      }

      if (!mounted) return;
      widget.onQuizCreated();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (isPublishNow ? 'Google Form test published live to students!' : 'Draft saved successfully!')),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save Failed: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: CognitoColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: CognitoColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingQuiz != null ? 'Edit Google Form Test' : 'Add Google Form Test Link',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            Text(
              widget.editingQuiz != null ? 'Modify link, track & test settings' : 'External Online Assessment',
              style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quiz / Test Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: 'e.g. Python Full Stack Google Form Quiz'),
                    ),
                    const SizedBox(height: 14),

                    const Text('Google Form / External URL *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(hintText: 'https://docs.google.com/forms/d/e/.../viewform'),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<int>(
                                value: _durationMins,
                                isExpanded: true,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10 Mins', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 15, child: Text('15 Mins', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 20, child: Text('20 Mins', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 30, child: Text('30 Mins', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 45, child: Text('45 Mins', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 60, child: Text('60 Mins', overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) => setState(() => _durationMins = val ?? 20),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedYear,
                                isExpanded: true,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: const [
                                  DropdownMenuItem(value: 'ALL', child: Text('All Years', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: '1st Year', child: Text('1st Year', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: '2nd Year', child: Text('2nd Year', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: '3rd Year', child: Text('3rd Year', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: '4th Year', child: Text('4th Year', overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) => setState(() => _selectedYear = val ?? '2nd Year'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text('Instructions for Students', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Enter student instructions...'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sticky Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => _handleSave(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.editingQuiz != null ? 'Save Draft' : 'Save as Draft',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _handleSave(true),
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isSubmitting
                                ? 'Saving...'
                                : (widget.editingQuiz != null && widget.editingQuiz!['is_published'] == true
                                    ? 'Update & Publish'
                                    : 'Publish Paper Live'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

