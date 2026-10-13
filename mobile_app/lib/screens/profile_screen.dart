import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic>? userProfile;

  const ProfileScreen({super.key, this.userProfile});

  @override
  Widget build(BuildContext context) {
    final user = userProfile ?? {};
    final college = user['college'] ?? {};
    final student = user['student'] ?? {};

    final fullName = user['fullName'] ?? 'Student User';
    final email = user['email'] ?? 'student@techhub.com';
    final rollNumber = student['roll_number'] ?? '21KITS0501';
    final regNumber = student['registration_number'] ?? '21034A0501';
    final branch = student['branch'] ?? 'CSE';
    final year = student['year'] ?? '3rd Year';
    final section = student['section'] ?? 'A';
    final collegeName = college['name'] ?? college['shortName'] ?? 'KITS Divili';
    final primaryColor = CognitoColors.parseHex(college['primaryColor']);

    return Scaffold(
      backgroundColor: CognitoColors.background,
      appBar: AppBar(
        title: const Text('My Identity Card'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Student ID Card Design
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, CognitoColors.darkBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
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
                                const Text(
                                  'COGNITO TECH HUB',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  collegeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'STUDENT ID',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            fullName.isNotEmpty ? fullName[0] : 'S',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Roll No: $rollNumber',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Reg No: $regNumber',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _idField('Branch', branch),
                      _idField('Year', year),
                      _idField('Section', section),
                      _idField('Status', 'ACTIVE'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Info List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CognitoColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: CognitoColors.primary, size: 20),
                    title: const Text('Email Address', style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                    subtitle: Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                  ),
                  const Divider(height: 1, color: CognitoColors.border),
                  ListTile(
                    leading: const Icon(Icons.apartment_outlined, color: CognitoColors.primary, size: 20),
                    title: const Text('Institution Tenant', style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                    subtitle: Text(collegeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                  ),
                  const Divider(height: 1, color: CognitoColors.border),
                  const ListTile(
                    leading: Icon(Icons.system_security_update_good_outlined, color: CognitoColors.primary, size: 20),
                    title: Text('App Engine Version', style: TextStyle(fontSize: 12, color: CognitoColors.textSecondary)),
                    subtitle: Text('v1.2.0 (Build 2026.1)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CognitoColors.textDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () async {
                await ApiService.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CognitoColors.dangerLight,
                foregroundColor: CognitoColors.danger,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('LOG OUT ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _idField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
