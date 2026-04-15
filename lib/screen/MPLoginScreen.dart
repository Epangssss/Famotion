import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../utils/auth_helper.dart';
import 'MPSignUpScreen.dart';
class MPLoginScreen extends StatefulWidget {
  const MPLoginScreen({Key? key}) : super(key: key);

  @override
  _MPLoginScreenState createState() => _MPLoginScreenState();
}

class _MPLoginScreenState extends State<MPLoginScreen> {
  var emailController = TextEditingController();
  var passwordController = TextEditingController();

  var emailFocusNode = FocusNode();
  var passwordFocusNode = FocusNode();

  void _navigateToSignUp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MPSignUpScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          final offset = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved);
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: offset, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCE7CD),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome, Famotions!', style: boldTextStyle(size: 32, color: const Color(0xFF1A2A14))),
              8.height,
              Text('Sign in to continue discovering music that fits your mood.', style: secondaryTextStyle(size: 14)),
              32.height,
              AppTextField(
                controller: emailController,
                focus: emailFocusNode,
                nextFocus: passwordFocusNode,
                textFieldType: TextFieldType.EMAIL,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(borderRadius: radius(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6A8A53)),
                ),
              ),
              16.height,
              AppTextField(
                controller: passwordController,
                focus: passwordFocusNode,
                textFieldType: TextFieldType.PASSWORD,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: OutlineInputBorder(borderRadius: radius(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6A8A53)),
                ),
              ),
              8.height,
              Align(
                alignment: Alignment.centerRight,
                child: Text('Forgot Password?', style: boldTextStyle(color: const Color(0xFF6A8A53), size: 14)).onTap(() {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      final resetEmailCont = TextEditingController(text: emailController.text);
                      final otpCont = TextEditingController();
                      final newPassCont = TextEditingController();
                      bool otpSent = false;
                      bool isLoading = false;
                      
                      return StatefulBuilder(
                        builder: (context, setStateDialog) {
                          return AlertDialog(
                            title: Text(otpSent ? 'Masukkan OTP & Sandi' : 'Reset Password'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: resetEmailCont,
                                  decoration: const InputDecoration(labelText: 'Email Terdaftar'),
                                  enabled: !otpSent,
                                ),
                                if (otpSent) ...[
                                  TextFormField(
                                    controller: otpCont,
                                    decoration: const InputDecoration(labelText: 'Kode OTP 4-Digit'),
                                    keyboardType: TextInputType.number,
                                  ),
                                  TextFormField(
                                    controller: newPassCont,
                                    decoration: const InputDecoration(labelText: 'Sandi Baru'),
                                    obscureText: true,
                                  ),
                                ]
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: isLoading ? null : () async {
                                  setStateDialog(() => isLoading = true);
                                  
                                  if (!otpSent) {
                                    final email = resetEmailCont.text.trim();
                                    if (email.isEmpty) {
                                      toast('Harap isi Email');
                                    } else {
                                      final success = await AuthHelper().requestPasswordReset(context, email: email);
                                      if (success) {
                                        setStateDialog(() => otpSent = true);
                                      }
                                    }
                                  } else {
                                    final email = resetEmailCont.text.trim();
                                    final otp = otpCont.text.trim();
                                    final pass = newPassCont.text.trim();
                                    if (otp.isEmpty || pass.isEmpty) {
                                      toast('Isi OTP dan Sandi Baru');
                                    } else {
                                      final success = await AuthHelper().resetPassword(context, email: email, otp: otp, newPassword: pass);
                                      if (success && context.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    }
                                  }
                                  
                                  setStateDialog(() => isLoading = false);
                                },
                                child: isLoading 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                  : Text(otpSent ? 'Simpan' : 'Kirim OTP (Cek Terminal Node.js)'),
                              ),
                            ],
                          );
                        }
                      );
                    },
                  );
                }),
              ),
              24.height,

              // Divider "or"
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFADC18A), thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: secondaryTextStyle(size: 13, color: const Color(0xFF7A9462))),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFADC18A), thickness: 1)),
                ],
              ),
              16.height,

              // Google Sign In
              GestureDetector(
                onTap: () async {
                  toast('Sedang memproses Google Sign In...');
                  await AuthHelper().authWithGoogle(context, isSignUp: false);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/google_logo.png',
                        width: 24,
                        height: 24,
                      ),
                      12.width,
                      Text(
                        'Sign in with Google',
                        style: boldTextStyle(size: 15, color: const Color(0xFF1A2A14)),
                      ),
                    ],
                  ),
                ),
              ),
              20.height,

              AppButton(
                text: 'Sign In',
                color: const Color(0xFFD8A854),
                textColor: Colors.white,
                shapeBorder: RoundedRectangleBorder(borderRadius: radius(16)),
                onTap: () async {
                  if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
                    toast('Isi email dan password terlebih dahulu');
                    return;
                  }
                  await AuthHelper().loginWithEmail(
                    context,
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );
                },
                width: context.width(),
              ),
              24.height,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: secondaryTextStyle()),
                  GestureDetector(
                    onTap: _navigateToSignUp,
                    child: Text('Sign Up', style: boldTextStyle(color: const Color(0xFF6A8A53))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


