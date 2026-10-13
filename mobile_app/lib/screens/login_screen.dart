import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'registration_screen.dart';
import 'student_dashboard_screen.dart';
import 'super_admin_dashboard_screen.dart';
import 'trainer_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _logoTapCount = 0;
  DateTime? _lastLogoTapTime;

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastLogoTapTime == null || now.difference(_lastLogoTapTime!) > const Duration(seconds: 3)) {
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }
    _lastLogoTapTime = now;
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _showServerConfigDialog();
    }
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.replaceAll(' ', '').trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both Email / Roll Number and Password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.login(identifier, password);
      if (mounted) {
        final user = res['user'] ?? {};
        final role = user['role'] ?? 'STUDENT';

        if (role == 'SUPER_ADMIN' || role == 'PROGRAM_MANAGER' || role == 'COLLEGE_ADMIN' || role == 'TPO') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SuperAdminDashboardScreen(userProfile: user),
            ),
          );
        } else if (role == 'TRAINER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TrainerDashboardScreen(userProfile: user),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDashboardScreen(userProfile: user),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        String msg = e.toString().replaceAll('Exception: ', '');
        if (msg.contains('TimeoutException') ||
            msg.contains('SocketException') ||
            msg.contains('ClientException') ||
            msg.contains('Connection refused') ||
            msg.contains('Network is unreachable') ||
            msg.contains('Future not completed') ||
            msg.contains('OS Error') ||
            msg.contains('errno =') ||
            msg.contains('Failed host lookup')) {
          msg = 'Unable to reach backend server. Please check your mobile data or Wi-Fi connection.';
        }
        _errorMessage = msg;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showServerConfigDialog() {
    final serverController = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: CognitoColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Server & Network', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend API & Sync Endpoint:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitoColors.textDark),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                hintText: 'e.g. https://techhub.cognitoinsights.ai/api',
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cloud_done_rounded, size: 14, color: CognitoColors.primary),
                  label: const Text('Cloud API (Live)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => serverController.text = ApiService.publicCloudUrl,
                ),
                ActionChip(
                  avatar: const Icon(Icons.wifi_rounded, size: 14, color: CognitoColors.primary),
                  label: const Text('Wi-Fi (192.168.6.200)', style: TextStyle(fontSize: 11)),
                  onPressed: () => serverController.text = ApiService.wifiLanUrl,
                ),
                ActionChip(
                  avatar: const Icon(Icons.developer_mode_rounded, size: 14),
                  label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                  onPressed: () => serverController.text = ApiService.emulatorUrl,
                ),
                ActionChip(
                  avatar: const Icon(Icons.storage_rounded, size: 14),
                  label: const Text('Supabase Cloud', style: TextStyle(fontSize: 11)),
                  onPressed: () => serverController.text = '${ApiService.supabaseUrl}/rest/v1',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.setCustomBaseUrl(serverController.text.trim());
              await ApiService.initialize();
              if (!ctx.mounted) return;
              if (mounted) {
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Endpoint updated: ${ApiService.baseUrl}'),
                    backgroundColor: CognitoColors.primary,
                  ),
                );
              }
            },
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Brand Header with sharp Cognito Emblem (Secret 5-tap for admin network configuration)
                Center(
                  child: GestureDetector(
                    onTap: _handleLogoTap,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: CognitoColors.primary.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/emblem.png',
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/logo.webp',
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            size: 44,
                            color: CognitoColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cognito Tech Hub',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: CognitoColors.darkBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cognito Insights Solutions Pvt Ltd',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CognitoColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Multi-Tenant Engineering Classroom Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: CognitoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Error Banner
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CognitoColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CognitoColors.danger.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: CognitoColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: CognitoColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Inputs
                const Text(
                  'Email or Student Roll Number',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _identifierController,
                  decoration: const InputDecoration(
                    hintText: 'Enter email address or roll number',
                    prefixIcon: Icon(Icons.person_outline, color: CognitoColors.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CognitoColors.textDark),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline, color: CognitoColors.textSecondary, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: CognitoColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CognitoColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'LOG IN',
                          style: TextStyle(letterSpacing: 0.5, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),

                // Student Registration CTA
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(fontSize: 13, color: CognitoColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                        );
                      },
                      child: const Text(
                        'Register as Student',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: CognitoColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
