import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'qr_scanner_screen.dart';
import 'attendance_screen.dart';
import 'behaviour_screen.dart';
import 'materials_screen.dart';
import 'profile_screen.dart';
import 'take_quiz_screen.dart';
import 'quiz_result_screen.dart';
import 'student_assessments_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const StudentDashboardScreen({super.key, this.userProfile});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentTabIndex = 0;
  late Map<String, dynamic> _user;
  List<dynamic> _todaySessions = [];
  List<dynamic> _announcements = [];
  Map<String, dynamic> _attendanceSummary = {};
  Map<String, dynamic> _behaviourData = {};
  List<dynamic> _materials = [];
  List<dynamic> _quizzes = [];
  bool _hasMarkedToday = false;
  Timer? _windowTimer;

  // Working attendance window: 09:00 AM to 04:00 PM daily
  String get _attendanceWindowStatus {
    final now = DateTime.now();
    if (now.hour < 9) return 'NOT_OPEN_YET';
    if (now.hour >= 16) return 'TIMED_OUT';
    return 'OPEN';
  }

  bool get _isAttendanceWindowOpen => _attendanceWindowStatus == 'OPEN';

  String _getTodayFormatted() {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    final dayStr = now.day.toString().padLeft(2, '0');
    return '$dayName, $dayStr $monthName ${now.year}';
  }

  String _getShortTodayDate() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[now.month - 1];
    final dayStr = now.day.toString().padLeft(2, '0');
    return '$dayStr $monthName ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    _user = widget.userProfile ?? {};
    _loadDashboardData();
    // Live timer to refresh attendance window status (e.g. at 4:00 PM sharp)
    _windowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _windowTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final studentId = _user['id'] ?? _user['userId'] ?? 'unknown';

    try {
      final prefs = await SharedPreferences.getInstance();
      final localMarked = prefs.getBool('marked_today_${studentId}_$todayStr') ?? false;
      if (mounted && localMarked) {
        setState(() => _hasMarkedToday = true);
      }

      final sess = await ApiService.getTodaySessions();
      final ann = await ApiService.getAnnouncements();
      final att = await ApiService.getStudentAttendance();
      final beh = await ApiService.getStudentBehaviour();
      final mat = await ApiService.getMaterials();
      final qz = await ApiService.getQuizzes();

      final serverMarked = att['hasMarkedToday'] == true || att['summary']?['hasMarkedToday'] == true;
      final isMarked = localMarked || serverMarked;
      if (serverMarked) {
        await prefs.setBool('marked_today_${studentId}_$todayStr', true);
      }

      if (mounted) {
        setState(() {
          _todaySessions = sess;
          _announcements = ann;
          _attendanceSummary = att['summary'] ?? {};
          _behaviourData = beh;
          _materials = mat;
          _quizzes = qz;
          _hasMarkedToday = isMarked;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeTab(),
      const AttendanceScreen(),
      const StudentAssessmentsScreen(),
      const MaterialsScreen(),
      const BehaviourScreen(),
      ProfileScreen(userProfile: _user),
    ];

    return Scaffold(
      backgroundColor: CognitoColors.background,
      body: screens[_currentTabIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: CognitoColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: CognitoColors.primary,
          unselectedItemColor: CognitoColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Assessments'),
            BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), activeIcon: Icon(Icons.folder), label: 'Materials'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_graph_outlined), activeIcon: Icon(Icons.auto_graph), label: 'Behaviour'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final college = _user['college'] ?? {};
    final student = _user['student'] ?? {};

    final collegeName = college['shortName'] ?? college['name'] ?? 'KITS Divili';
    final fullName = _user['fullName'] ?? 'Student User';
    final branch = student['branch'] ?? 'CSE';
    final year = student['year'] ?? '3rd Year';
    final section = student['section'] ?? 'A';
    final primaryColor = CognitoColors.parseHex(college['primaryColor']);
    final logoUrl = college['logoUrl'];
    final activeSession = _todaySessions.isNotEmpty ? _todaySessions.first : null;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // DYNAMIC COLLEGE BRANDING HERO HEADER
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, CognitoColors.darkBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: College Brand & Seal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: collegeName.toLowerCase().contains('adarsh')
                                      ? Image.asset('assets/images/adharsh_logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.school, color: CognitoColors.primary))
                                      : collegeName.toLowerCase().contains('kits')
                                          ? Image.asset('assets/images/kits_logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.school, color: CognitoColors.primary))
                                          : (logoUrl != null
                                              ? Image.network('${ApiService.hostUrl}$logoUrl', errorBuilder: (_, __, ___) => const Icon(Icons.school, color: CognitoColors.primary))
                                              : const Icon(Icons.account_balance_outlined, color: CognitoColors.primary)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        collegeName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'COGNITO TECH HUB PARTNER',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                                SizedBox(width: 5),
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Student Name & Academic Banner
                      Text(
                        'Good Morning, $fullName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'B.Tech $branch | $year | Section $section',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Live Date Display Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '📅 Today: ${_getTodayFormatted()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Metric Pill Row (Real Dynamic Metrics Starting From 0)
                      Builder(builder: (_) {
                        final totalSessions = _attendanceSummary['totalSessions'] ?? 0;
                        final attPct = _attendanceSummary['overallPercentage'] ?? 0;
                        final presentCount = _attendanceSummary['presentCount'] ?? 0;
                        final hasBeh = _behaviourData['hasEvaluations'] == true;
                        final behScore = _behaviourData['behaviour']?['attendance_consistency'] ?? 0;

                        final attText = totalSessions == 0
                            ? '0% Attendance (0 Sessions)'
                            : '$attPct% Attendance ($presentCount/$totalSessions Sessions)';
                        final behText = !hasBeh || behScore == 0 ? 'Pending Evaluation' : '$behScore% Behaviour';

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _heroPill(Icons.check_circle_outline, attText, Colors.white),
                            _heroPill(Icons.star_outline, behText, Colors.white),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Content Padding
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ASSIGNED FACULTY / TRAINER CARD
                  Builder(builder: (_) {
                    final studentYear = (_user['student']?['year'] ?? _user['year'] ?? '2nd Year').toString();
                    final roll = (_user['student']?['roll_number'] ?? _user['roll_number'] ?? '').toString().toUpperCase();
                    final branch = (_user['student']?['branch'] ?? _user['branch'] ?? '').toString().toUpperCase();
                    final is2nd = studentYear.contains('2') || roll.startsWith('24HN') || roll.startsWith('25HN5');
                    final is4th = studentYear.contains('4') || roll.startsWith('21HN') || roll.startsWith('22HN');
                    final isAidsOrAiml = branch.contains('AI') || branch.contains('DS') || branch.contains('ML') || roll.contains('A54') || roll.contains('A42');

                    Map<String, dynamic> defaultTrainer;
                    if (is2nd || (is4th && isAidsOrAiml)) {
                      defaultTrainer = {
                        'full_name': 'Sushma Elisala',
                        'course_name': 'Python Full stack',
                        'email': 'vsushmaelisala@gmail.com',
                        'mobile': '+91 98888 33333'
                      };
                    } else {
                      // 3rd year / other 4th year branches -> Allotted to Pathivada Daiva Rao
                      defaultTrainer = {
                        'full_name': 'Pathivada Daiva Rao',
                        'course_name': 'Java full stack',
                        'email': 'daivaraopathivada@gmail.com',
                        'mobile': '+91 98888 44444'
                      };
                    }

                    // 1. Check explicit trainer allocation in _behaviourData
                    Map<String, dynamic>? explicitTrainer;
                    if (_behaviourData['trainer_notes'] != null) {
                      try {
                        final tn = _behaviourData['trainer_notes'];
                        final parsed = tn is Map ? tn : jsonDecode(tn.toString());
                        if (parsed is Map && (parsed['assigned_trainer_name'] != null || parsed['assigned_trainer_id'] != null)) {
                          explicitTrainer = {
                            'full_name': parsed['assigned_trainer_name'] ?? 'Assigned Faculty',
                            'name': parsed['assigned_trainer_name'] ?? 'Assigned Faculty',
                            'email': parsed['assigned_trainer_email'] ?? '',
                            'course_name': parsed['course_name'] ?? (is2nd ? 'Python Full stack' : 'Java full stack'),
                            'mobile': '+91 98888 33333',
                          };
                        }
                      } catch (_) {}
                    }

                    var trainer = explicitTrainer ?? _user['assignedTrainer'] ?? _user['assigned_trainer'] ?? defaultTrainer;

                    final trainerName = trainer['full_name'] ?? trainer['name'] ?? defaultTrainer['full_name']!;
                    final courseName = trainer['course_name'] ?? defaultTrainer['course_name']!;
                    final email = trainer['email'] ?? defaultTrainer['email']!;
                    final mobile = trainer['mobile'] ?? defaultTrainer['mobile']!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.school, color: Color(0xFF15803D), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trainerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: CognitoColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Assigned Faculty • $courseName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF166534),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF166534),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'FACULTY',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFBBF7D0)),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.email_outlined, size: 14, color: Color(0xFF15803D)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: CognitoColors.textDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF15803D)),
                                  const SizedBox(width: 6),
                                  Text(
                                    mobile,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CognitoColors.textDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // ACTIVE QUIZ HERO ALERT BANNER (If any live tests are pending)
                  Builder(builder: (_) {
                    final pending = _quizzes.where((q) => q['is_published'] == true && q['has_submitted'] != true).toList();
                    if (pending.isEmpty) return const SizedBox.shrink();
                    final firstQuiz = pending.first;
                    final qTitle = firstQuiz['title'] ?? 'Daily Assessment Test';
                    final qDuration = firstQuiz['duration_minutes'] ?? 15;
                    final qTrainer = firstQuiz['trainer_name'] ?? 'Faculty Trainer';
                    final qId = firstQuiz['id']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text('LIVE TEST ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text('⏱ $qDuration MINS', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            qTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Published by $qTrainer • 1 Attempt Only',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TakeQuizScreen(
                                      quizId: qId,
                                      quizTitle: qTitle,
                                    ),
                                  ),
                                ).then((_) => _loadDashboardData());
                              },
                              icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF1E3A8A), size: 18),
                              label: const Text(
                                'ATTEMPT QUIZ NOW',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E3A8A)),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // TODAY'S SESSION & ATTENDANCE QR CTA CARD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Classroom Session",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CognitoColors.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CognitoColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _getShortTodayDate(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: CognitoColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CognitoColors.border),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_hasMarkedToday)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF15803D)),
                                    SizedBox(width: 5),
                                    Text(
                                      'ATTENDANCE COMPLETED • PRESENT',
                                      style: TextStyle(
                                        color: Color(0xFF15803D),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_attendanceWindowStatus == 'TIMED_OUT')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.access_time_rounded, size: 13, color: Color(0xFFDC2626)),
                                    SizedBox(width: 5),
                                    Text(
                                      'ATTENDANCE WINDOW: 09:00 AM – 04:00 PM',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_attendanceWindowStatus == 'NOT_OPEN_YET')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFC7D2FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF4338CA)),
                                    SizedBox(width: 5),
                                    Text(
                                      'OPENS TODAY AT 09:00 AM',
                                      style: TextStyle(
                                        color: Color(0xFF4338CA),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CognitoColors.lightBlue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ATTENDANCE ACTIVE • 09:00 AM – 04:00 PM',
                                  style: TextStyle(
                                    color: CognitoColors.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, size: 14, color: CognitoColors.textSecondary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '09:00 AM – 04:00 PM',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          activeSession?['title'] ?? 'Python OOP & Data Structures',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: CognitoColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeSession?['description'] ?? 'Deep dive into Object Oriented Architecture, classes, and Pythonic design patterns.',
                          style: const TextStyle(fontSize: 13, color: CognitoColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_pin_circle_outlined, size: 16, color: CognitoColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Trainer: ${activeSession?['trainer_name'] ?? 'Priya Sharma (Python Specialist)'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ATTENDANCE ACTION AREA
                        // When student has marked today, show verified status; otherwise show Scan QR button.
                        if (_hasMarkedToday) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5), width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Attendance verified for today's session. Re-scanning locked until next session."),
                                    backgroundColor: Color(0xFF15803D),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 26),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          "TODAY'S ATTENDANCE COMPLETED",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                            color: Color(0xFF15803D),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          "Verified & Synced to Database",
                                          style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                                  );
                                  if (res == true) {
                                    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                                    final studentId = _user['id'] ?? _user['userId'] ?? 'unknown';
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('marked_today_${studentId}_$todayStr', true);
                                    setState(() => _hasMarkedToday = true);
                                    _loadDashboardData();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CognitoColors.primary,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                                label: const Text(
                                  'SCAN ATTENDANCE QR',
                                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.timer_outlined, size: 12, color: CognitoColors.textSecondary),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Daily Window: 09:00 AM – 04:00 PM',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: CognitoColors.textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // DAILY ASSESSMENT QUIZZES & TESTS SECTION
                  _buildDailyQuizzesSection(),
                  const SizedBox(height: 24),

                  // Quick Action Grid (Live Dynamic Values)
                  Builder(builder: (_) {
                    final totalSessions = _attendanceSummary['totalSessions'] ?? 0;
                    final attPct = _attendanceSummary['overallPercentage'] ?? 0;
                    final hasBeh = _behaviourData['hasEvaluations'] == true;
                    final behScore = _behaviourData['behaviour']?['attendance_consistency'] ?? 0;
                    final attSub = totalSessions == 0 ? '0% Consistent' : '$attPct% Consistent';
                    final matSub = '${_materials.length} Resources';

                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.18,
                      children: [
                        _actionCard(
                          'My Attendance',
                          attSub,
                          Icons.calendar_today_outlined,
                          CognitoColors.primary,
                          () => setState(() => _currentTabIndex = 1),
                        ),
                        _actionCard(
                          'Study Hub',
                          matSub,
                          Icons.folder_outlined,
                          const Color(0xFF007A78),
                          () => setState(() => _currentTabIndex = 2),
                        ),
                        _actionCard(
                          'Performance',
                          !hasBeh || behScore == 0 ? 'Evaluating' : '$behScore% Score',
                          Icons.auto_graph_outlined,
                          const Color(0xFF7C3AED),
                          () => setState(() => _currentTabIndex = 3),
                        ),
                        _actionCard(
                          'My Profile',
                          'Academic ID',
                          Icons.account_circle_outlined,
                          const Color(0xFFD97706),
                          () => setState(() => _currentTabIndex = 4),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 24),

                  // Tech Hub Notices & Announcements
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Tech Hub Notices & Updates',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: CognitoColors.lightBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_announcements.length} Active',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_announcements.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: CognitoColors.border),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline_rounded, color: CognitoColors.textSecondary, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No new institutional notices at this time.',
                              style: TextStyle(fontSize: 12.5, color: CognitoColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._announcements.map((a) {
                      final priority = (a['priority'] ?? 'MEDIUM').toString().toUpperCase();
                      final isUrgent = priority == 'URGENT';
                      final isHigh = priority == 'HIGH';
                      final badgeColor = isUrgent
                          ? const Color(0xFFEF4444)
                          : isHigh
                              ? const Color(0xFFF59E0B)
                              : CognitoColors.primary;

                      final collegeBadge = a['college_name'] ?? 'All Campuses';
                      final author = a['author_name'] ?? 'Program Office';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUrgent ? const Color(0xFFFCA5A5) : CognitoColors.border,
                            width: isUrgent ? 1.5 : 1,
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    priority,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    collegeBadge,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  author,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CognitoColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              a['title'] ?? 'Notice',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: CognitoColors.textDark),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a['message'] ?? '',
                              style: const TextStyle(fontSize: 12.5, color: CognitoColors.textSecondary, height: 1.35),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CognitoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyQuizzesSection() {
    final activeQuizzes = _quizzes.where((q) => q['is_published'] == true).toList();
    final availableTests = activeQuizzes.where((q) => q['has_submitted'] != true).toList();
    final completedTests = activeQuizzes.where((q) => q['has_submitted'] == true).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Trainers Live Assessments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _currentTabIndex = 2),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Assessments Portal Shortcut Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFF6FF), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CognitoColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, color: CognitoColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dedicated Assessment Center',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: CognitoColors.textDark),
                        ),
                        Text(
                          '${availableTests.length} Live Test${availableTests.length == 1 ? '' : 's'} • ${completedTests.length} Submitted',
                          style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Access Live Tests (Not Attempted), Pending Results, and View Assessment Results with score breakdown & answer sheets.',
                style: TextStyle(fontSize: 11.5, color: CognitoColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _currentTabIndex = 2),
                  icon: const Icon(Icons.launch_rounded, size: 16),
                  label: const Text(
                    'OPEN ASSESSMENTS MODULE',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CognitoColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
