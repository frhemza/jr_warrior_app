import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum UserRole { coach, parent }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserRole _role = UserRole.parent;
  bool _isCreateAccount = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rawUrl = Uri.base.toString();
      final uri = Uri.base;

      final isCoachLink = rawUrl.contains('role=coach') ||
          uri.queryParameters['role'] == 'coach' ||
          uri.fragment.contains('role=coach');

      if (isCoachLink) {
        setState(() {
          _role = UserRole.coach;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatPhoneNumber(String input) {
    String clean = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('0')) {
      clean = '+92${clean.substring(1)}';
    } else if (!clean.startsWith('+')) {
      clean = '+$clean';
    }
    return clean;
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController(text: _emailController.text.trim());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.sourceSans3(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your registered email address to receive a password reset link.',
              style: GoogleFonts.sourceSans3(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailResetController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'name@example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailResetController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset link sent to $email'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    _showError('Error sending reset link: $e');
                  }
                }
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final rawPhone = _phoneController.text.trim();
    final formattedPhone = _formatPhoneNumber(rawPhone);

    try {
      if (_isCreateAccount) {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-not-created',
            message: 'Account was created but no user was returned.',
          );
        }

        final fullName = _fullNameController.text.trim();
        await user.updateDisplayName(fullName);

        // Save user profile directly to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'role': _role.name,
          'name': fullName,
          'fullName': fullName,
          'phone': formattedPhone,
          'parentPhone': formattedPhone,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      _showError(_messageForAuthError(error));
    } on FirebaseException catch (error) {
      _showError(error.message ?? 'Unable to save your profile. Please try again.');
    } catch (_) {
      _showError(
        _isCreateAccount
            ? 'Unable to create your account. Please try again.'
            : 'Unable to sign in. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isCreateAccount = !_isCreateAccount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCoachMode = _role == UserRole.coach;

    final subtitle = _isCreateAccount
        ? (isCoachMode ? 'Create a Coach account' : 'Create your parent account')
        : 'Sign in to continue';
    final actionLabel = _isCreateAccount ? 'Create Account' : 'Sign In';
    final switchLabel = _isCreateAccount
        ? 'Already have an account? Sign In'
        : 'Need an account? Create Account';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 56,
                      color: Color(0xFFC85A32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Jr. Warrior',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sourceSans3(
                        fontSize: 16,
                        color: colors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isCreateAccount) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCoachMode
                              ? const Color(0xFFC85A32).withValues(alpha: 0.12)
                              : colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCoachMode
                                ? const Color(0xFFC85A32)
                                : colors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCoachMode ? Icons.sports : Icons.family_restroom,
                              color: isCoachMode ? const Color(0xFFC85A32) : colors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isCoachMode
                                    ? 'Secret Coach Registration Active'
                                    : 'Parent Account Registration',
                                textAlign: TextAlign.left,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.bold,
                                  color: isCoachMode ? const Color(0xFFC85A32) : colors.primary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _fullNameController,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline, color: colors.primary),
                        ),
                        validator: (value) {
                          if (!_isCreateAccount) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: InputDecoration(
                          labelText: 'Phone Number (e.g. 03001234567)',
                          prefixIcon: Icon(Icons.phone_outlined, color: colors.primary),
                        ),
                        validator: (value) {
                          if (!_isCreateAccount) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your phone number';
                          }
                          if (value.trim().length < 10) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline, color: colors.primary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (!_isCreateAccount) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _showForgotPasswordDialog,
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.sourceSans3(
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          : Text(actionLabel),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : _toggleMode,
                      child: Text(switchLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}