import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _showOtp = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_showOtp) {
        await ref
            .read(authProvider.notifier)
            .verify(_emailController.text.trim(), _otpController.text.trim());
      } else {
        await ref
            .read(authProvider.notifier)
            .login(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
        // If login didn't throw, and state is NOT authenticated, it means OTP is required
        if (!ref.read(authProvider)) {
          setState(() => _showOtp = true);
        }
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        setState(() => _error = 'Invalid credentials');
      } else {
        setState(() => _error = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _showOtp ? 'Verification Code' : 'Welcome Back',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!_showOtp) ...[
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                  ),
                ] else ...[
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'Code from Email',
                      border: OutlineInputBorder(),
                      helperText: 'Check your inbox for a 6-digit code',
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _submit(),
                    autofocus: true,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_showOtp ? 'Verify' : 'Login'),
                ),
                if (_showOtp)
                  TextButton(
                    onPressed: () => setState(() => _showOtp = false),
                    child: const Text('Back to Login'),
                  ),
                if (!_showOtp)
                  TextButton(
                    onPressed: () {
                      ref.read(serverUrlProvider.notifier).clear();
                    },
                    child: const Text('Change Server'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
