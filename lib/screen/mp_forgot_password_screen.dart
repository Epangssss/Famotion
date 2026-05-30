import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../utils/auth_helper.dart';

class MPForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const MPForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<MPForgotPasswordScreen> createState() => _MPForgotPasswordScreenState();
}

class _MPForgotPasswordScreenState extends State<MPForgotPasswordScreen> {
  late TextEditingController emailCont;
  final otpCont = TextEditingController();
  final newPassCont = TextEditingController();
  
  bool otpSent = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    emailCont = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCE7CD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A2A14)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A8A53).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset, size: 64, color: Color(0xFF6A8A53)),
              ).center(),
              32.height,
              Text(
                otpSent ? 'Reset Password' : 'Forgot Password?', 
                style: boldTextStyle(size: 32, color: const Color(0xFF1A2A14))
              ),
              8.height,
              Text(
                otpSent 
                    ? 'Enter the 4-digit OTP sent to your email and your new password.'
                    : 'Enter your registered email address to receive a password reset OTP.', 
                style: secondaryTextStyle(size: 14)
              ),
              32.height,

              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: !otpSent ? _buildEmailForm() : _buildOtpForm(),
              ),

              24.height,
              AppButton(
                text: otpSent ? 'Reset Password' : 'Send OTP',
                color: const Color(0xFFD8A854),
                textColor: Colors.white,
                shapeBorder: RoundedRectangleBorder(borderRadius: radius(16)),
                onTap: isLoading ? null : () async {
                  setState(() => isLoading = true);
                  
                  if (!otpSent) {
                    final email = emailCont.text.trim();
                    if (email.isEmpty) {
                      toast('Please enter your email address');
                    } else {
                      final success = await AuthHelper().requestPasswordReset(context, email: email);
                      if (success) {
                        setState(() => otpSent = true);
                      }
                    }
                  } else {
                    final email = emailCont.text.trim();
                    final otp = otpCont.text.trim();
                    final pass = newPassCont.text.trim();
                    if (otp.isEmpty || pass.isEmpty) {
                      toast('Please enter the OTP and your new password');
                    } else {
                      final success = await AuthHelper().resetPassword(context, email: email, otp: otp, newPassword: pass);
                      if (success && context.mounted) {
                        toast('Password reset successfully!');
                        Navigator.pop(context);
                      }
                    }
                  }
                  
                  setState(() => isLoading = false);
                },
                width: context.width(),
                child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text(otpSent ? 'Save New Password' : 'Send OTP Code', style: boldTextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return AppTextField(
      controller: emailCont,
      textFieldType: TextFieldType.EMAIL,
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your registered email',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
        border: OutlineInputBorder(borderRadius: radius(16), borderSide: BorderSide.none),
        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6A8A53)),
      ),
    );
  }

  Widget _buildOtpForm() {
    return Column(
      children: [
        AppTextField(
          controller: emailCont,
          textFieldType: TextFieldType.EMAIL,
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Email',
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.2),
            border: OutlineInputBorder(borderRadius: radius(16), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
          ),
        ),
        16.height,
        AppTextField(
          controller: otpCont,
          textFieldType: TextFieldType.PHONE,
          decoration: InputDecoration(
            labelText: 'OTP Code',
            hintText: 'Enter 4-digit OTP',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.8),
            border: OutlineInputBorder(borderRadius: radius(16), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF6A8A53)),
          ),
        ),
        16.height,
        AppTextField(
          controller: newPassCont,
          textFieldType: TextFieldType.PASSWORD,
          decoration: InputDecoration(
            labelText: 'New Password',
            hintText: 'Enter your new password',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.8),
            border: OutlineInputBorder(borderRadius: radius(16), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6A8A53)),
          ),
        ),
      ],
    );
  }
}
