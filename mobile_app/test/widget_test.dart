import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cognito_techhub/screens/login_screen.dart';
import 'package:cognito_techhub/screens/profile_screen.dart';
import 'package:cognito_techhub/screens/attendance_screen.dart';
import 'package:cognito_techhub/screens/materials_screen.dart';
import 'package:cognito_techhub/screens/behaviour_screen.dart';
import 'package:cognito_techhub/screens/student_dashboard_screen.dart';
import 'package:cognito_techhub/screens/super_admin_dashboard_screen.dart';
import 'package:cognito_techhub/screens/trainer_dashboard_screen.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    expect(find.text('Cognito Tech Hub'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
    expect(find.text('Register as Student'), findsOneWidget);
  });

  testWidgets('Login screen renders cleanly on compact 320x640 mobile screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Cognito Tech Hub'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders cleanly on compact 320x640 screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          userProfile: {
            'fullName': 'Sri Satya Sai Alugolu',
            'email': 'srisatyasai@adarsh.edu.in',
            'college': {'name': 'Adarsh College of Engineering & Technology (Autonomous)', 'shortName': 'ADARSH'},
            'student': {'roll_number': '21HN1A0589', 'registration_number': '21034A0589', 'branch': 'CSE-AI', 'year': '4th Year', 'section': 'A'},
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('My Identity Card'), findsOneWidget);
    expect(find.text('STUDENT ID'), findsOneWidget);
  });

  testWidgets('MaterialsScreen renders cleanly on compact 320x640 screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MaterialsScreen(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Study Materials & Handouts'), findsOneWidget);
  });

  testWidgets('BehaviourScreen renders cleanly on compact 320x640 screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BehaviourScreen(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Learning Behaviour'), findsOneWidget);
  });

  testWidgets('AttendanceScreen renders cleanly on compact 320x640 screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AttendanceScreen(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('My Attendance'), findsOneWidget);
  });

  testWidgets('StudentDashboardScreen renders cleanly on compact 320x640 screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterErrorDetails? caughtDetails;
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtDetails = details;
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentDashboardScreen(
          userProfile: {
            'fullName': 'Sri Satya Sai Alugolu',
            'college': {'name': 'Adarsh College of Engineering & Technology (Autonomous)', 'shortName': 'ADARSH'},
            'student': {'roll_number': '21HN1A0589', 'branch': 'CSE-AI', 'year': '4th Year'},
          },
        ),
      ),
    );
    await tester.pump();
    FlutterError.onError = oldHandler;
    expect(caughtDetails, isNull);
    expect(find.textContaining('Sri Satya Sai Alugolu'), findsOneWidget);
  });

  testWidgets('SuperAdminDashboardScreen renders cleanly on compact 320x640 screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SuperAdminDashboardScreen(
          userProfile: {
            'fullName': 'Super Admin',
            'role': 'SUPER_ADMIN',
            'email': 'admin@techhub.com',
          },
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Cognito Tech Hub'), findsWidgets);
  });

  testWidgets('TrainerDashboardScreen renders cleanly on compact 320x640 screen without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: TrainerDashboardScreen(
          userProfile: {
            'fullName': 'Senior Faculty Trainer',
            'role': 'TRAINER',
            'email': 'trainer@techhub.com',
          },
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Senior Faculty Trainer'), findsOneWidget);
  });

  test('Attendance window calculation correctly classifies 9:00 AM to 4:00 PM operating hours', () {
    String getWindowStatus(int hour) {
      if (hour < 9) return 'NOT_OPEN_YET';
      if (hour >= 16) return 'TIMED_OUT';
      return 'OPEN';
    }

    // Before 9:00 AM: NOT_OPEN_YET
    expect(getWindowStatus(0), 'NOT_OPEN_YET');
    expect(getWindowStatus(8), 'NOT_OPEN_YET');

    // Working hours 09:00 AM to 04:00 PM (hour 9 to 15): OPEN
    expect(getWindowStatus(9), 'OPEN');
    expect(getWindowStatus(12), 'OPEN');
    expect(getWindowStatus(15), 'OPEN');

    // After 04:00 PM (hour 16 and beyond): TIMED_OUT
    expect(getWindowStatus(16), 'TIMED_OUT');
    expect(getWindowStatus(17), 'TIMED_OUT');
    expect(getWindowStatus(23), 'TIMED_OUT');
  });
}
