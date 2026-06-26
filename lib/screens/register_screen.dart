import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.length < 6) {
      setState(() => _error = 'Lengkapi semua field (password ≥ 6 karakter).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signUp(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        username: _username.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.vibrant.createShader(b),
                child: const Text(
                  'Create your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Join the iFriends community 💛',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              _field(_name, 'Display name', Icons.badge_outlined),
              const SizedBox(height: 12),
              _field(_username, 'Username (unique)', Icons.alternate_email),
              const SizedBox(height: 12),
              _field(_email, 'Email', Icons.email_outlined),
              const SizedBox(height: 12),
              _field(_password, 'Password', Icons.lock_outline, obscure: true),
              const SizedBox(height: 18),
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
                      : const Text('Create account',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
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
