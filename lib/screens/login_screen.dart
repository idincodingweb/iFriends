import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(
        email: _email.text,
        password: _password.text,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 240,
                decoration: const BoxDecoration(
                  gradient: AppColors.vibrant,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(40)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.favorite, color: Colors.white, size: 56),
                    SizedBox(height: 8),
                    Text('Welcome back',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700)),
                    Text('Sign in to your iFriends account',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(_email, 'Email', Icons.email_outlined),
                    const SizedBox(height: 14),
                    _field(_password, 'Password', Icons.lock_outline,
                        obscure: true),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    GestureDetector(
                      onTap: _loading ? null : _submit,
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: AppColors.vibrant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Sign In',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("New here? ",
                            style: TextStyle(color: AppColors.textMuted)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text('Create account',
                              style: TextStyle(
                                  color: AppColors.primaryCoral,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryCoral),
        filled: true,
        fillColor: AppColors.softBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
