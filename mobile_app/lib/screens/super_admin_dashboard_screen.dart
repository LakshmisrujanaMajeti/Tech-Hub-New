import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'login_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const SuperAdminDashboardScreen({super.key, required this.userProfile});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _currentTab = 0;
  bool _isLoading = true;
  String? _selectedCollegeId; // null = all registered hubs
  Timer? _syncTimer;

  List<dynamic> _registeredColleges = [];
  Map<String, dynamic> _overviewMetrics = {};
  List<dynamic> _programManagers = [];
  List<dynamic> _collegeStaff = [];
  List<dynamic> _trainers = [];
  List<dynamic> _courses = [];
  List<dynamic> _todaySlots = [];
  List<dynamic> _notices = [];

  // Attendance Slot State
  Map<String, dynamic>? _generatedSlotData;
  bool _isGeneratingSlot = false;
  String _selectedSlotName = 'Morning Technical Slot (09:00 AM - 01:00 PM)';
  String _selectedSlotDuration = '30';

  // Student Nominal Register State
  String _studentSearchQuery = '';
  String _studentSelectedBranch = 'all';
  String _studentSelectedYear = 'all';
  String _studentSelectedStatus = 'all';
  final TextEditingController _studentSearchController = TextEditingController();
  Future<Map<String, dynamic>>? _studentsFuture;

  String? get _userCollegeId =>
      widget.userProfile['college_id']?.toString() ??
      widget.userProfile['collegeId']?.toString() ??
      widget.userProfile['college']?['id']?.toString();

  bool get _isCollegeStaff {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    return role == 'COLLEGE_ADMIN' || role == 'TPO';
  }

  Map<String, dynamic> get _currentCollegeInfo {
    if (_registeredColleges.isNotEmpty) {
      final match = _registeredColleges.firstWhere(
        (c) => c['id'].toString() == _userCollegeId.toString(),
        orElse: () => _registeredColleges.first,
      );
      if (match is Map<String, dynamic>) return match;
    }
    if (widget.userProfile['college'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(widget.userProfile['college']);
    }
    return {
      'id': _userCollegeId,
      'college_name': widget.userProfile['college_name'] ?? widget.userProfile['collegeName'] ?? 'College Campus',
      'short_name': widget.userProfile['college_name'] ?? widget.userProfile['collegeName'] ?? 'Campus Tech Hub',
      'college_code': 'HUB',
    };
  }

  void _refreshStudentsFuture() {
    final effectiveColId = _isCollegeStaff ? _userCollegeId : _selectedCollegeId;

    _studentsFuture = ApiService.getStudents(
      collegeId: effectiveColId,
      branch: _studentSelectedBranch,
      year: _studentSelectedYear,
      search: _studentSearchQuery,
      attendanceStatus: _studentSelectedStatus,
      limit: 100,
    );
  }

  @override
  void initState() {
    super.initState();
    if (_isCollegeStaff) {
      _selectedCollegeId = _userCollegeId;
    }
    _refreshStudentsFuture();
    _loadDashboardData();
    // Realtime analytics sync every 15 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadDashboardData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool isBackground = false}) async {
    if (!isBackground) setState(() => _isLoading = true);
    try {
      final effectiveColId = _isCollegeStaff ? _userCollegeId : _selectedCollegeId;

      final results = await Future.wait([
        ApiService.getRegisteredColleges(),
        ApiService.getAnalyticsOverview(effectiveColId),
        ApiService.getProgramManagers(),
        ApiService.getCollegeStaff(collegeId: effectiveColId),
        ApiService.getTrainers(effectiveColId),
        ApiService.getCourses(),
        ApiService.getTodayAttendanceSlots(collegeId: effectiveColId),
        ApiService.getAnnouncements(collegeId: effectiveColId),
      ]);

      if (mounted) {
        setState(() {
          _registeredColleges = results[0] as List<dynamic>;
          _overviewMetrics = results[1] as Map<String, dynamic>;
          _programManagers = results[2] as List<dynamic>;
          _collegeStaff = results[3] as List<dynamic>;
          _trainers = results[4] as List<dynamic>;
          _courses = results[5] as List<dynamic>;
          _todaySlots = results[6] as List<dynamic>;
          _notices = results[7] as List<dynamic>;
          _isLoading = false;
          if (!isBackground) {
            _refreshStudentsFuture();
          }
        });
      }
    } catch (e) {
      if (mounted && !isBackground) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCollegeSelect(String? collegeId) async {
    if (_isCollegeStaff) return; // Strict lock: college staff can never switch campuses
    setState(() {
      _selectedCollegeId = collegeId;
      _refreshStudentsFuture();
      _isLoading = true;
    });
    try {
      final results = await Future.wait([
        ApiService.getAnalyticsOverview(collegeId),
        ApiService.getTrainers(collegeId),
        ApiService.getAnnouncements(collegeId: collegeId),
      ]);
      if (mounted) {
        setState(() {
          _overviewMetrics = results[0] as Map<String, dynamic>;
          _trainers = results[1] as List<dynamic>;
          _notices = results[2] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _showAddProgramManagerModal() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    final passwordController = TextEditingController(text: 'Cognito@123');
    String? assignedCollegeId = _selectedCollegeId;
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
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: CognitoColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Add Program Manager',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create an executive manager to oversee partner engineering campuses.',
                  style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Enter full name'),
                ),
                const SizedBox(height: 14),
                const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Enter email address'),
                ),
                const SizedBox(height: 14),
                const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Enter 10-digit mobile number'),
                ),
                const SizedBox(height: 14),
                const Text('Initial Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: 'Enter password'),
                ),
                const SizedBox(height: 14),
                const Text('Campus Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: assignedCollegeId,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Registered Campuses (HQ Global)')),
                    ..._registeredColleges.map((c) => DropdownMenuItem(
                          value: c['id'].toString(),
                          child: Text(c['short_name'] ?? c['college_name']),
                        )),
                  ],
                  onChanged: (val) => setModalState(() => assignedCollegeId = val),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final email = emailController.text.trim();
                            final pwd = passwordController.text.trim();
                            if (name.isEmpty || email.isEmpty || pwd.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill all required fields.')),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.createProgramManager(
                                fullName: name,
                                email: email,
                                mobile: mobileController.text.trim(),
                                password: pwd,
                                collegeId: assignedCollegeId,
                              );
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Program Manager "$name" created successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            } catch (err) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${err.toString().replaceAll("Exception: ", "")}'), backgroundColor: CognitoColors.danger),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('CREATE PROGRAM MANAGER', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProgramManagerModal(Map<String, dynamic> pm) {
    final nameController = TextEditingController(text: pm['full_name'] ?? '');
    final emailController = TextEditingController(text: pm['email'] ?? '');
    final mobileController = TextEditingController(text: pm['mobile'] ?? '');
    final passwordController = TextEditingController();
    String? assignedCollegeId = pm['college_id']?.toString();
    String status = pm['status'] ?? 'ACTIVE';
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
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: CognitoColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Edit Program Manager',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Update account permissions and campus assignments for ${pm['full_name']}.',
                  style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Enter full name'),
                ),
                const SizedBox(height: 14),
                const Text('Email Address (Read-only)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    fillColor: Colors.grey.shade100,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Enter 10-digit mobile number'),
                ),
                const SizedBox(height: 14),
                const Text('Reset Password (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: 'Leave blank to keep current password'),
                ),
                const SizedBox(height: 14),
                const Text('Campus Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: assignedCollegeId,
                  decoration: const InputDecoration(hintText: 'Select assigned campus'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('HQ (Cross-College / All Hubs)'),
                    ),
                    ..._registeredColleges.map((c) => DropdownMenuItem<String?>(
                          value: c['id'].toString(),
                          child: Text(c['short_name'] ?? c['college_name']),
                        )),
                  ],
                  onChanged: (val) => setModalState(() => assignedCollegeId = val),
                ),
                const SizedBox(height: 14),
                const Text('Account Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(hintText: 'Select status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                  ],
                  onChanged: (val) => setModalState(() => status = val ?? 'ACTIVE'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CognitoColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Full name cannot be empty.'), backgroundColor: CognitoColors.danger),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.updateProgramManager(
                                pm['id'].toString(),
                                fullName: name,
                                mobile: mobileController.text.trim(),
                                password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null,
                                status: status,
                                collegeId: assignedCollegeId,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Program Manager "$name" updated successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            } catch (err) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${err.toString().replaceAll("Exception: ", "")}'), backgroundColor: CognitoColors.danger),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAllocateTrainerModal({
    Map<String, dynamic>? singleStudent,
    List<dynamic>? candidateStudents,
    String? preselectedTrainerId,
  }) {
    // List of trainers: defaults for Elisala Sushma & Daiva Rao, plus any dynamically loaded trainers
    final List<Map<String, dynamic>> availableTrainers = [
      {
        'id': '48632025-1678-4014-925a-86391063614b',
        'full_name': 'Sushma Elisala',
        'email': 'vsushmaelisala@gmail.com',
        'course_name': 'Python Full stack',
        'years': '2nd & 4th Year',
        'badge': 'Python Tutor (2nd & 4th Year)',
        'badgeColor': const Color(0xFF15803D),
        'badgeBg': const Color(0xFFDCFCE7),
      },
      {
        'id': '0ed2be5c-fce6-4e4f-83eb-96be2b162746',
        'full_name': 'Pathivada Daiva Rao',
        'email': 'daivaraopathivada@gmail.com',
        'course_name': 'Java full stack',
        'years': '3rd & 4th Year',
        'badge': 'Java Tutor (3rd & 4th Year)',
        'badgeColor': const Color(0xFF1E40AF),
        'badgeBg': const Color(0xFFDBEAFE),
      },
    ];

    // Add dynamically loaded trainers if not already present
    for (final tr in _trainers) {
      final tid = tr['id']?.toString();
      if (tid != null && !availableTrainers.any((t) => t['id'] == tid)) {
        final assns = (tr['assignments'] as List?) ?? [];
        final firstAssn = assns.isNotEmpty ? assns.first : null;
        final cName = firstAssn?['course_name'] ?? 'Technical Training';
        final yList = (firstAssn?['target_years'] as List?)?.map((e) => e.toString()).toList() ?? [];
        availableTrainers.add({
          'id': tid,
          'full_name': tr['full_name'] ?? 'Trainer',
          'email': tr['email'] ?? '',
          'course_name': cName,
          'years': yList.isNotEmpty ? yList.join(', ') : 'All Years',
          'badge': 'Faculty',
          'badgeColor': CognitoColors.primary,
          'badgeBg': CognitoColors.primary.withOpacity(0.1),
        });
      }
    }

    String selectedTrainerId = preselectedTrainerId ??
        (availableTrainers.isNotEmpty ? availableTrainers.first['id'] : '');
    
    final selectedTrainer = availableTrainers.firstWhere(
      (t) => t['id'] == selectedTrainerId,
      orElse: () => availableTrainers.first,
    );
    final courseController = TextEditingController(text: selectedTrainer['course_name'] ?? 'Python Full Stack & AI');

    // Selected student IDs set
    final Set<String> selectedStudentIds = {};
    if (singleStudent != null) {
      final sid = (singleStudent['id'] ?? singleStudent['student_id'] ?? '').toString();
      if (sid.isNotEmpty) selectedStudentIds.add(sid);
    } else if (candidateStudents != null && candidateStudents.isNotEmpty) {
      for (final s in candidateStudents) {
        final sid = (s['id'] ?? s['student_id'] ?? '').toString();
        if (sid.isNotEmpty) selectedStudentIds.add(sid);
      }
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final activeTrainer = availableTrainers.firstWhere(
            (t) => t['id'] == selectedTrainerId,
            orElse: () => availableTrainers.first,
          );
          final isSushma = (activeTrainer['full_name'] ?? '').toString().toLowerCase().contains('sushma');

          return Container(
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CognitoColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.assignment_ind_rounded, color: CognitoColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Student–Trainer Allocation',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                            ),
                            Text(
                              singleStudent != null
                                  ? 'Allot faculty to ${singleStudent['full_name'] ?? 'student'}'
                                  : 'Allot ${selectedStudentIds.length} student(s) to a trainer',
                              style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Trainer Dropdown
                  const Text('Select Trainer / Faculty *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedTrainerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: availableTrainers.map((t) {
                      return DropdownMenuItem<String>(
                        value: t['id'],
                        child: Text(
                          '${t['full_name']} (${t['years']})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedTrainerId = val;
                          final match = availableTrainers.firstWhere((t) => t['id'] == val, orElse: () => availableTrainers.first);
                          courseController.text = match['course_name'] ?? 'Python Full Stack & AI';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Policy Alert / Specialization Notice
                  if (isSushma)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Policy Reminder: Sushma Elisala teaches Python and is designated for 2nd Year & 4th Year students.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Designation: ${activeTrainer['full_name']} • Scope: ${activeTrainer['years']}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Course / Track Name
                  const Text('Course Track / Subject Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: courseController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Python Full Stack & AI',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Student Selection List (if multiple)
                  if (singleStudent == null && candidateStudents != null && candidateStudents.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Students (${selectedStudentIds.length} / ${candidateStudents.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              if (selectedStudentIds.length == candidateStudents.length) {
                                selectedStudentIds.clear();
                              } else {
                                selectedStudentIds.addAll(
                                  candidateStudents.map((s) => (s['id'] ?? s['student_id']).toString()),
                                );
                              }
                            });
                          },
                          child: Text(
                            selectedStudentIds.length == candidateStudents.length ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidateStudents.length,
                        itemBuilder: (c, idx) {
                          final st = candidateStudents[idx];
                          final sid = (st['id'] ?? st['student_id'] ?? '').toString();
                          final sname = st['full_name'] ?? 'Student';
                          final roll = st['roll_number'] ?? '';
                          final year = st['year'] ?? '';
                          final isChecked = selectedStudentIds.contains(sid);

                          return CheckboxListTile(
                            value: isChecked,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            title: Text('$sname ($roll)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text('$year • ${st['branch'] ?? 'Branch'}', style: const TextStyle(fontSize: 11)),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedStudentIds.add(sid);
                                } else {
                                  selectedStudentIds.remove(sid);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: (isSubmitting || selectedStudentIds.isEmpty)
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final res = await ApiService.allocateTrainerToStudents(
                                      studentIds: selectedStudentIds.toList(),
                                      trainerId: selectedTrainerId,
                                      trainerName: activeTrainer['full_name'],
                                      trainerEmail: activeTrainer['email'],
                                      courseName: courseController.text.trim(),
                                    );
                                    if (mounted) {
                                      Navigator.pop(modalCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? 'Successfully allotted student(s) to ${activeTrainer['full_name']}!'),
                                          backgroundColor: const Color(0xFF16A34A),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      _refreshStudentsFuture();
                                      _loadDashboardData();
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Allocation failed: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            isSubmitting ? 'Allotting...' : 'Confirm Allocation (${selectedStudentIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CognitoColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddStudentModal() {
    final nameController = TextEditingController();
    final rollController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    final passwordController = TextEditingController(text: 'Student@123');
    String selectedBranch = 'CSE';
    String selectedYear = '3';
    String selectedSection = 'A';
    String? studentCollegeId = _selectedCollegeId ?? (_registeredColleges.isNotEmpty ? _registeredColleges.first['id']?.toString() : null);
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
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: CognitoColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Direct Student Creation',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Instantly onboard an active student without OTP email verification.',
                  style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 18),

                const Text('Campus / College', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: studentCollegeId,
                  decoration: const InputDecoration(hintText: 'Select College'),
                  items: _registeredColleges.map((c) => DropdownMenuItem<String?>(
                    value: c['id'].toString(),
                    child: Text(c['short_name'] ?? c['college_name']),
                  )).toList(),
                  onChanged: (val) => setModalState(() => studentCollegeId = val),
                ),
                const SizedBox(height: 14),

                const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Adarsh Varma'),
                ),
                const SizedBox(height: 14),

                const Text('Roll Number / Student ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: rollController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'e.g. 22KITS0501'),
                ),
                const SizedBox(height: 14),

                const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'e.g. student@kitsdivili.ac.in'),
                ),
                const SizedBox(height: 14),

                const Text('Mobile Number (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'e.g. +91 98765 43210'),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedBranch,
                            items: const [
                              DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                              DropdownMenuItem(value: 'AI&DS', child: Text('AI&DS')),
                              DropdownMenuItem(value: 'ECE', child: Text('ECE')),
                              DropdownMenuItem(value: 'EEE', child: Text('EEE')),
                              DropdownMenuItem(value: 'MECH', child: Text('MECH')),
                              DropdownMenuItem(value: 'CIVIL', child: Text('CIVIL')),
                              DropdownMenuItem(value: 'IT', child: Text('IT')),
                            ],
                            onChanged: (val) => setModalState(() => selectedBranch = val ?? 'CSE'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedYear,
                            items: const [
                              DropdownMenuItem(value: '1', child: Text('1st')),
                              DropdownMenuItem(value: '2', child: Text('2nd')),
                              DropdownMenuItem(value: '3', child: Text('3rd')),
                              DropdownMenuItem(value: '4', child: Text('4th')),
                            ],
                            onChanged: (val) => setModalState(() => selectedYear = val ?? '3'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedSection,
                            items: const [
                              DropdownMenuItem(value: 'A', child: Text('Sec A')),
                              DropdownMenuItem(value: 'B', child: Text('Sec B')),
                              DropdownMenuItem(value: 'C', child: Text('Sec C')),
                              DropdownMenuItem(value: 'D', child: Text('Sec D')),
                            ],
                            onChanged: (val) => setModalState(() => selectedSection = val ?? 'A'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Initial Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: 'Default: Student@123'),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CognitoColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final roll = rollController.text.trim().toUpperCase();
                            final email = emailController.text.trim().toLowerCase();
                            final pwd = passwordController.text.trim();

                            if (name.isEmpty || roll.isEmpty || email.isEmpty || studentCollegeId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill in Name, Roll Number, Email, and College.'), backgroundColor: CognitoColors.danger),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.createStudentDirectly({
                                'fullName': name,
                                'rollNumber': roll,
                                'email': email,
                                'mobile': mobileController.text.trim().isNotEmpty ? mobileController.text.trim() : null,
                                'collegeId': studentCollegeId,
                                'branch': selectedBranch,
                                'year': selectedYear,
                                'section': selectedSection,
                                'password': pwd.isNotEmpty ? pwd : 'Student@123',
                              });
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Student "$name ($roll)" created successfully without OTP!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            } catch (err) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${err.toString().replaceAll("Exception: ", "")}'), backgroundColor: CognitoColors.danger),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('CREATE STUDENT (ACTIVE)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPostNoticeModal() {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    final isExecutive = role == 'SUPER_ADMIN' || role == 'PROGRAM_MANAGER';

    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedPriority = 'MEDIUM';
    String selectedTargetRole = 'ALL';
    String? selectedCollege = isExecutive
        ? _selectedCollegeId
        : (widget.userProfile['college_id']?.toString() ??
            (widget.userProfile['college'] != null ? widget.userProfile['college']['id']?.toString() : null));
    bool isPosting = false;
    String? modalError;

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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Post Tech Hub Notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                          Text('Broadcast instantly to mobile app & sync with database', style: TextStyle(fontSize: 11, color: CognitoColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (modalError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(modalError!, style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),

                // Target Campus
                if (isExecutive) ...[
                  const Text('Target Campus *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: CognitoColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedCollege,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Registered Campuses (Adarsh & KITS Divili)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          ..._registeredColleges.map((c) => DropdownMenuItem<String?>(
                            value: c['id'].toString(),
                            child: Text('${c['short_name'] ?? c['college_name']} (${c['roll_code'] ?? 'HUB'})', style: const TextStyle(fontSize: 13)),
                          )),
                        ],
                        onChanged: (val) => setModalState(() => selectedCollege = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school, size: 18, color: CognitoColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assigned Campus: ${widget.userProfile['college']?['short_name'] ?? 'Your Campus'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: CognitoColors.darkBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Row for Target Role and Priority
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target Audience *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedTargetRole,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All (Everyone)', style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'STUDENT', child: Text('Students Only', style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'TRAINER', child: Text('Trainers Only', style: TextStyle(fontSize: 12.5))),
                            ],
                            onChanged: (val) => setModalState(() => selectedTargetRole = val ?? 'ALL'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Priority Level *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: selectedPriority,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                            items: const [
                              DropdownMenuItem(value: 'LOW', child: Text('Low', style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'MEDIUM', child: Text('Normal', style: TextStyle(fontSize: 12.5))),
                              DropdownMenuItem(value: 'HIGH', child: Text('High', style: TextStyle(fontSize: 12.5, color: Color(0xFFD97706), fontWeight: FontWeight.bold))),
                              DropdownMenuItem(value: 'URGENT', child: Text('Urgent', style: TextStyle(fontSize: 12.5, color: Colors.red, fontWeight: FontWeight.bold))),
                            ],
                            onChanged: (val) => setModalState(() => selectedPriority = val ?? 'MEDIUM'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Notice Headline / Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'e.g. Schedule Update & Guest Lecture Announcement'),
                ),
                const SizedBox(height: 14),

                const Text('Notice Message *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Enter notice message details...'),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: isPosting ? null : () async {
                    final title = titleController.text.trim();
                    final message = messageController.text.trim();
                    if (title.isEmpty || message.isEmpty) {
                      setModalState(() => modalError = 'Please provide both notice title and message body.');
                      return;
                    }

                    setModalState(() {
                      isPosting = true;
                      modalError = null;
                    });

                    try {
                      await ApiService.createAnnouncement(
                        title: title,
                        message: message,
                        priority: selectedPriority,
                        targetRole: selectedTargetRole,
                        collegeId: selectedCollege,
                      );
                      if (mounted) {
                        Navigator.pop(modalCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notice published and synced with Supabase successfully!'),
                            backgroundColor: Color(0xFF16A34A),
                          ),
                        );
                        _loadDashboardData();
                      }
                    } catch (e) {
                      setModalState(() {
                        isPosting = false;
                        modalError = e.toString().replaceAll('Exception: ', '');
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isPosting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('PUBLISH NOTICE & SYNC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNotice(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice?'),
        content: const Text('Are you sure you want to remove this notice? It will be removed from both the database and cloud sync.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteAnnouncement(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notice deleted successfully.'), backgroundColor: Colors.red),
          );
          _loadDashboardData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting notice: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _handleLogout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    final isSuperAdmin = role == 'SUPER_ADMIN';
    final isProgramManager = role == 'PROGRAM_MANAGER';
    final isCollegeAdmin = role == 'COLLEGE_ADMIN';
    final isTpo = role == 'TPO';
    final isCollegeStaff = isCollegeAdmin || isTpo;

    String portalTitle = 'Super Admin Executive Portal';
    if (isProgramManager) {
      portalTitle = 'Program Manager Portal';
    } else if (isCollegeAdmin) {
      portalTitle = 'College Admin Portal';
    } else if (isTpo) {
      portalTitle = 'Placement Officer (TPO) Portal';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CognitoColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/images/emblem.png', errorBuilder: (_, __, ___) => const Icon(Icons.school, color: CognitoColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cognito Tech Hub',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: CognitoColors.darkBlue),
                  ),
                  Text(
                    portalTitle,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CognitoColors.primary),
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
            tooltip: 'Refresh Dashboard',
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CognitoColors.primary))
          : Stack(
              fit: StackFit.expand,
              children: [
                // Watermark Background for Adarsh or KITS Divili
                if (_selectedCollegeId != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: 0.05,
                          child: Builder(builder: (_) {
                            final col = _registeredColleges.firstWhere(
                              (c) => c['id'].toString() == _selectedCollegeId.toString(),
                              orElse: () => <String, dynamic>{},
                            );
                            final isAdarsh = col['college_code'] == 'ADARSH' ||
                                (col['short_name'] ?? '').toString().toLowerCase().contains('adarsh');
                            return Image.asset(
                              isAdarsh ? 'assets/images/adharsh_logo.png' : 'assets/images/kits_logo.png',
                              width: 320,
                              height: 320,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),

                RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Campus Selection / Locked Badge (Clean, No Cloud Status Bar)
                        if (!isCollegeStaff) ...[
                          const Text(
                            'SELECT ACTIVE CAMPUS TECH HUB',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CognitoColors.textSecondary, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: CognitoColors.border),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedCollegeId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: CognitoColors.primary),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Row(
                                      children: [
                                        Icon(Icons.hub_rounded, size: 20, color: CognitoColors.primary),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text('All Registered Hubs (Adarsh & KITS Divili)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._registeredColleges.map((col) {
                                    final isAdarsh = col['college_code'] == 'ADARSH' ||
                                        (col['short_name'] ?? '').toString().toLowerCase().contains('adarsh');
                                    return DropdownMenuItem<String?>(
                                      value: col['id'].toString(),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            margin: const EdgeInsets.only(right: 10),
                                            child: Image.asset(
                                              isAdarsh ? 'assets/images/adharsh_logo.png' : 'assets/images/kits_logo.png',
                                              errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_rounded, size: 18, color: CognitoColors.primary),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${col['short_name'] ?? col['college_name']} (${col['roll_code'] ?? 'HUB'})',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) => _handleCollegeSelect(val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ] else if (_currentTab != 0) ...[
                          // Locked Institutional Campus Badge for College Admin / TPO (shown on Tabs 1, 2, 3, 4)
                          Builder(builder: (_) {
                            final col = _currentCollegeInfo;
                            final shortName = col['short_name'] ?? col['shortName'] ?? col['college_name'] ?? 'College Campus';
                            final isAdarsh = col['college_code'] == 'ADARSH' ||
                                (col['code'] == 'ADARSH') ||
                                shortName.toString().toLowerCase().contains('adarsh');
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: CognitoColors.primary.withOpacity(0.2)),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: CognitoColors.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Image.asset(
                                      isAdarsh ? 'assets/images/adharsh_logo.png' : 'assets/images/kits_logo.png',
                                      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_rounded, size: 20, color: CognitoColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shortName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CognitoColors.textDark),
                                        ),
                                        const SizedBox(height: 2),
                                        const Row(
                                          children: [
                                            Icon(Icons.lock_outline_rounded, size: 12, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text(
                                              'Secured Campus Partner Access Only',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 18),
                        ],

                        // Live KPI Metrics Grid
                        _buildMetricsGrid(),
                        const SizedBox(height: 24),

                        // View Content Switcher based on Role and Selected Tab
                        if (!isCollegeStaff) ...[
                          if (_currentTab == 0) ...[
                            _buildCampusesOverviewSection(),
                          ] else if (_currentTab == 1) ...[
                            _buildStudentsRosterSection(),
                          ] else if (_currentTab == 2) ...[
                            _buildCollegeStaffSection(),
                            const SizedBox(height: 24),
                            _buildProgramManagersSection(),
                            const SizedBox(height: 24),
                            _buildTrainersSection(),
                          ] else if (_currentTab == 3) ...[
                            _buildDailyAttendanceSlotsSection(),
                          ] else ...[
                            _buildReportsAndExportsSection(),
                          ],
                        ] else ...[
                          if (_currentTab == 0) ...[
                            _buildCollegeStaffHomeSection(),
                          ] else if (_currentTab == 1) ...[
                            _buildStudentsRosterSection(),
                          ] else if (_currentTab == 2) ...[
                            _buildTrainersSection(),
                          ] else if (_currentTab == 3) ...[
                            _buildDailyAttendanceSlotsSection(),
                          ] else ...[
                            _buildReportsAndExportsSection(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (idx) => setState(() => _currentTab = idx),
        selectedItemColor: CognitoColors.primary,
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        items: !isCollegeStaff
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Campuses'),
                BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Students'),
                BottomNavigationBarItem(icon: Icon(Icons.badge_rounded), label: 'Staff & Faculty'),
                BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_rounded), label: 'Daily Slots'),
                BottomNavigationBarItem(icon: Icon(Icons.file_download_rounded), label: 'Reports'),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.account_balance_rounded), label: 'My Campus'),
                BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Students'),
                BottomNavigationBarItem(icon: Icon(Icons.school_rounded), label: 'Faculty'),
                BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_rounded), label: 'Daily Slots'),
                BottomNavigationBarItem(icon: Icon(Icons.file_download_rounded), label: 'Reports'),
              ],
      ),
    );
  }

  Widget _buildCampusFilterChip({
    required String? id,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _handleCollegeSelect(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? CognitoColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? CognitoColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: CognitoColors.primary.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : CognitoColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : CognitoColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metricsObj = _overviewMetrics['metrics'] is Map<String, dynamic>
        ? _overviewMetrics['metrics'] as Map<String, dynamic>
        : _overviewMetrics;

    final totalStudents = metricsObj['totalStudents'] ?? _overviewMetrics['totalStudents'] ?? 0;
    final totalColleges = metricsObj['totalColleges'] ?? _overviewMetrics['totalColleges'] ?? (_registeredColleges.isNotEmpty ? _registeredColleges.length : 2);
    final totalBatches = metricsObj['activeBatches'] ?? metricsObj['activePrograms'] ?? _overviewMetrics['activeBatches'] ?? _overviewMetrics['activePrograms'] ?? 4;
    final totalTrainers = metricsObj['totalTrainers'] ?? _overviewMetrics['totalTrainers'] ?? _trainers.length;
    final attendancePct = metricsObj['todayAttendanceRate'] ?? metricsObj['todayAttendancePercentage'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Students Enrolled',
                value: '$totalStudents',
                subtitle: _isCollegeStaff ? 'Campus Enrolled Roster' : (_selectedCollegeId != null ? 'In selected campus' : 'Across registered hubs'),
                icon: Icons.people_rounded,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _isCollegeStaff
                  ? _buildMetricCard(
                      title: 'Active Batches',
                      value: '$totalBatches',
                      subtitle: 'Campus Specialized Batches',
                      icon: Icons.class_rounded,
                      color: const Color(0xFF7C3AED),
                    )
                  : _buildMetricCard(
                      title: 'Active Tech Hubs',
                      value: '$totalColleges',
                      subtitle: _registeredColleges.isNotEmpty
                          ? _registeredColleges.map((c) => c['short_name'] ?? c['college_name']).take(2).join(" & ")
                          : 'KITS Divili & Adarsh',
                      icon: Icons.domain_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Active Faculty/Trainers',
                value: '$totalTrainers',
                subtitle: _isCollegeStaff ? 'Assigned Campus Faculty' : 'Campus Specialized Faculty',
                icon: Icons.school_rounded,
                color: const Color(0xFF0D9488),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Today Attendance',
                value: '$attendancePct%',
                subtitle: 'Realtime session sync',
                icon: Icons.fact_check_rounded,
                color: const Color(0xFFEA580C),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: CognitoColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCollegeStaffHomeSection() {
    final col = _currentCollegeInfo;
    final collegeName = col['college_name'] ?? col['name'] ?? widget.userProfile['college_name'] ?? 'College Campus';
    final shortName = col['short_name'] ?? col['shortName'] ?? widget.userProfile['collegeName'] ?? 'Campus Tech Hub';
    final isAdarsh = col['college_code'] == 'ADARSH' ||
        (col['code'] == 'ADARSH') ||
        shortName.toString().toLowerCase().contains('adarsh');
    final brandColor = isAdarsh ? const Color(0xFFC2410C) : const Color(0xFF1E3A8A);

    final role = widget.userProfile['role'] ?? 'COLLEGE_ADMIN';
    final canManageStudents = role == 'SUPER_ADMIN' || role == 'PROGRAM_MANAGER' || role == 'COLLEGE_ADMIN';
    final canPostNotices = canManageStudents || role == 'TPO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Institutional Secured Banner Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                brandColor,
                brandColor.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: brandColor.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        isAdarsh ? 'assets/images/adharsh_logo.png' : 'assets/images/kits_logo.png',
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.account_balance_rounded,
                          size: 32,
                          color: brandColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.security_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'AUTONOMOUS PARTNER HUB • ${role.toString().replaceAll('_', ' ')}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shortName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            collegeName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Colors.lightGreenAccent),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Strict Confidential Portal: Access restricted exclusively to your campus roster and faculty.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. Institutional Quick Action Buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (canPostNotices) ...[
                ElevatedButton.icon(
                  onPressed: _showPostNoticeModal,
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: const Text('+ Post Campus Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (canManageStudents) ...[
                ElevatedButton.icon(
                  onPressed: _showAddStudentModal,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('+ Add Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CognitoColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentTab = 3),
                icon: const Icon(Icons.qr_code_rounded, size: 16),
                label: const Text('+ Generate Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _downloadReportCsv('students', 'student_nominal_register'),
                icon: const Icon(Icons.file_download_rounded, size: 16),
                label: const Text('Export Nominal Roll', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CognitoColors.textDark,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Departmental Distribution Quick Filter Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Campus Department Roster',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _studentSelectedBranch = 'all';
                  _currentTab = 1;
                  _refreshStudentsFuture();
                });
              },
              child: const Text(
                'View All Students →',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBranchCard('CSE', 'Computer Science', Icons.computer_rounded, const Color(0xFF2563EB)),
            _buildBranchCard('ECE', 'Electronics & Comm.', Icons.memory_rounded, const Color(0xFF7C3AED)),
            _buildBranchCard('MECH', 'Mechanical Engg.', Icons.precision_manufacturing_rounded, const Color(0xFFD97706)),
            _buildBranchCard('CIVIL', 'Civil Engineering', Icons.architecture_rounded, const Color(0xFF059669)),
            _buildBranchCard('AIDS', 'AI & Data Science', Icons.smart_toy_rounded, const Color(0xFFDC2626)),
            _buildBranchCard('IT', 'Information Tech', Icons.cloud_done_rounded, const Color(0xFF0284C7)),
          ],
        ),
        const SizedBox(height: 24),

        // 4. Today's Attendance Slots Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Active Attendance Slots",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentTab = 3),
              child: const Text(
                'Manage Slots →',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_todaySlots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey.shade500, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active attendance sessions for today yet. Tap "+ Generate Slot" to launch a live QR code slot for students.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else
          ..._todaySlots.take(3).map((slot) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0D9488), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot['slot_name'] ?? 'Training Session Slot',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: CognitoColors.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Batch: ${slot['batch_name'] ?? 'General'} • Code: ${slot['slot_code'] ?? slot['token'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${slot['attendee_count'] ?? 0} Checked-In',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 20),

        // 5. Recent Campus Notices
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Campus Notices',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            if (canPostNotices)
              GestureDetector(
                onTap: _showPostNoticeModal,
                child: const Text(
                  '+ Post Notice',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_notices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_outlined, color: Colors.grey.shade500, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No campus notices posted yet. Tap "+ Post Notice" to publish notices directly to your students.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else
          ..._notices.take(3).map((notice) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (notice['priority'] == 'URGENT' ? Colors.red : Colors.blue).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notice['priority'] ?? 'NOTICE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: notice['priority'] == 'URGENT' ? Colors.red : Colors.blue,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          notice['created_at'] != null
                              ? notice['created_at'].toString().split('T')[0]
                              : 'Today',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notice['title'] ?? 'Campus Notice',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: CognitoColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notice['message'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildBranchCard(String branchCode, String branchTitle, IconData icon, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _studentSelectedBranch = branchCode;
          _currentTab = 1;
          _refreshStudentsFuture();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  branchCode,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color),
                ),
                Text(
                  'Filter Roster',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampusesOverviewSection() {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    final canManageStudents = role == 'SUPER_ADMIN' || role == 'PROGRAM_MANAGER' || role == 'COLLEGE_ADMIN';
    final canPostNotices = canManageStudents || role == 'TPO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canPostNotices) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _showPostNoticeModal,
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: const Text('+ Post Campus Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
                if (canManageStudents) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddStudentModal,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Add Student (No OTP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CognitoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
                if (role == 'SUPER_ADMIN') ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showAddProgramManagerModal,
                    icon: const Icon(Icons.badge_rounded, size: 16),
                    label: const Text('+ Add Program Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Registered Partner Campuses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CognitoColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_registeredColleges.length} Active Tech Hubs',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._registeredColleges.map((col) {
          final isSelected = _selectedCollegeId == col['id'];
          final isKits = col['college_code'] == 'KITS_DIVILI';
          final brandColor = isKits ? const Color(0xFF1E3A8A) : const Color(0xFFC2410C);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? brandColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _handleCollegeSelect(col['id']),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: brandColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.school_rounded, color: brandColor, size: 26),
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
                                        col['short_name'] ?? col['college_name'],
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CognitoColors.textDark),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: const Text(
                                        'ACTIVE HUB',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  col['college_name'],
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildHubDetailColumn('Assigned Faculty', '${col['trainer_count'] ?? 0} Trainers'),
                            Container(width: 1, height: 24, color: Colors.grey.shade300),
                            _buildHubDetailColumn('Active Tracks', '${col['program_count'] ?? 1} Track'),
                            Container(width: 1, height: 24, color: Colors.grey.shade300),
                            _buildHubDetailColumn('Enrolled Students', '${col['student_count'] ?? 0} Students'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isSelected ? 'Viewing Live Campus Data' : 'Tap to Focus Campus Data',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? brandColor : CognitoColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                            size: 14,
                            color: isSelected ? brandColor : CognitoColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        _buildNoticesSection(),
      ],
    );
  }

  Widget _buildNoticesSection() {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    final isExecutive = role == 'SUPER_ADMIN' || role == 'PROGRAM_MANAGER';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.campaign_rounded, color: Color(0xFF0284C7), size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Campus Notices & Announcements',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showPostNoticeModal,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Post Notice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_notices.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
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
                    'No campus notices posted yet. Tap "Post Notice" to broadcast updates to students, trainers, or staff.',
                    style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          ..._notices.map((notice) {
            final priority = (notice['priority'] ?? 'MEDIUM').toString().toUpperCase();
            final isUrgent = priority == 'URGENT';
            final isHigh = priority == 'HIGH';
            final badgeColor = isUrgent
                ? const Color(0xFFEF4444)
                : isHigh
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF0284C7);

            final collegeName = notice['college_name'] ?? 'All Registered Campuses';
            final authorName = notice['author_name'] ?? 'Office';
            final authorRole = notice['author_role'] ?? 'ADMIN';
            final targetRole = notice['target_role'] ?? 'ALL';
            final canDelete = isExecutive ||
                notice['created_by'] == widget.userProfile['id'] ||
                notice['college_id'] == widget.userProfile['college_id'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
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
                          collegeName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Target: $targetRole',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.indigo.shade700),
                        ),
                      ),
                      const Spacer(),
                      if (canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Delete Notice',
                          onPressed: () => _deleteNotice(notice['id'].toString()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    notice['title'] ?? 'Notice',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: CognitoColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice['message'] ?? '',
                    style: const TextStyle(fontSize: 12.5, color: CognitoColors.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '$authorName ($authorRole)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildHubDetailColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: CognitoColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
      ],
    );
  }

  Widget _buildProgramManagersSection() {
    final isSuperAdmin = (widget.userProfile['role'] ?? '') == 'SUPER_ADMIN';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Program Managers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
            ),
            if (isSuperAdmin)
              ElevatedButton.icon(
                onPressed: _showAddProgramManagerModal,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Manager', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CognitoColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_programManagers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text(
                'No Program Managers added yet. Tap "+ Add Manager" above.',
                style: TextStyle(color: CognitoColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ..._programManagers.map((pm) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: CognitoColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      (pm['full_name'] ?? 'P')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: CognitoColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pm['full_name'] ?? 'Program Manager',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pm['email'] ?? '',
                          style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                pm['assigned_college_short_name'] ?? 'HQ (All Campuses)',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              pm['mobile'] ?? '',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSuperAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: CognitoColors.primary, size: 20),
                      tooltip: 'Edit Details',
                      onPressed: () => _showEditProgramManagerModal(pm),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      tooltip: 'Remove',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Program Manager?'),
                            content: Text('Are you sure you want to remove ${pm['full_name']}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await ApiService.deleteProgramManager(pm['id']);
                            _loadDashboardData();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTrainersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Trainers & Specialized Faculty',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.playlist_add_rounded, color: CognitoColors.primary, size: 22),
                  tooltip: 'Add Course Track',
                  onPressed: _showAddCourseModal,
                ),
                ElevatedButton.icon(
                  onPressed: _showAddTrainerModal,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Trainer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CognitoColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _selectedCollegeId != null ? 'Showing specialized trainers assigned to this campus' : 'Showing all trainers across registered tech hubs',
          style: const TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_trainers.isEmpty)
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
                  Icon(Icons.school_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text(
                    'No trainers added for this selection yet.',
                    style: TextStyle(color: CognitoColors.textDark, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "+ Add Trainer" above to onboard specialized faculty.',
                    style: TextStyle(color: CognitoColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ..._trainers.map((trainer) {
            final assignments = (trainer['assignments'] as List?) ?? [];
            final firstAssn = assignments.isNotEmpty ? assignments[0] : null;
            final courseName = firstAssn != null ? (firstAssn['course_name'] ?? 'General Track') : 'Faculty';
            final years = firstAssn != null && firstAssn['target_years'] != null ? List<String>.from(firstAssn['target_years']) : <String>[];
            final branches = firstAssn != null && firstAssn['target_branches'] != null ? List<String>.from(firstAssn['target_branches']) : <String>[];
            final collegeName = trainer['college_short_name'] ?? trainer['college_name'] ?? 'Partner Campus';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          (trainer['full_name'] ?? 'T')[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: CognitoColors.primary, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trainer['full_name'] ?? 'Trainer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trainer['email'] ?? '',
                              style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: CognitoColors.primary, size: 18),
                        tooltip: 'Edit Trainer',
                        onPressed: () => _showEditTrainerModal(trainer),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                        tooltip: 'Delete Trainer',
                        onPressed: () => _confirmDeleteTrainer(trainer['id'], trainer['full_name'] ?? 'Trainer'),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CognitoColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_rounded, size: 13, color: CognitoColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              courseName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.domain_rounded, size: 13, color: CognitoColors.textDark),
                            const SizedBox(width: 4),
                            Text(
                              collegeName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.textDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Year Access: ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.textSecondary),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            ...years.map((y) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Text(
                                    '✓ $y',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                )),
                            if (years.length < 4) ...[
                              Builder(builder: (_) {
                                final allYears = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
                                final restricted = allYears.where((y) => !years.contains(y)).toList();
                                if (restricted.isEmpty) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Text(
                                    '🚫 Restricted: ${restricted.join(", ")}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Branches: ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CognitoColors.textSecondary),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            ...branches.map((b) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    b,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAllocateTrainerModal(preselectedTrainerId: trainer['id']?.toString()),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                      label: Text('Allot Students to ${trainer['full_name'] ?? 'Trainer'}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showAddCourseModal() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descController = TextEditingController();
    final catController = TextEditingController(text: 'Technology');
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
                const Row(
                  children: [
                    Icon(Icons.auto_stories_rounded, color: CognitoColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Add New Course Track',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add a specialized curriculum track (e.g., Auto CAD, AWS & AI Tools, etc.)',
                  style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text('Course Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Flutter & Mobile Systems'),
                ),
                const SizedBox(height: 14),
                const Text('Course Code *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(hintText: 'e.g. FLUTTER-APP'),
                ),
                const SizedBox(height: 14),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(hintText: 'Brief syllabus or focus areas'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final code = codeController.text.trim();
                            if (name.isEmpty || code.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Course Name and Code are required.')),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.createCourse(
                                name: name,
                                code: code,
                                description: descController.text.trim(),
                                category: catController.text.trim(),
                              );
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Course track "$name" created successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
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
                        : const Text('CREATE COURSE TRACK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTrainerModal() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    final passwordController = TextEditingController(text: 'Trainer@123');
    
    String? assignedCollegeId = _selectedCollegeId ?? (_registeredColleges.isNotEmpty ? _registeredColleges[0]['id'].toString() : null);
    
    String? selectedCourseName = _courses.isNotEmpty ? _courses[0]['name'].toString() : 'Java Full Stack';
    String? selectedCourseId = _courses.isNotEmpty ? _courses[0]['id'].toString() : null;

    final availableYears = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    List<String> selectedYears = ['3rd Year'];

    final availableBranches = ['CSE', 'AI&DS', 'AIML', 'CSE(DS)', 'EEE', 'ECE', 'Agri', 'Mechanical', 'Civil', 'Others'];
    List<String> selectedBranches = ['CSE'];

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
                const Row(
                  children: [
                    Icon(Icons.person_add_rounded, color: CognitoColors.primary, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Add Trainer / Faculty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Assign specialized trainer to a college tech hub with assigned track and batches.',
                  style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Ramesh Kumar'),
                ),
                const SizedBox(height: 14),
                const Text('Email Address *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'e.g. trainer.ramesh@cognito.edu'),
                ),
                const SizedBox(height: 14),
                const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '10-digit phone number'),
                ),
                const SizedBox(height: 14),
                const Text('Initial Password *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: 'Trainer password'),
                ),
                const SizedBox(height: 14),
                const Text('Campus Tech Hub Assignment *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: assignedCollegeId,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  items: _registeredColleges.map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text('${c['short_name'] ?? c['college_name']} (${c['roll_code'] ?? 'HUB'})'),
                  )).toList(),
                  onChanged: (val) => setModalState(() => assignedCollegeId = val),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Specialized Track / Course *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddCourseModal();
                      },
                      child: const Text('+ New Course', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedCourseName,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  items: [
                    ..._courses.map((cr) => DropdownMenuItem<String>(
                          value: cr['name'].toString(),
                          child: Text(cr['name'].toString()),
                        )),
                    if (!_courses.any((c) => c['name'] == 'Java Full Stack'))
                      const DropdownMenuItem(value: 'Java Full Stack', child: Text('Java Full Stack')),
                    if (!_courses.any((c) => c['name'] == 'Python Full Stack'))
                      const DropdownMenuItem(value: 'Python Full Stack', child: Text('Python Full Stack')),
                    if (!_courses.any((c) => c['name'] == 'AWS and AI Tools'))
                      const DropdownMenuItem(value: 'AWS and AI Tools', child: Text('AWS and AI Tools')),
                    if (!_courses.any((c) => c['name'] == 'Auto CAD'))
                      const DropdownMenuItem(value: 'Auto CAD', child: Text('Auto CAD')),
                  ],
                  onChanged: (val) {
                    setModalState(() {
                      selectedCourseName = val;
                      final match = _courses.firstWhere(
                        (c) => c['name'].toString() == val,
                        orElse: () => null,
                      );
                      selectedCourseId = match != null ? match['id']?.toString() : null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                const Text('Target Academic Years *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: availableYears.map((yr) {
                    final isSel = selectedYears.contains(yr);
                    return FilterChip(
                      label: Text(yr),
                      selected: isSel,
                      selectedColor: CognitoColors.primary.withOpacity(0.15),
                      checkmarkColor: CognitoColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? CognitoColors.primary : CognitoColors.textDark,
                      ),
                      onSelected: (checked) {
                        setModalState(() {
                          if (checked) {
                            selectedYears.add(yr);
                          } else if (selectedYears.length > 1) {
                            selectedYears.remove(yr);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Target Engineering Branches *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: availableBranches.map((br) {
                    final isSel = selectedBranches.contains(br);
                    return FilterChip(
                      label: Text(br),
                      selected: isSel,
                      selectedColor: CognitoColors.primary.withOpacity(0.15),
                      checkmarkColor: CognitoColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? CognitoColors.primary : CognitoColors.textDark,
                      ),
                      onSelected: (checked) {
                        setModalState(() {
                          if (checked) {
                            selectedBranches.add(br);
                          } else if (selectedBranches.length > 1) {
                            selectedBranches.remove(br);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final email = emailController.text.trim();
                            final pwd = passwordController.text.trim();
                            if (name.isEmpty || email.isEmpty || pwd.isEmpty || assignedCollegeId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill all required fields and select a campus.')),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.createTrainer({
                                'fullName': name,
                                'email': email,
                                'mobile': mobileController.text.trim(),
                                'password': pwd,
                                'collegeId': assignedCollegeId!,
                                'courseName': selectedCourseName,
                                'courseId': selectedCourseId,
                                'targetYears': selectedYears,
                                'targetBranches': selectedBranches,
                              });
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Trainer "$name" onboarded and assigned successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
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
                        : const Text('CREATE & ASSIGN TRAINER', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTrainerModal(Map<String, dynamic> trainer) {
    final nameController = TextEditingController(text: trainer['full_name'] ?? '');
    final emailController = TextEditingController(text: trainer['email'] ?? '');
    final mobileController = TextEditingController(text: trainer['mobile'] ?? '');
    final passwordController = TextEditingController();

    String? assignedCollegeId = trainer['college_id']?.toString() ??
        (trainer['assignments'] != null && (trainer['assignments'] as List).isNotEmpty
            ? trainer['assignments'][0]['college_id']?.toString()
            : null);

    final firstAssignment = (trainer['assignments'] != null && (trainer['assignments'] as List).isNotEmpty)
        ? trainer['assignments'][0]
        : null;

    String? selectedCourseName = firstAssignment?['course_name'] ?? 'Java Full Stack';
    String? selectedCourseId = firstAssignment?['course_id']?.toString();

    final availableYears = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    List<String> selectedYears = firstAssignment?['target_years'] != null
        ? List<String>.from(firstAssignment['target_years'])
        : ['3rd Year'];

    final availableBranches = ['CSE', 'AI&DS', 'AIML', 'CSE(DS)', 'EEE', 'ECE', 'Agri', 'Mechanical', 'Civil', 'Others'];
    List<String> selectedBranches = firstAssignment?['target_branches'] != null
        ? List<String>.from(firstAssignment['target_branches'])
        : ['CSE'];

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
                    const Icon(Icons.edit_rounded, color: CognitoColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Edit Trainer: ${trainer['full_name'] ?? ''}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Update trainer profile, campus, course track, and target batches.',
                  style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 18),
                const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'Full name'),
                ),
                const SizedBox(height: 14),
                const Text('Email Address *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email address'),
                ),
                const SizedBox(height: 14),
                const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Mobile number'),
                ),
                const SizedBox(height: 14),
                const Text('Change Password (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: 'Leave empty to keep existing password'),
                ),
                const SizedBox(height: 14),
                const Text('Campus Tech Hub Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  value: assignedCollegeId,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  items: _registeredColleges.map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text('${c['short_name'] ?? c['college_name']} (${c['roll_code'] ?? 'HUB'})'),
                  )).toList(),
                  onChanged: (val) => setModalState(() => assignedCollegeId = val),
                ),
                const SizedBox(height: 14),
                const Text('Specialized Track / Course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedCourseName,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  items: [
                    ..._courses.map((cr) => DropdownMenuItem<String>(
                          value: cr['name'].toString(),
                          child: Text(cr['name'].toString()),
                        )),
                    if (!_courses.any((c) => c['name'] == selectedCourseName) && selectedCourseName != null)
                      DropdownMenuItem(value: selectedCourseName, child: Text(selectedCourseName!)),
                  ],
                  onChanged: (val) {
                    setModalState(() {
                      selectedCourseName = val;
                      final match = _courses.firstWhere(
                        (c) => c['name'].toString() == val,
                        orElse: () => null,
                      );
                      selectedCourseId = match != null ? match['id']?.toString() : null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                const Text('Target Academic Years', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: availableYears.map((yr) {
                    final isSel = selectedYears.contains(yr);
                    return FilterChip(
                      label: Text(yr),
                      selected: isSel,
                      selectedColor: CognitoColors.primary.withOpacity(0.15),
                      checkmarkColor: CognitoColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? CognitoColors.primary : CognitoColors.textDark,
                      ),
                      onSelected: (checked) {
                        setModalState(() {
                          if (checked) {
                            selectedYears.add(yr);
                          } else if (selectedYears.length > 1) {
                            selectedYears.remove(yr);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Target Engineering Branches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: availableBranches.map((br) {
                    final isSel = selectedBranches.contains(br);
                    return FilterChip(
                      label: Text(br),
                      selected: isSel,
                      selectedColor: CognitoColors.primary.withOpacity(0.15),
                      checkmarkColor: CognitoColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? CognitoColors.primary : CognitoColors.textDark,
                      ),
                      onSelected: (checked) {
                        setModalState(() {
                          if (checked) {
                            selectedBranches.add(br);
                          } else if (selectedBranches.length > 1) {
                            selectedBranches.remove(br);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final email = emailController.text.trim();
                            final pwd = passwordController.text.trim();
                            if (name.isEmpty || email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Name and Email are required.')),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              await ApiService.updateTrainer(
                                trainer['id'],
                                {
                                  'fullName': name,
                                  'email': email,
                                  'mobile': mobileController.text.trim(),
                                  if (pwd.isNotEmpty) 'password': pwd,
                                  'collegeId': assignedCollegeId,
                                  'courseName': selectedCourseName,
                                  'courseId': selectedCourseId,
                                  'targetYears': selectedYears,
                                  'targetBranches': selectedBranches,
                                },
                              );
                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Trainer "$name" updated successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
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
                        : const Text('SAVE TRAINER CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTrainer(String trainerId, String trainerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Trainer?'),
        content: Text('Are you sure you want to remove trainer "$trainerName"? They will no longer have access to mark attendance or upload materials.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteTrainer(trainerId);
        _loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trainer "$trainerName" removed successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ==========================================
  // SECTION: COLLEGE ADMINS & TPO PLACEMENT OFFICERS
  // ==========================================
  Widget _buildCollegeStaffSection() {
    final filteredStaff = _selectedCollegeId == null
        ? _collegeStaff
        : _collegeStaff.where((s) => s['college_id'].toString() == _selectedCollegeId.toString()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Authorities & Placement Officers (TPO)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Principals, College Admins & TPOs with individual college access',
                    style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddCollegeStaffDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CognitoColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (filteredStaff.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.supervisor_account_outlined, size: 40, color: Colors.grey),
                const SizedBox(height: 10),
                const Text('No College Staff Configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text(
                  'Click "+ Add Staff" above to onboard a College Admin or Placement Officer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredStaff.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final staff = filteredStaff[index];
              final role = staff['role'] ?? 'COLLEGE_ADMIN';
              final isTpo = role == 'TPO';
              final roleLabel = isTpo ? 'Placement Officer (TPO)' : 'College Admin / Dean';
              final roleColor = isTpo ? const Color(0xFFD97706) : CognitoColors.primary;
              final collegeName = staff['college_short_name'] ?? staff['college_name'] ?? 'College';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: roleColor.withOpacity(0.12),
                      child: Icon(
                        isTpo ? Icons.work_outline_rounded : Icons.school_outlined,
                        color: roleColor,
                        size: 22,
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
                                  staff['full_name'] ?? 'Staff Member',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CognitoColors.textDark),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: roleColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  roleLabel,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: roleColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.account_balance_rounded, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(collegeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(staff['email'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                              ),
                              if (staff['mobile'] != null && staff['mobile'].toString().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(staff['mobile'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showAddCollegeStaffDialog(staff: staff);
                        } else if (val == 'delete') {
                          _confirmDeleteCollegeStaff(staff['id'].toString(), staff['full_name'] ?? 'Staff');
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _showAddCollegeStaffDialog({Map<String, dynamic>? staff}) {
    final isEdit = staff != null;
    final nameController = TextEditingController(text: isEdit ? staff['full_name'] : '');
    final emailController = TextEditingController(text: isEdit ? staff['email'] : '');
    final mobileController = TextEditingController(text: isEdit ? staff['mobile'] ?? '' : '');
    final passwordController = TextEditingController();

    String selectedRole = isEdit ? (staff['role'] ?? 'COLLEGE_ADMIN') : 'COLLEGE_ADMIN';
    String? selectedColId = isEdit
        ? staff['college_id']?.toString()
        : (_selectedCollegeId ?? (_registeredColleges.isNotEmpty ? _registeredColleges.first['id'].toString() : null));

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit College Staff Account' : 'Onboard College Admin / TPO',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Role / Designation *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedRole,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: const [
                    DropdownMenuItem(value: 'COLLEGE_ADMIN', child: Text('College Admin / Principal / Dean')),
                    DropdownMenuItem(value: 'TPO', child: Text('Training & Placement Officer (TPO)')),
                  ],
                  onChanged: (val) => setModalState(() => selectedRole = val ?? selectedRole),
                ),
                const SizedBox(height: 12),

                const Text('Assigned Campus Tech Hub *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: selectedColId,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: _registeredColleges.map((c) {
                    return DropdownMenuItem<String?>(
                      value: c['id'].toString(),
                      child: Text('${c['short_name'] ?? c['college_name']} (${c['roll_code'] ?? 'HUB'})'),
                    );
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedColId = val),
                ),
                const SizedBox(height: 12),

                const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Dr. K. Prasad / Prof. R. Rao'),
                ),
                const SizedBox(height: 12),

                const Text('Official Email Address *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailController,
                  enabled: !isEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'e.g. admin@adarsh.ac.in or tpo@kits.ac.in'),
                ),
                const SizedBox(height: 12),

                const Text('Contact Mobile Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '+91 94401 23456'),
                ),
                const SizedBox(height: 12),

                Text(isEdit ? 'Reset Password (optional)' : 'Account Password *', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: isEdit ? 'Leave blank to keep existing password' : 'Enter login password (min 6 chars)',
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final email = emailController.text.trim();
                            final mobile = mobileController.text.trim();
                            final pwd = passwordController.text.trim();

                            if (name.isEmpty || (!isEdit && email.isEmpty) || (!isEdit && pwd.isEmpty) || selectedColId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill all mandatory fields.')),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            try {
                              if (isEdit) {
                                await ApiService.updateCollegeStaff(staff['id'].toString(), {
                                  'fullName': name,
                                  'mobile': mobile,
                                  'collegeId': selectedColId,
                                  if (pwd.isNotEmpty) 'password': pwd,
                                });
                              } else {
                                await ApiService.createCollegeStaff({
                                  'fullName': name,
                                  'email': email,
                                  'mobile': mobile,
                                  'password': pwd,
                                  'role': selectedRole,
                                  'collegeId': selectedColId,
                                });
                              }

                              if (!mounted) return;
                              Navigator.pop(ctx);
                              _loadDashboardData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Staff account "${name}" ${isEdit ? 'updated' : 'onboarded'} successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
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
                        : Text(isEdit ? 'SAVE STAFF CHANGES' : 'CREATE STAFF ACCOUNT', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCollegeStaff(String staffId, String staffName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete College Staff?'),
        content: Text('Are you sure you want to remove "$staffName"? They will no longer be able to log in to manage their college dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteCollegeStaff(staffId);
        _loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Staff account "$staffName" deleted successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ==========================================
  // SECTION: DAILY ATTENDANCE QR SLOTS
  // ==========================================
  Widget _buildDailyAttendanceSlotsSection() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily QR-Based Student Attendance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
        ),
        const SizedBox(height: 3),
        const Text(
          'Generate dynamic, time-bound QR codes for scheduled daily slots. Students scan to record verified presence.',
          style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // Generated Slot Active Display Card
        if (_generatedSlotData != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CognitoColors.primary, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.fiber_manual_record, size: 10, color: Color(0xFF16A34A)),
                          SizedBox(width: 6),
                          Text('ACTIVE ATTENDANCE SLOT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => setState(() => _generatedSlotData = null),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _generatedSlotData!['slotName'] ?? 'Daily Technical Session',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: CognitoColors.darkBlue),
                ),
                Text(
                  '${_generatedSlotData!['collegeName']} (${_generatedSlotData!['collegeCode']})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Large Scannable QR Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: _generatedSlotData!['token'] ?? '',
                    version: QrVersions.auto,
                    size: 210.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: CognitoColors.primary),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: CognitoColors.darkBlue),
                  ),
                ),
                const SizedBox(height: 14),

                // Token Display & Copy
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    _generatedSlotData!['token'] ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2, color: CognitoColors.primary),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Valid for ${_generatedSlotData!['validityMinutes']} minutes • Time-bound to prevent sharing',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _loadDashboardData(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh Attendee Count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Slot Generator Controls
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
                        const Text('Slot Validity Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingSlot ? null : _generateDailySlotQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                  label: _isGeneratingSlot
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('GENERATE DAILY ATTENDANCE QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        const SizedBox(height: 24),

        // Today's Slots History
        const Text(
          "Today's Scheduled Slots Roster",
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
        ),
        const SizedBox(height: 10),

        if (_todaySlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No attendance slots generated yet today. Generate one above.', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todaySlots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final slot = _todaySlots[index];
              final isValid = slot['is_currently_valid'] == true;
              final attendeeCount = slot['attendee_count'] ?? 0;
              final tokenStr = (slot['token'] ?? slot['slot_code'] ?? '').toString();

              return InkWell(
                onTap: () => _showGeneratedQrDialog(slot['slot_name'] ?? 'Session Slot', tokenStr, 30),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isValid ? CognitoColors.primary.withOpacity(0.4) : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isValid ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.qr_code_rounded, color: isValid ? const Color(0xFF16A34A) : Colors.grey, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(slot['slot_name'] ?? 'Session Slot', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(
                              'Token: $tokenStr • ${slot['college_short_name'] ?? ''}',
                              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isValid ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isValid ? 'ACTIVE' : 'EXPIRED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isValid ? const Color(0xFF16A34A) : Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('$attendeeCount Present', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: CognitoColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showGeneratedQrDialog(String slotTitle, String token, int validityMins) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      slotTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: CognitoColors.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // QR Code
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: token,
                    version: QrVersions.auto,
                    size: 210,
                    gapless: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Prominent Token Code Card
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: token));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Attendance Token "$token" copied to clipboard!'),
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
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: CognitoColors.primary, letterSpacing: 1.2),
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
                                  token,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 1.5),
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
                        'Tap to copy • Students can scan QR above or enter this code manually',
                        style: TextStyle(fontSize: 11, color: CognitoColors.textSecondary, fontWeight: FontWeight.w500, height: 1.35),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CognitoColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateDailySlotQr() async {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    final targetCollegeId = (role == 'COLLEGE_ADMIN' || role == 'TPO')
        ? (widget.userProfile['college_id']?.toString() ??
            (widget.userProfile['college'] != null ? widget.userProfile['college']['id']?.toString() : null))
        : (_selectedCollegeId ?? (_registeredColleges.isNotEmpty ? _registeredColleges.first['id'].toString() : null));

    if (targetCollegeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an active college hub to generate a slot.')),
      );
      return;
    }

    setState(() => _isGeneratingSlot = true);
    try {
      final res = await ApiService.generateAttendanceSlotQr({
        'collegeId': targetCollegeId,
        'slotName': _selectedSlotName,
        'validityMinutes': int.parse(_selectedSlotDuration),
      });

      final slotObj = res['slot'] ?? {};
      final token = (slotObj['token'] ?? slotObj['slotCode'] ?? slotObj['slot_code'] ?? '').toString();

      setState(() {
        _generatedSlotData = slotObj;
        _isGeneratingSlot = false;
      });

      _loadDashboardData();
      _showGeneratedQrDialog(_selectedSlotName, token, int.parse(_selectedSlotDuration));
    } catch (e) {
      setState(() => _isGeneratingSlot = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: CognitoColors.danger),
      );
    }
  }

  // ==========================================
  // SECTION: REPORTS & DATA EXPORTS (CSV & PDF)
  // ==========================================
  Widget _buildReportsAndExportsSection() {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    final isCollegeStaff = role == 'COLLEGE_ADMIN' || role == 'TPO';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Institutional Data Exports & Nominal Reports',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
        ),
        const SizedBox(height: 3),
        const Text(
          'Download verified student registers, attendance audit logs, and faculty rosters in standard RFC 4180 CSV or view printable summaries.',
          style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 16),

        _buildReportCard(
          title: 'Student Nominal Roll',
          description: 'Official academic register: Roll numbers, student names, branch, year, section, and contact details.',
          icon: Icons.assignment_ind_rounded,
          color: CognitoColors.primary,
          onDownloadCsv: () => _downloadReportCsv('students', 'student_nominal_roll'),
          onViewSummary: () => _showPrintableReportDialog('students', 'Student Nominal Roll Report'),
          onAddStudent: _showAddStudentModal,
        ),
        const SizedBox(height: 12),

        _buildReportCard(
          title: 'Daily Student Attendance Logs',
          description: 'Verified session attendance records with timestamps, check-in methods (QR scan), and device info.',
          icon: Icons.fact_check_rounded,
          color: const Color(0xFF16A34A),
          onDownloadCsv: () => _downloadReportCsv('attendance', 'student_attendance_logs'),
          onViewSummary: () => _showPrintableReportDialog('attendance', 'Student Daily Attendance Logs'),
        ),
        const SizedBox(height: 12),

        if (!isCollegeStaff) ...[
          _buildReportCard(
            title: 'Campus Trainers & Faculty Roster',
            description: 'Faculty directory with assigned course tracks, target academic years, and branches.',
            icon: Icons.school_rounded,
            color: const Color(0xFF7C3AED),
            onDownloadCsv: () => _downloadReportCsv('trainers', 'trainers_faculty_roster'),
            onViewSummary: () => _showPrintableReportDialog('trainers', 'Trainers & Faculty Directory'),
          ),
          const SizedBox(height: 12),

          _buildReportCard(
            title: 'College Admins & TPOs Directory',
            description: 'Institutional authorities, principals, and training & placement officers contact registers.',
            icon: Icons.supervisor_account_rounded,
            color: const Color(0xFFD97706),
            onDownloadCsv: () => _downloadReportCsv('staff', 'college_staff_directory'),
            onViewSummary: () => _showPrintableReportDialog('staff', 'College Staff & TPO Directory'),
          ),
        ],
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onDownloadCsv,
    required VoidCallback onViewSummary,
    VoidCallback? onAddStudent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CognitoColors.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDownloadCsv,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onViewSummary,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          if (onAddStudent != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddStudent,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('+ Onboard Student Directly (No OTP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CognitoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadReportCsv(String reportType, String filename) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating CSV export...')),
      );

      final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
      final effectiveColId = (role == 'COLLEGE_ADMIN' || role == 'TPO')
          ? (widget.userProfile['college_id']?.toString() ??
              (widget.userProfile['college'] != null ? widget.userProfile['college']['id']?.toString() : null))
          : _selectedCollegeId;

      final csvData = await ApiService.getReportData(reportType, collegeId: effectiveColId, format: 'csv');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${filename}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Cognito Tech Hub Report: $filename.csv');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download report: $e'), backgroundColor: CognitoColors.danger),
      );
    }
  }

  Future<void> _showPrintableReportDialog(String reportType, String title) async {
    try {
      final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
      final effectiveColId = (role == 'COLLEGE_ADMIN' || role == 'TPO')
          ? (widget.userProfile['college_id']?.toString() ??
              (widget.userProfile['college'] != null ? widget.userProfile['college']['id']?.toString() : null))
          : _selectedCollegeId;

      final data = await ApiService.getReportData(reportType, collegeId: effectiveColId, format: 'json');
      final items = (data['students'] ?? data['records'] ?? data['trainers'] ?? data['staff'] ?? []) as List<dynamic>;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${items.length} verified records found', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (reportType == 'students') ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddStudentModal();
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                      label: const Text('Add Student', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CognitoColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No records matching current filter.'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final it = items[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${idx + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it['full_name'] ?? it['student_name'] ?? it['trainer_name'] ?? it['staff_name'] ?? 'Record',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${it['roll_number'] ?? it['email'] ?? ''} • ${it['branch'] ?? it['course_name'] ?? it['staff_role'] ?? ''}',
                                        style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                if (it['attendance_status'] != null || it['enrollment_status'] != null || it['status'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (it['attendance_status'] ?? it['enrollment_status'] ?? it['status'] ?? 'ACTIVE').toString(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                if (reportType == 'students') ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Delete Student',
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _confirmDeleteStudent(it);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadReportCsv(reportType, reportType);
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('EXPORT AND SHARE CSV (RFC 4180)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load report summary: $e'), backgroundColor: CognitoColors.danger),
      );
    }
  }

  // ==========================================
  // CONFIRM DELETE STUDENT
  // ==========================================
  Future<void> _confirmDeleteStudent(dynamic s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Are you sure you want to permanently remove ${s['full_name'] ?? 'this student'} (${s['roll_number'] ?? ''})? This will delete their profile and behaviour records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final id = s['id']?.toString() ?? s['user_id']?.toString();
        if (id == null) throw Exception('Student ID not found');
        await ApiService.deleteStudent(id);
        if (!mounted) return;
        setState(() {});
        _loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student ${s['full_name'] ?? ''} deleted successfully.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete student: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: CognitoColors.danger,
          ),
        );
      }
    }
  }

  // ==========================================
  // SECTION: STUDENT NOMINAL ROSTER (SUPER ADMIN, PM, COLLEGE ADMIN, TPO)
  // ==========================================
  Widget _buildStudentsRosterSection() {
    final role = widget.userProfile['role'] ?? 'SUPER_ADMIN';
    final isCollegeStaff = role == 'COLLEGE_ADMIN' || role == 'TPO';

    final effectiveColId = isCollegeStaff
        ? (widget.userProfile['college_id']?.toString() ??
            (widget.userProfile['college'] != null ? widget.userProfile['college']['id']?.toString() : null))
        : _selectedCollegeId;

    _studentsFuture ??= ApiService.getStudents(
      collegeId: effectiveColId,
      branch: _studentSelectedBranch,
      year: _studentSelectedYear,
      search: _studentSearchQuery,
      attendanceStatus: _studentSelectedStatus,
      limit: 100,
    );

    return FutureBuilder<Map<String, dynamic>>(
      future: _studentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: CognitoColors.primary),
            ),
          );
        }

        final data = snapshot.data;
        final List<dynamic> students = (data != null && data['students'] != null)
            ? (data['students'] as List<dynamic>)
            : [];
        final int totalCount = data?['total'] ?? students.length;
        final int presentCount = data?['presentCount'] ?? 0;
        final int absentCount = data?['absentCount'] ?? 0;
        final int pendingCount = data?['pendingCount'] ?? 0;
        final int attendanceRate = data?['attendanceRate'] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Responsive Title & Action Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 460;
                final titleWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Nominal Register',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CognitoColors.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effectiveColId != null
                          ? '$totalCount Registered Students • Campus Filter Active'
                          : '$totalCount Registered Students across All Partner Campuses',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                );

                final buttonsWidget = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAllocateTrainerModal(candidateStudents: students),
                      icon: const Icon(Icons.group_add_rounded, size: 14),
                      label: const Text('Allot Trainers', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showQuickManualAttendanceDialog(),
                      icon: const Icon(Icons.how_to_reg_rounded, size: 14),
                      label: const Text('Mark Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddStudentModal,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                      label: const Text('+ Student', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CognitoColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadReportCsv('students', 'student_nominal_register'),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 10),
                      buttonsWidget,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    buttonsWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Live Attendance KPI Summary Cards
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildAttendanceKpiItem(
                      label: 'Total Registered',
                      count: totalCount.toString(),
                      color: CognitoColors.primary,
                      icon: Icons.people_alt_rounded,
                    ),
                  ),
                  Container(height: 36, width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: _buildAttendanceKpiItem(
                      label: 'Present Today',
                      count: presentCount.toString(),
                      color: const Color(0xFF16A34A),
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  Container(height: 36, width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: _buildAttendanceKpiItem(
                      label: 'Pending / Absent',
                      count: (absentCount + pendingCount).toString(),
                      color: const Color(0xFFD97706),
                      icon: Icons.access_time_rounded,
                    ),
                  ),
                  Container(height: 36, width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: _buildAttendanceKpiItem(
                      label: 'Attendance Rate',
                      count: '$attendanceRate%',
                      color: const Color(0xFF0284C7),
                      icon: Icons.pie_chart_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Campus Filter Chips (for Super Admin & Program Manager)
            if (!isCollegeStaff && _registeredColleges.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCampusFilterChip(
                      id: null,
                      label: 'All Campuses ($totalCount)',
                      icon: Icons.account_balance_rounded,
                      isSelected: _selectedCollegeId == null,
                    ),
                    const SizedBox(width: 8),
                    ..._registeredColleges.map((col) {
                      final colCount = col['student_count'] ?? (col['college_code'] == 'ADARSH' ? totalCount : 0);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCampusFilterChip(
                          id: col['id'].toString(),
                          label: '${col['short_name'] ?? col['college_name']} ($colCount)',
                          icon: Icons.school_rounded,
                          isSelected: _selectedCollegeId == col['id'].toString(),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Realtime Search Box
            TextField(
              controller: _studentSearchController,
              decoration: InputDecoration(
                hintText: 'Search by student name, roll number, email...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, color: CognitoColors.primary, size: 20),
                suffixIcon: _studentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _studentSearchController.clear();
                          setState(() {
                            _studentSearchQuery = '';
                            _refreshStudentsFuture();
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: CognitoColors.primary, width: 1.5)),
              ),
              onChanged: (val) {
                setState(() {
                  _studentSearchQuery = val;
                  _refreshStudentsFuture();
                });
              },
            ),
            const SizedBox(height: 10),

            // Filter Pills Row (Branch, Year, Attendance Status, Bulk Action)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  // Branch Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _studentSelectedBranch,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textDark),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Branches')),
                          DropdownMenuItem(value: 'CSE', child: Text('CSE')),
                          DropdownMenuItem(value: 'ECE', child: Text('ECE')),
                          DropdownMenuItem(value: 'MECH', child: Text('MECH')),
                          DropdownMenuItem(value: 'CIVIL', child: Text('CIVIL')),
                          DropdownMenuItem(value: 'AIDS', child: Text('AIDS')),
                          DropdownMenuItem(value: 'IT', child: Text('IT')),
                        ],
                        onChanged: (v) => setState(() {
                          _studentSelectedBranch = v ?? 'all';
                          _refreshStudentsFuture();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Year Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _studentSelectedYear,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textDark),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Years')),
                          DropdownMenuItem(value: '1st Year', child: Text('1st Year')),
                          DropdownMenuItem(value: '2nd Year', child: Text('2nd Year')),
                          DropdownMenuItem(value: '3rd Year', child: Text('3rd Year')),
                          DropdownMenuItem(value: '4th Year', child: Text('4th Year')),
                        ],
                        onChanged: (v) => setState(() {
                          _studentSelectedYear = v ?? 'all';
                          _refreshStudentsFuture();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Attendance Status Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _studentSelectedStatus,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textDark),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'PRESENT', child: Text('Present Today')),
                          DropdownMenuItem(value: 'PENDING', child: Text('Not Marked')),
                          DropdownMenuItem(value: 'ABSENT', child: Text('Absent Today')),
                        ],
                        onChanged: (v) => setState(() {
                          _studentSelectedStatus = v ?? 'all';
                          _refreshStudentsFuture();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bulk Action Button
                  if (students.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _handleBulkMarkAllPresent(students),
                      icon: const Icon(Icons.done_all_rounded, size: 14),
                      label: const Text('Mark All Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Student Cards List
            if (students.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'No students match the current filters.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Try resetting filters or checking another campus.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _studentSearchController.clear();
                          _studentSearchQuery = '';
                          _studentSelectedBranch = 'all';
                          _studentSelectedYear = 'all';
                          _studentSelectedStatus = 'all';
                          if (!isCollegeStaff) _selectedCollegeId = null;
                          _refreshStudentsFuture();
                        });
                      },
                      child: const Text('Reset All Filters', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: students.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final s = students[idx] as Map<String, dynamic>;
                  final studentId = s['id']?.toString() ?? s['student_id']?.toString() ?? '';
                  final studentName = s['full_name'] ?? 'Student';
                  final rollNumber = s['roll_number'] ?? '';
                  final collegeName = s['college_name'] ?? 'Tech Hub Campus';
                  final branch = s['branch'] ?? '';
                  final year = s['year'] ?? '';
                  final todayStatus = (s['today_status'] ?? 'PENDING').toString().toUpperCase();
                  final markedTime = s['today_marked_time']?.toString();
                  final consistency = s['attendance_consistency']?.toString() ?? '90';

                  final assignedTrainer = s['assignedTrainer'] ?? s['assigned_trainer'];
                  final assignedTrainerName = assignedTrainer is Map
                      ? (assignedTrainer['full_name'] ?? assignedTrainer['name'] ?? 'Faculty')
                      : (s['assigned_trainer_name'] ?? (year.toString().contains('2') ? 'Sushma Elisala' : 'Pathivada Daiva Rao'));
                  final assignedCourse = (assignedTrainer is Map
                      ? (assignedTrainer['course_name'] ?? '')
                      : (s['course_name'] ?? '')).toString();

                  final isPresent = todayStatus == 'PRESENT';

                  return GestureDetector(
                    onTap: () => _showStudentProfileModal(studentId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPresent ? const Color(0xFFBBF7D0) : Colors.grey.shade200,
                          width: isPresent ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tier 1: Avatar, Name, Status Badge, Consistency Pill
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isPresent
                                    ? const Color(0xFFDCFCE7)
                                    : CognitoColors.primary.withOpacity(0.08),
                                child: Text(
                                  studentName.isNotEmpty ? studentName.substring(0, 1).toUpperCase() : 'S',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: isPresent ? const Color(0xFF16A34A) : CognitoColors.primary,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studentName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: CognitoColors.textDark),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '$rollNumber • $branch • $year',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Consistency % pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Text(
                                  '$consistency%',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPresent ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPresent
                                      ? (markedTime != null ? 'PRESENT • $markedTime' : 'PRESENT')
                                      : 'NOT MARKED',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isPresent ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Assigned Faculty Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.school_rounded, size: 12, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Faculty: $assignedTrainerName${assignedCourse.isNotEmpty ? " • $assignedCourse" : ""}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Tier 2: College Tag and Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.account_balance_rounded, size: 13, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        collegeName,
                                        style: const TextStyle(fontSize: 11, color: CognitoColors.primary, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Allot Trainer Button
                              ElevatedButton.icon(
                                onPressed: () => _showAllocateTrainerModal(singleStudent: s),
                                icon: const Icon(Icons.assignment_ind_rounded, size: 12),
                                label: const Text('Allot', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F766E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  minimumSize: const Size(60, 30),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Quick Attendance Button
                              ElevatedButton(
                                onPressed: () => _handleAdminMarkStudentAttendance(
                                  s,
                                  targetStatus: isPresent ? 'ABSENT' : 'PRESENT',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPresent ? Colors.grey.shade100 : const Color(0xFF16A34A),
                                  foregroundColor: isPresent ? Colors.grey.shade700 : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  minimumSize: const Size(82, 30),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isPresent ? Colors.grey.shade300 : Colors.transparent,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  isPresent ? 'Mark Absent' : 'Mark Present',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Delete button
                              InkWell(
                                onTap: () => _confirmDeleteStudent(s),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildAttendanceKpiItem({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _handleAdminMarkStudentAttendance(Map<String, dynamic> s, {String targetStatus = 'PRESENT'}) async {
    final studentId = (s['student_id'] ?? s['id'])?.toString();
    final roll = s['roll_number']?.toString() ?? '';
    final studentName = s['full_name'] ?? 'Student';

    try {
      final res = await ApiService.markManualAttendance(
        studentId: studentId ?? '',
        rollNumber: roll,
        status: targetStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Marked $studentName as $targetStatus!'),
          backgroundColor: targetStatus == 'PRESENT' ? const Color(0xFF16A34A) : CognitoColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _refreshStudentsFuture();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update attendance: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: CognitoColors.danger,
        ),
      );
    }
  }

  Future<void> _handleBulkMarkAllPresent(List<dynamic> students) async {
    final ids = students.map((s) => (s['id'] ?? s['student_id']).toString()).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.done_all_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Bulk Attendance Confirmation'),
          ],
        ),
        content: Text('Are you sure you want to mark all ${ids.length} visible students as PRESENT for today?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Mark All Present', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiService.markManualAttendanceBulk(studentIds: ids, status: 'PRESENT');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Marked ${ids.length} students PRESENT!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      setState(() {
        _refreshStudentsFuture();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk attendance failed: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: CognitoColors.danger,
        ),
      );
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
                return const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Student profile details unavailable.')));
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

                  // Header with avatar & roll
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

                  // Lifetime Attendance Metrics Grid
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
                        _buildProfileMetric('Overall Attendance', '$attPercent%', const Color(0xFF16A34A)),
                        _buildProfileMetric('Total Sessions', totalSess, CognitoColors.primary),
                        _buildProfileMetric('Present Marks', presentSess, const Color(0xFF0F766E)),
                        _buildProfileMetric('Absent Marks', absentSess, const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personal Information Section
                  const Text('Personal & Academic Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CognitoColors.textDark)),
                  const SizedBox(height: 10),
                  _buildProfileInfoRow('Email Address', email, Icons.email_outlined),
                  _buildProfileInfoRow('Contact Phone', mobile, Icons.phone_outlined),
                  _buildProfileInfoRow('Date of Birth', dob, Icons.cake_outlined),
                  _buildProfileInfoRow('Gender Identity', gender, Icons.person_outline),
                  _buildProfileInfoRow('Aadhar Number', aadhar, Icons.badge_outlined),
                  _buildProfileInfoRow('Residential Address', address, Icons.home_outlined),
                  const SizedBox(height: 20),

                  // Session Attendance History
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
                      _handleAdminMarkStudentAttendance(student, targetStatus: 'PRESENT');
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

  Widget _buildProfileMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildProfileInfoRow(String label, String value, IconData icon) {
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

  void _showQuickManualAttendanceDialog() {
    final rollController = TextEditingController();
    String selectedStatus = 'PRESENT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.how_to_reg_rounded, color: CognitoColors.primary, size: 22),
              SizedBox(width: 8),
              Text('RBAC Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mark attendance directly by student roll number.',
                style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: rollController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Student Roll Number',
                  hintText: 'e.g. 21HN1A5401',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Attendance Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'PRESENT', child: Text('PRESENT')),
                  DropdownMenuItem(value: 'ABSENT', child: Text('ABSENT')),
                ],
                onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'PRESENT'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final roll = rollController.text.trim();
                if (roll.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final res = await ApiService.markManualAttendance(
                    studentId: '',
                    rollNumber: roll,
                    status: selectedStatus,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Attendance marked!'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                  setState(() {});
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
                      backgroundColor: CognitoColors.danger,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: CognitoColors.primary),
              child: const Text('Confirm Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
