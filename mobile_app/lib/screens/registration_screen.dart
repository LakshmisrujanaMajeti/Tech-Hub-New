import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'student_dashboard_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: College Selection
  List<dynamic> _colleges = [];
  Map<String, dynamic>? _selectedCollege;
  final _collegeSearchController = TextEditingController();

  List<dynamic> get _filteredColleges {
    final query = _collegeSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _colleges;
    return _colleges.where((c) {
      final name = (c['college_name'] ?? '').toString().toLowerCase();
      final shortName = (c['short_name'] ?? '').toString().toLowerCase();
      final code = (c['college_code'] ?? '').toString().toLowerCase();
      return name.contains(query) || shortName.contains(query) || code.contains(query);
    }).toList();
  }

  // Step 2: Student Details
  final _fullNameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _mobileController = TextEditingController();
  String _selectedBranch = 'CSE';
  String _selectedYear = '3rd Year';
  String _selectedSection = 'A';
  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];
  DateTime? _selectedDob;
  final _dobController = TextEditingController();
  final _aadharController = TextEditingController();
  final _addressController = TextEditingController();

  // Step 3: OTP
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  String? _verificationToken;

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _customBranchController = TextEditingController();

  final List<String> _branches = [
    'CSE',
    'AI&DS',
    'AIML',
    'CSE(DS)',
    'EEE',
    'ECE',
    'Agri',
    'Mechanical',
    'Civil',
    'Others',
  ];
  final List<String> _years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> _sections = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _fetchColleges();
  }

  Future<void> _fetchColleges() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getPublicColleges();
      setState(() {
        _colleges = list;
        if (_colleges.isNotEmpty && _selectedCollege == null) {
          _selectedCollege = _colleges.first;
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load colleges.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatError(dynamic e) {
    final str = e.toString().replaceAll('Exception: ', '');
    if (str.contains('SocketException') ||
        str.contains('ClientException') ||
        str.contains('TimeoutException') ||
        str.contains('Failed host lookup') ||
        str.contains('Connection refused') ||
        str.contains('OS Error') ||
        str.contains('errno = 7') ||
        str.contains('Network is unreachable')) {
      return 'Unable to reach server. Please check your mobile data or Wi-Fi connection and try again.';
    }
    return str;
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please provide a valid email address.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.sendOtp(email);
      setState(() {
        _otpSent = true;
        _otpController.clear();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('6-digit verification code sent to $email. Please check your inbox (and spam folder) and enter the code below.'),
          backgroundColor: CognitoColors.success,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = _formatError(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Enter the 6-digit verification code.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final token = await ApiService.verifyOtp(email, otp);
      setState(() {
        _verificationToken = token;
        _currentStep = 3; // Move to password step
      });
    } catch (e) {
      setState(() => _errorMessage = _formatError(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.registerStudent({
        'verificationToken': _verificationToken,
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'password': password,
        'collegeId': _selectedCollege!['id'],
        'rollNumber': _rollNumberController.text.trim(),
        'registrationNumber': _regNumberController.text.trim(),
        'branch': _selectedBranch == 'Others'
            ? (_customBranchController.text.trim().isNotEmpty ? _customBranchController.text.trim() : 'Others')
            : _selectedBranch,
        'year': _selectedYear,
        'section': _selectedSection,
        'gender': _selectedGender,
        'dob': _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        'aadharId': _aadharController.text.trim().isNotEmpty ? _aadharController.text.trim() : null,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => StudentDashboardScreen(userProfile: res['user']),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _errorMessage = _formatError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Student Registration'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Step Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: List.generate(4, (index) {
                      final isDone = _currentStep > index;
                      final isCurrent = _currentStep == index;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isDone || isCurrent ? CognitoColors.primary : CognitoColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CognitoColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: CognitoColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: CognitoColors.danger, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: _currentStep == 0
                      ? _buildStepCollege()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: _buildCurrentStep(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStepCollege();
      case 1:
        return _buildStepDetails();
      case 2:
        return _buildStepOtp();
      case 3:
        return _buildStepPassword();
      default:
        return const SizedBox();
    }
  }

  // Step 0: College Picker
  Widget _buildStepCollege() {
    final collegesToDisplay = _filteredColleges;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Step 1 of 4',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  '🏛️ Andhra Pradesh',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select Your College Institution',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CognitoColors.darkBlue),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose your engineering college to link with your campus Tech Hub program.',
            style: TextStyle(fontSize: 13, color: CognitoColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Search Bar for 29 AP Colleges
          TextField(
            controller: _collegeSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search 29 AP colleges (name, code, city)...',
              prefixIcon: const Icon(Icons.search, color: CognitoColors.primary),
              suffixIcon: _collegeSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: CognitoColors.textSecondary),
                      onPressed: () {
                        _collegeSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: CognitoColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // College Count and Selected Badge
          Row(
            children: [
              Text(
                'Showing ${collegesToDisplay.length} of ${_colleges.length} Engineering Colleges',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textSecondary),
              ),
              const Spacer(),
              if (_selectedCollege != null)
                Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: CognitoColors.lightBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedCollege!['short_name'] ?? '',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CognitoColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Scrollable List of Colleges (Virtualized & fast)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : collegesToDisplay.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 44, color: CognitoColors.textSecondary),
                            const SizedBox(height: 10),
                            Text(
                              'No colleges match "${_collegeSearchController.text}"',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CognitoColors.textDark),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                _collegeSearchController.clear();
                                setState(() {});
                              },
                              child: const Text('Reset Search'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: collegesToDisplay.length,
                        itemBuilder: (context, index) {
                          final college = collegesToDisplay[index];
                          final isSelected = _selectedCollege?['id'] == college['id'];
                          final isRegistered = college['is_registered_hub'] == true ||
                              college['college_code'] == 'ADARSH' ||
                              college['college_code'] == 'KITS_DIVILI';
                          final rollCode = (college['roll_code'] ??
                              (college['college_code'] == 'ADARSH'
                                  ? 'HN'
                                  : college['college_code'] == 'KITS_DIVILI'
                                      ? 'JQ'
                                      : college['college_code']) ??
                              '').toString().toUpperCase();
                          final collegeName = (college['college_name'] ?? college['name'] ?? '').toString();
                          final district = (college['district'] ?? 'Andhra Pradesh').toString();
                          final isAdarsh = rollCode == 'HN' || college['college_code'] == 'ADARSH' || collegeName.toLowerCase().contains('adarsh');
                          final isKits = rollCode == 'JQ' || college['college_code'] == 'KITS_DIVILI' || collegeName.toLowerCase().contains('kits');
                          final hasOfficialLogo = isRegistered && (isAdarsh || isKits);

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedCollege = college);
                              if (!isRegistered) {
                                _showComingSoonBottomSheet(college);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? CognitoColors.primary : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: CognitoColors.primary.withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? CognitoColors.primary.withOpacity(0.4)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_rounded,
                                      color: isSelected ? CognitoColors.primary : const Color(0xFF475569),
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
                                                college['college_name'] ?? college['short_name'] ?? '',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5,
                                                  color: isSelected ? CognitoColors.primary : CognitoColors.textDark,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (rollCode.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  rollCode,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: isSelected ? CognitoColors.primary : const Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$district • Roll Code: $rollCode',
                                          style: const TextStyle(fontSize: 11, color: CognitoColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? CognitoColors.primary : const Color(0xFFCBD5E1),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Pinned Bottom Action Button
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _selectedCollege == null
                ? null
                : () {
                    final isRegistered = _selectedCollege!['is_registered_hub'] == true ||
                        _selectedCollege!['college_code'] == 'ADARSH' ||
                        _selectedCollege!['college_code'] == 'KITS_DIVILI';
                    if (isRegistered) {
                      setState(() {
                        _errorMessage = null;
                        _currentStep = 1;
                      });
                    } else {
                      _showComingSoonBottomSheet(_selectedCollege!);
                    }
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _selectedCollege != null
                  ? ((_selectedCollege!['is_registered_hub'] == true ||
                          _selectedCollege!['college_code'] == 'ADARSH' ||
                          _selectedCollege!['college_code'] == 'KITS_DIVILI')
                      ? 'Continue with ${_selectedCollege!['short_name'] ?? 'College'}'
                      : 'Check Hub Availability (${_selectedCollege!['short_name'] ?? 'College'})')
                  : 'Select a College to Continue',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Coming Soon Bottom Sheet for Non-registered Colleges (Student Data only recorded in KITS & Adarsh)
  void _showComingSoonBottomSheet(Map<String, dynamic> college) {
    final emailCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
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
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: CognitoColors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Text(
                            'REQUEST ACCEPTED • COMING SOON',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          college['short_name'] ?? college['college_name'] ?? 'College',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: CognitoColors.darkBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Cognito Tech Hub classroom programs are currently active at Adarsh College of Engineering and KITS Divili.\n\nYour request has been accepted! Enter your student email below to receive updates as soon as Tech Hub launches at your campus.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Student Email Address',
                  hintText: 'e.g. yourname@student.ac.in',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rollCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'College Roll Number (Optional)',
                  hintText: 'e.g. 21${college['roll_code'] ?? 'XX'}1A5401',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid email address.'),
                              backgroundColor: CognitoColors.danger,
                            ),
                          );
                          return;
                        }
                        setModalState(() => isSubmitting = true);
                        await ApiService.submitCampusInterest(
                          collegeId: college['id'].toString(),
                          email: email,
                          rollNumber: rollCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Request Accepted! We will update you at $email once Tech Hub launches at ${college['short_name'] ?? 'your college'}.',
                            ),
                            backgroundColor: CognitoColors.success,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Request Accepted — Notify Me',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step 2: Academic & Personal Details (With Official College Roll Code Enforcement)
  Widget _buildStepDetails() {
    final college = _selectedCollege;
    final collegeName = college?['short_name'] ?? college?['college_name'] ?? 'College';
    final rollCode = (college?['roll_code'] ??
        (college?['college_code'] == 'ADARSH'
            ? 'HN'
            : college?['college_code'] == 'KITS_DIVILI'
                ? 'JQ'
                : college?['college_code']) ??
        '').toString().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 2 of 4',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Academic Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CognitoColors.darkBlue),
        ),
        const SizedBox(height: 14),

        // Selected College Banner with Official Roll Code
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.school, size: 20, color: CognitoColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  collegeName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.darkBlue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CognitoColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Code: $rollCode',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _fullNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter student full name'),
        ),
        const SizedBox(height: 14),

        const Text('College Roll Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _rollNumberController,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          decoration: InputDecoration(
            hintText: 'e.g. 21${rollCode}1A5401',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 6),

        // Helper guidance info container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: CognitoColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your college code is $rollCode (Example: 21${rollCode}1A5401 or 22${rollCode}1A0501)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Branch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedBranch,
                    items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedBranch = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedYear,
                    items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedYear = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedSection,
                    items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedSection = v!),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_selectedBranch == 'Others') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customBranchController,
            decoration: const InputDecoration(
              labelText: 'Specify Your Branch Name *',
              hintText: 'e.g. Chemical, Mining, Automobile',
              prefixIcon: Icon(Icons.school_outlined, size: 20),
            ),
          ),
        ],
        const SizedBox(height: 14),

        const Text('Mobile Number (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _mobileController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          maxLength: 10,
          decoration: const InputDecoration(
            hintText: 'Enter 10-digit mobile number',
            counterText: '',
            prefixIcon: Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 14),

        // Personal Demographics: Gender & Date of Birth (DOB)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gender *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _genders
                        .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedGender = v ?? _selectedGender),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date of Birth *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _dobController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDob ?? DateTime(2003, 1, 1),
                        firstDate: DateTime(1980),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDob = picked;
                          _dobController.text =
                              "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Aadhaar ID
        const Text('Aadhaar ID (12 Digits) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _aadharController,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: const InputDecoration(
            hintText: 'Enter 12-digit Government Aadhaar number',
            prefixIcon: Icon(Icons.badge_outlined, size: 20),
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),

        // Residential Address
        const Text('Permanent / Current Address *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _addressController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Enter student full residential address (Door No, Village/City, District)',
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Icon(Icons.home_outlined, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _errorMessage = null;
                _currentStep = 0;
              }),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final name = _fullNameController.text.trim();
                  final roll = _rollNumberController.text.trim().toUpperCase();
                  final aadhar = _aadharController.text.trim();
                  final address = _addressController.text.trim();
                  final mobile = _mobileController.text.trim();

                  if (name.isEmpty || roll.isEmpty) {
                    setState(() => _errorMessage = 'Please provide your Full Name and Roll Number.');
                    return;
                  }

                  if (mobile.isNotEmpty && (mobile.length != 10 || !RegExp(r'^\d{10}$').hasMatch(mobile))) {
                    setState(() => _errorMessage = 'Mobile number must be exactly 10 digits.');
                    return;
                  }

                  if (_dobController.text.trim().isEmpty) {
                    setState(() => _errorMessage = 'Please select your Date of Birth.');
                    return;
                  }

                  if (aadhar.isNotEmpty && (aadhar.length != 12 || !RegExp(r'^\d{12}$').hasMatch(aadhar))) {
                    setState(() => _errorMessage = 'Aadhaar ID must be exactly 12 digits (numbers only).');
                    return;
                  }

                  if (address.isEmpty) {
                    setState(() => _errorMessage = 'Please provide your residential address.');
                    return;
                  }

                  if (rollCode == 'HN' && roll.contains('JQ')) {
                    setState(() => _errorMessage =
                        "You entered code 'JQ' which belongs to KITS Divili. Your college code for Adarsh is 'HN' (e.g., 21HN1A5401).");
                    return;
                  }

                  if (rollCode == 'JQ' && roll.contains('HN')) {
                    setState(() => _errorMessage =
                        "You entered code 'HN' which belongs to Adarsh College. Your college code for KITS Divili is 'JQ' (e.g., 21JQ1A5401).");
                    return;
                  }

                  if (rollCode.isNotEmpty && !roll.contains(rollCode)) {
                    setState(() => _errorMessage =
                        "Your college code for $collegeName is '$rollCode' (e.g. 21${rollCode}1A5401). Roll number must contain your college code '$rollCode'.");
                    return;
                  }

                  setState(() {
                    _errorMessage = null;
                    _currentStep = 2;
                  });
                },
                child: const Text('Proceed to Verification'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Step 2: Email & OTP
  Widget _buildStepOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 3 of 4',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Verify Email Address',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CognitoColors.darkBlue),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your email address to receive a secure 6-digit one-time verification code.',
          style: TextStyle(fontSize: 13, color: CognitoColors.textSecondary),
        ),
        const SizedBox(height: 20),

        const Text('Student Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                enabled: !_otpSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Enter student email address'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _otpSent ? CognitoColors.textSecondary : CognitoColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: Text(_otpSent ? 'Resend' : 'Send OTP', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_otpSent) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: CognitoColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'OTP sent to ${_emailController.text.trim()}. Check inbox or spam folder.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _otpSent = false),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                  child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('6-Digit Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: const InputDecoration(hintText: '••••••', counterText: ''),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Verify OTP & Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],

        const SizedBox(height: 12),
        TextButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('Back to Details')),
      ],
    );
  }

  // Step 3: Password Creation
  Widget _buildStepPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Step 4 of 4',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CognitoColors.primary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Create Your Password',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CognitoColors.darkBlue),
        ),
        const SizedBox(height: 20),

        const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: 'Enter password (min 6 characters)')),
        const SizedBox(height: 14),

        const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm password')),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : _completeRegistration,
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('COMPLETE REGISTRATION'),
        ),
      ],
    );
  }
}
