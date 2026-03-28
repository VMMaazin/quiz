import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _employeeIdController = TextEditingController();
  
  String _selectedRole = 'Student';
  String? _selectedClass;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rollNumberController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == 'Student' && _selectedClass == null) {
      _showError('Please select your class');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userData = {
        'uid': userCredential.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'isApproved': false,
      };

      if (_selectedRole == 'Student') {
        userData['rollNumber'] = _rollNumberController.text.trim();
        userData['classId'] = _selectedClass!;
      } else if (_selectedRole == 'Faculty') {
        userData['employeeId'] = _employeeIdController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/pending_approval');
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Registration failed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRoleSelector(),
              const SizedBox(height: 32),
              _buildCommonFields(),
              const SizedBox(height: 20),
              if (_selectedRole == 'Student') _buildStudentFields(),
              if (_selectedRole == 'Faculty') _buildFacultyFields(),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _signup,
                      child: const Text('Register'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Role',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _RoleButton(
              title: 'Student',
              icon: Icons.school_rounded,
              isSelected: _selectedRole == 'Student',
              onTap: () => setState(() => _selectedRole = 'Student'),
            ),
            const SizedBox(width: 12),
            _RoleButton(
              title: 'Faculty',
              icon: Icons.person_rounded,
              isSelected: _selectedRole == 'Faculty',
              onTap: () => setState(() => _selectedRole = 'Faculty'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Full Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
        ),
        const SizedBox(height: 20),
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
      ],
    );
  }

  Widget _buildStudentFields() {
    return Column(
      children: [
        TextFormField(
          controller: _rollNumberController,
          decoration: const InputDecoration(
            hintText: 'Roll Number',
            prefixIcon: Icon(Icons.numbers),
          ),
          validator: (value) => value!.isEmpty ? 'Please enter roll number' : null,
        ),
        const SizedBox(height: 20),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();

            final classes = snapshot.data!.docs;
            return DropdownButtonFormField<String>(
              initialValue: _selectedClass,
              decoration: const InputDecoration(
                hintText: 'Select Class',
                prefixIcon: Icon(Icons.class_outlined),
              ),
              items: classes.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final className = data['className'] ?? data['name'] ?? 'Unknown Class';
                final section = data['section'] ?? '';
                final displayText = section.isEmpty ? className : '$className - $section';

                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(displayText),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedClass = value),
              validator: (value) => value == null ? 'Please select a class' : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildFacultyFields() {
    return TextFormField(
      controller: _employeeIdController,
      decoration: const InputDecoration(
        hintText: 'Employee ID',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      validator: (value) => value!.isEmpty ? 'Please enter employee ID' : null,
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleButton({
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
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
