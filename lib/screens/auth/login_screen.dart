import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final String? errorMessage;
  final bool shouldSignOut;

  const LoginScreen({
    super.key,
    this.errorMessage,
    this.shouldSignOut = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Student';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _animationController.forward();

    // Handle external error message and sign out request
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.shouldSignOut) {
        await FirebaseAuth.instance.signOut();
      }
      if (widget.errorMessage != null && mounted) {
        _showError(widget.errorMessage!);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get(const GetOptions(source: Source.server));

      // 1. If no Firestore user document exists -> navigate to LoginScreen (handled by throwing)
      if (!userData.exists) {
        await FirebaseAuth.instance.signOut();
        throw 'User data not found. Please contact admin.';
      }

      final data = userData.data()!;
      final role = data['role']?.toString();
      final isApproved = data['isApproved'] ?? false;

      // Check role mismatch first to be helpful
      if (role?.trim().toLowerCase() != _selectedRole.toLowerCase()) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          _showRoleMismatchDialog(role);
        }
        return;
      }

      // 2. If approved == false -> sign them out and show Login message
      if (!isApproved) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          _showNotApprovedDialog();
        }
        return;
      }

      // 3. Navigation after successful checks
      if (mounted) {
        String routeName = '/student_home';
        final normalizedRole = role?.trim().toLowerCase();
        if (normalizedRole == 'admin') routeName = '/admin_home';
        if (normalizedRole == 'faculty') routeName = '/faculty_home';

        Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNotApprovedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Pending'),
        content: const Text('Your account is waiting for admin approval. Please try again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRoleMismatchDialog(String? actualRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Incorrect Role'),
        content: Text('The selected role ($_selectedRole) does not match your registered account role (${actualRole ?? "None"}).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your email to reset password');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildRoleSelector(),
                      const SizedBox(height: 32),
                      _buildLoginForm(),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.quiz_rounded, size: 64, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome Back',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue your journey',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      children: [
        _RoleCard(
          title: 'Student',
          icon: Icons.school_rounded,
          isSelected: _selectedRole == 'Student',
          onTap: () => setState(() => _selectedRole = 'Student'),
        ),
        const SizedBox(width: 12),
        _RoleCard(
          title: 'Faculty',
          icon: Icons.person_rounded,
          isSelected: _selectedRole == 'Faculty',
          onTap: () => setState(() => _selectedRole = 'Faculty'),
        ),
        const SizedBox(width: 12),
        _RoleCard(
          title: 'Admin',
          icon: Icons.admin_panel_settings_rounded,
          isSelected: _selectedRole == 'Admin',
          onTap: () => setState(() => _selectedRole = 'Admin'),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!value.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPassword,
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _login,
                  child: const Text('Login'),
                ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",
          style: GoogleFonts.poppins(color: Colors.grey.shade600),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/signup'),
          child: Text(
            'Sign Up',
            style: GoogleFonts.poppins(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

