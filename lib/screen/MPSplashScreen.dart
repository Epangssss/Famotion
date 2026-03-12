import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:just_audio/just_audio.dart';
import 'MPLoginScreen.dart';

class MPSplashScreen extends StatefulWidget {
  const MPSplashScreen({Key? key}) : super(key: key);

  @override
  _MPSplashScreenState createState() => _MPSplashScreenState();
}

class _MPSplashScreenState extends State<MPSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  int _currentEmotionIndex = 0;
  final List<IconData> _emotions = [
    Icons.favorite,                   // Love/Happy
    Icons.sentiment_dissatisfied, // Sad (to show we handle all moods)
    Icons.sentiment_satisfied_alt,    // Satisfied/Calm
    Icons.sentiment_very_satisfied,   // Very happy
    Icons.music_note,                 // Music
    Icons.eco,                        // Nature/Relaxed
  ];
  
  Timer? _emotionTimer;

  @override
  void initState() {
    super.initState();
    
    // Setup animation (Heartbeat effect)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Setup Emotion Switcher Timer
    _emotionTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (mounted) {
        setState(() {
          _currentEmotionIndex = (_currentEmotionIndex + 1) % _emotions.length;
        });
      }
    });

    _playSplashMusic();
    _navigateToNext();
  }

  Future<void> _playSplashMusic() async {
    try {
      // Memutar suara chime singkat dari URL stabil saat splash screen dimulai. 
      // Atau efek ambient relaksasi. 
      await _audioPlayer.setUrl('https://cdn.pixabay.com/download/audio/2022/10/25/audio_145d2e3d36.mp3?filename=success-chime-104928.mp3');
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Could not play splash audio: $e");
    }
  }

  Future<void> _navigateToNext() async {
    // Wait for splash duration 5 detik agar animasi dan lagu terasa.
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    
    // Stop audio before navigating just in case
    await _audioPlayer.stop();
    MPLoginScreen().launch(context, isNewTask: true, pageRouteAnimation: PageRouteAnimation.Fade);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emotionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF132A20), // Dark green background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon Container
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDCE7CD),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD8A854).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation, 
                      child: ScaleTransition(scale: animation, child: child)
                    );
                  },
                  child: Icon(
                    _emotions[_currentEmotionIndex],
                    key: ValueKey<int>(_currentEmotionIndex),
                    color: const Color(0xFFD8A854), // Accent Gold
                    size: 80,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 60), 
            
            Text(
              'Famotion',
              style: boldTextStyle(
                color: Colors.white,
                size: 36,
                letterSpacing: 2.0,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'Music Therapy Recommendation',
              style: secondaryTextStyle(
                color: Colors.white.withOpacity(0.8),
                size: 14,
                letterSpacing: 0.5,
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Loading indicator
            const CircularProgressIndicator(
              color: Color(0xFFD8A854),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
