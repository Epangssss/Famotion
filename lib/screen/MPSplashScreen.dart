import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'MPLoginScreen.dart';

class MPSplashScreen extends StatefulWidget {
  const MPSplashScreen({Key? key}) : super(key: key);

  @override
  _MPSplashScreenState createState() => _MPSplashScreenState();
}

class _MPSplashScreenState extends State<MPSplashScreen> {
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    MPLoginScreen().launch(context, isNewTask: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF132A20),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDCE7CD),
              ),
              child: const Icon(Icons.favorite, color: Color(0xFFD8A854), size: 80),
            ),
            24.height,
            Text('Famotion', style: boldTextStyle(color: Colors.white, size: 32)),
            8.height,
            Text('Music Therapy Recommendation', style: secondaryTextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
