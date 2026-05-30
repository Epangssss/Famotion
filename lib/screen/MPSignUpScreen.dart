import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../utils/auth_helper.dart';

class MPSignUpScreen extends StatefulWidget {
  const MPSignUpScreen({super.key});

  @override
  _MPSignUpScreenState createState() => _MPSignUpScreenState();
}

class _MPSignUpScreenState extends State<MPSignUpScreen> with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final nameFocusNode = FocusNode();
  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();

  bool _isLoading = false;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameFocusNode.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      toast('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    
    await AuthHelper().registerWithEmail(
      context,
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dark green gradient background (different from Login)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E2118), // Very dark green
                    Color(0xFF183828), // Mid dark green
                    Color(0xFF1E4A34), // Slightly lighter
                    Color(0xFF0A1A0F), // Darkest bottom
                  ],
                  stops: [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // Animated soft circle blobs
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              final t = _bgController.value;
              return Stack(
                children: [
                  // Top-right warm glow blob
                  Positioned(
                    top: -80 + 20 * math.sin(t * 2 * math.pi),
                    right: -60,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFD8A854).withOpacity(0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom-left cool glow blob
                  Positioned(
                    bottom: 40 + 15 * math.cos(t * 2 * math.pi),
                    left: -80,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF4CAF7D).withOpacity(0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Mid subtle glow
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.4,
                    right: 20 + 10 * math.sin(t * math.pi),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6AB187).withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Subtle decorative music notes
          Positioned(top: 80, right: 30, child: _DecorativeNote(size: 22, opacity: 0.2, angle: 0.3)),
          Positioned(top: 200, left: 20, child: _DecorativeNote(size: 16, opacity: 0.15, angle: -0.2)),
          Positioned(bottom: 200, right: 40, child: _DecorativeNote(size: 18, opacity: 0.15, angle: 0.1)),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                  28.height,

                  // Heading
                  Text(
                    'Join Famotion',
                    style: boldTextStyle(size: 34, color: Colors.white),
                  ),
                  8.height,
                  Text(
                    'Create your account and discover music for every mood.',
                    style: secondaryTextStyle(size: 14, color: Colors.white.withOpacity(0.55)),
                  ),
                  32.height,

                  // Name Field
                  _buildField(
                    controller: nameController,
                    focus: nameFocusNode,
                    nextFocus: emailFocusNode,
                    type: TextFieldType.NAME,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                  ),
                  16.height,

                  // Email Field
                  _buildField(
                    controller: emailController,
                    focus: emailFocusNode,
                    nextFocus: passwordFocusNode,
                    type: TextFieldType.EMAIL,
                    label: 'Email',
                    hint: 'Enter your email',
                    icon: Icons.email_outlined,
                  ),
                  16.height,

                  // Password Field
                  _buildField(
                    controller: passwordController,
                    focus: passwordFocusNode,
                    type: TextFieldType.PASSWORD,
                    label: 'Password',
                    hint: 'Create a password',
                    icon: Icons.lock_outline_rounded,
                  ),
                  6.height,
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      'Must be at least 8 characters.',
                      style: secondaryTextStyle(size: 12, color: Colors.white.withOpacity(0.35)),
                    ),
                  ),
                  32.height,

                  // Sign Up button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8A854)))
                      : Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE6B86A), Color(0xFFD8A854), Color(0xFFC4923D)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD8A854).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: _handleSignUp,
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              'Sign Up',
                              style: boldTextStyle(size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                  20.height,

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: secondaryTextStyle(size: 13, color: Colors.white.withOpacity(0.4))),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 1)),
                    ],
                  ),
                  16.height,

                  // Google Sign Up
                  GestureDetector(
                    onTap: () async {
                      toast('Sedang memproses Google Sign Up...');
                      await AuthHelper().authWithGoogle(context, isSignUp: true);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
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
                            'Sign up with Google',
                            style: boldTextStyle(size: 15, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  28.height,

                  // Sign In link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: secondaryTextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Sign In',
                          style: boldTextStyle(color: const Color(0xFFD8A854)),
                        ),
                      ),
                    ],
                  ),
                  24.height,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focus,
    FocusNode? nextFocus,
    required TextFieldType type,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return AppTextField(
      controller: controller,
      focus: focus,
      nextFocus: nextFocus,
      textFieldType: type,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: radius(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius(16),
          borderSide: const BorderSide(color: Color(0xFFD8A854), width: 1.5),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFD8A854).withOpacity(0.8), size: 20),
      ),
      textStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
    );
  }
}

// Decorative music note widget
class _DecorativeNote extends StatelessWidget {
  final double size;
  final double opacity;
  final double angle;

  const _DecorativeNote({
    required this.size,
    required this.opacity,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.music_note_rounded,
        size: size,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

