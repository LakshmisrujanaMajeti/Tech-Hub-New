import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 1600));

    // 1. Check App Version
    try {
      final versionInfo = await ApiService.checkAppVersion();
      if (mounted && (versionInfo['updateAvailable'] == true || versionInfo['forceUpdate'] == true)) {
        // Show update notification if forceUpdate or updateAvailable
        _showUpdateDialog(versionInfo);
        return;
      }
    } catch (_) {}

    // Always clear session on fresh app open so the user is required to authenticate on the login page
    await ApiService.logout();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showUpdateDialog(Map<String, dynamic> versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: !(versionInfo['forceUpdate'] == true),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update_alt, color: CognitoColors.primary),
            const SizedBox(width: 8),
            Text(
              versionInfo['forceUpdate'] == true ? 'Mandatory Update' : 'New Update Available',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${versionInfo['latestVersion']} is now available for Cognito Tech Hub.',
              style: const TextStyle(fontSize: 13, color: CognitoColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text('What’s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            ...?((versionInfo['releaseNotes'] as List?)?.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $note', style: const TextStyle(fontSize: 12, color: CognitoColors.textDark)),
                ))),
          ],
        ),
        actions: [
          if (!(versionInfo['forceUpdate'] == true))
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: CognitoColors.primary.withOpacity(0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/logo.webp',
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school_rounded,
                      size: 60,
                      color: CognitoColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'COGNITO TECH HUB',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: CognitoColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cognito Insights Private Limited',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CognitoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(CognitoColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
