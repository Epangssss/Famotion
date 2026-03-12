import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'MPDashboardScreen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCE7CD), // Top background from main UI
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Back!', style: boldTextStyle(size: 32, color: const Color(0xFF1A2A14))),
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
                  prefixIcon: const Icon(Icons.email_outlined),
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
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              16.height,
              Align(
                alignment: Alignment.centerRight,
                child: Text('Forgot Password?', style: boldTextStyle(color: const Color(0xFF6A8A53), size: 14)).onTap(() {
                  toast('Forgot Password Clicked');
                }),
              ),
              32.height,
              AppButton(
                text: 'Sign In',
                color: const Color(0xFFD8A854), // Accent Gold
                textColor: Colors.white,
                shapeBorder: RoundedRectangleBorder(borderRadius: radius(16)),
                onTap: () {
                   DashboardPage().launch(context, isNewTask: true);
                },
                width: context.width(),
              ),
              24.height,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: secondaryTextStyle()),
                  Text('Sign Up', style: boldTextStyle(color: const Color(0xFF6A8A53))).onTap(() {
                    toast('Sign Up Clicked');
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
