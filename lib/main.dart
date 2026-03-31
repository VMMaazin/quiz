import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/faculty/faculty_home_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';
import 'screens/student/attempt_quiz_screen.dart';
import 'screens/student/quiz_result_review_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'College Quiz App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth_wrapper': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/pending_approval': (context) => const PendingApprovalScreen(),
        '/admin_home': (context) => const AdminHomeScreen(),
        '/faculty_home': (context) => const FacultyHomeScreen(),
        '/student_home': (context) => const StudentHomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    // Give Firebase a moment to initialize the current user state
    await Future.delayed(Duration.zero);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final data = doc.data()!;
      final isApproved = data['isApproved'] ?? false;
      final role = data['role']?.toString();

      if (!isApproved) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(
                errorMessage: 'Your account is pending admin approval',
                shouldSignOut: true,
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        final normalizedRole = role?.trim().toLowerCase();
        if (normalizedRole == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin_home');
        } else if (normalizedRole == 'faculty') {
          Navigator.pushReplacementNamed(context, '/faculty_home');
        } else {
          Navigator.pushReplacementNamed(context, '/student_home');
        }
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
