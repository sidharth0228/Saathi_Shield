import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';

class OTPVerifyScreen extends ConsumerStatefulWidget {
  final String phone;

  const OTPVerifyScreen({
    Key? key,
    required this.phone,
  }) : super(key: key);

  @override
  ConsumerState<OTPVerifyScreen> createState() => _OTPVerifyScreenState();
}

class _OTPVerifyScreenState extends ConsumerState<OTPVerifyScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _onVerifyPressed() {
    if (_formKey.currentState!.validate()) {
      final code = _otpController.text.trim();
      ref.read(authProvider.notifier).verifyOtp(widget.phone, code);
    }
  }

  void _onResendPressed() {
    ref.read(authProvider.notifier).requestLoginOtp(widget.phone);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification OTP code resent.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        ref.read(authProvider.notifier).resetError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                IconButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.arrow_back),
                  color: theme.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify OTP',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A 6-digit OTP code has been dispatched to ${widget.phone}. Enter it below to complete verification.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // OTP code input
                CustomTextField(
                  controller: _otpController,
                  labelText: 'Verification Code',
                  hintText: '6-digit code',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.lock_clock,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the verification code';
                    }
                    if (value.length != 6) {
                      return 'Code must be exactly 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Verify Button
                CustomButton(
                  text: 'Verify OTP & Log In',
                  onPressed: _onVerifyPressed,
                  isLoading: authState is AuthLoading,
                ),
                const SizedBox(height: 24),

                // Resend section
                Center(
                  child: TextButton(
                    onPressed: authState is AuthLoading ? null : _onResendPressed,
                    child: const Text('Resend Code'),
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
