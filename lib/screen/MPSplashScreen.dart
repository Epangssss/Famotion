import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:just_audio/just_audio.dart';
import 'MPLoginScreen.dart';

class MPSplashScreen extends StatefulWidget {
  const MPSplashScreen({Key? key}) : super(key: key);

  @override
  _MPSplashScreenState createState() => _MPSplashScreenState();
}

class _MPSplashScreenState extends State<MPSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _currentEmotionIndex = 0;
  final List<IconData> _emotions = [
    Icons.favorite, // Love/Happy
    Icons.sentiment_dissatisfied, // Sad (to show we handle all moods)
    Icons.sentiment_satisfied_alt, // Satisfied/Calm
    Icons.sentiment_very_satisfied, // Very happy
    Icons.music_note, // Music
    Icons.eco, // Nature/Relaxed
  ];

  Timer? _emotionTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

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
      await _audioPlayer.setUrl(
          'https://cdn.pixabay.com/download/audio/2022/10/25/audio_145d2e3d36.mp3?filename=success-chime-104928.mp3');
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
    MPLoginScreen().launch(context,
        isNewTask: true, pageRouteAnimation: PageRouteAnimation.Fade);
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
      backgroundColor: const Color(0xFF132A20),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center:
                      Alignment(0, -0.2), // Adjusted higher where the face is
                  radius: 1.0,
                  colors: [
                    Color(0xFF224231), // Lighter green at center
                    Color(0xFF0F1F17), // Very dark edges
                  ],
                ),
              ),
            ),
          ),

          // Bottom Glow Effect
          Positioned(
            bottom: -150,
            left: -50,
            right: -50,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD8A854).withOpacity(0.12),
                    blurRadius: 100,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),

          // Background Painter for Staff lines only
          Positioned.fill(
            child: CustomPaint(
              painter: _MusicStaffPainter(),
            ),
          ),

          // Decorative Icons layer
          _buildFloatingIcon(
              top: 80,
              left: 40,
              angle: -0.2,
              icon: Icons.music_note,
              size: 30,
              opacity: 0.4),
          _buildFloatingIcon(
              top: 60,
              right: 50,
              angle: 0.1,
              icon: Icons.music_note,
              size: 24,
              opacity: 0.3),
          _buildFloatingIcon(
              top: 400,
              right: 30,
              angle: -0.15,
              icon: Icons.music_note,
              size: 36,
              opacity: 0.5),
          _buildFloatingIcon(
              top: 600,
              left: 40,
              angle: 0.1,
              icon: Icons.music_note,
              size: 28,
              opacity: 0.3), // Fallback in case paths are complex

          // Custom Path Icons from Image
          Positioned(
            bottom: 120,
            left: 50,
            child: Transform.rotate(
              angle: -0.1,
              child: SizedBox(
                width: 30,
                height: 80,
                child: CustomPaint(painter: _TuningForkPainter()),
              ),
            ),
          ),

          Positioned(
            bottom: 100,
            right: 50,
            child: Transform.rotate(
              angle: 0.1,
              child: SizedBox(
                width: 60,
                height: 70,
                child: CustomPaint(painter: _LyrePainter()),
              ),
            ),
          ),



          // Center Foreground Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 0),

                // Central Face with Echo Rings
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final t = _animationController.value;
                    final pulse = 1.0 + 0.03 * math.sin(t * 2 * math.pi);
                    return SizedBox(
                      width: 140,
                      height: 140,
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Echo rings radiating outward from icon
                            ...List.generate(5, (i) {
                              final phase = (t + i / 5.0) % 1.0;
                              final ringRadius = 70.0 + phase * 140.0;
                              final ringOpacity = (1.0 - phase) * 0.40;
                              return SizedBox(
                                width: ringRadius * 2,
                                height: ringRadius * 2,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFDCE7CD).withOpacity(ringOpacity),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // Icon circle itself
                            Transform.scale(
                              scale: pulse,
                              child: child,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE5F1DB), // Soft greenish white
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE5F1DB).withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: const Color(0xFFD8A854).withOpacity(0.25),
                          blurRadius: 80,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                  scale: animation, child: child));
                        },
                        child: Icon(
                          _emotions[_currentEmotionIndex],
                          key: ValueKey<int>(_currentEmotionIndex),
                          color: const Color(0xFFDCA95C), // Gold
                          size: 90,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 70), // Same space based on image

                Text(
                  'Famotion',
                  style: boldTextStyle(
                    color: Colors.white,
                    size: 40,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Music Face Mood Recommendation',
                  style: secondaryTextStyle(
                    color: Colors.white.withOpacity(0.65),
                    size: 16,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 80),

                // Loading C arc
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CustomPaint(
                      painter: _ArcLoadingPainter(),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIcon({
    required double top,
    double? left,
    double? right,
    required double angle,
    required IconData icon,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Icon(
          icon,
          color: const Color(0xFFDCE7CD).withOpacity(opacity),
          size: size,
        ),
      ),
    );
  }
}


// Music Staff Background (static)
class _MusicStaffPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFDCE7CD).withOpacity(0.12)
      ..strokeWidth = 1.5;

    final Offset targetCenter = Offset(size.width / 2, size.height / 2 - 110);

    for (int i = 0; i < 5; i++) {
      final path = Path();
      path.moveTo(size.width, size.height * 0.15 + (i * 15));
      path.quadraticBezierTo(
        size.width * 0.7,
        targetCenter.dy - 60 + (i * 15),
        -50,
        size.height * 0.45 + (i * 15),
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Tuning Fork
class _TuningForkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCE7CD).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Handle
    path.moveTo(size.width / 2, size.height);
    path.lineTo(size.width / 2, size.height * 0.4);

    // Bottom ball
    canvas.drawCircle(Offset(size.width / 2, size.height), 3.5,
        Paint()..color = const Color(0xFFDCE7CD).withOpacity(0.3));

    // U-shape forks
    path.moveTo(size.width * 0.2, 0);
    path.lineTo(size.width * 0.2, size.height * 0.2);
    path.quadraticBezierTo(
        size.width * 0.2, size.height * 0.4, size.width / 2, size.height * 0.4);

    path.moveTo(size.width * 0.8, 0);
    path.lineTo(size.width * 0.8, size.height * 0.2);
    path.quadraticBezierTo(
        size.width * 0.8, size.height * 0.4, size.width / 2, size.height * 0.4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Lyre
class _LyrePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCE7CD).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    // Base block
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.quadraticBezierTo(
        size.width * 0.5, size.height, size.width * 0.8, size.height * 0.8);

    // Left arm
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.quadraticBezierTo(
        0, size.height * 0.5, size.width * 0.15, size.height * 0.1);
    path.quadraticBezierTo(
        size.width * 0.25, 0, size.width * 0.3, size.height * 0.1);

    // Right arm
    path.moveTo(size.width * 0.8, size.height * 0.8);
    path.quadraticBezierTo(
        size.width, size.height * 0.5, size.width * 0.85, size.height * 0.1);
    path.quadraticBezierTo(
        size.width * 0.75, 0, size.width * 0.7, size.height * 0.1);

    // Crossbar
    path.moveTo(size.width * 0.18, size.height * 0.35);
    path.lineTo(size.width * 0.82, size.height * 0.35);

    canvas.drawPath(path, paint);

    // Strings
    final stringPaint = Paint()
      ..color = const Color(0xFFDCE7CD).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = -1; i <= 1; i++) {
      double x = size.width * 0.5 + (i * size.width * 0.15);
      canvas.drawLine(Offset(x, size.height * 0.35),
          Offset(x, size.height * 0.85), stringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Arc Loading
class _ArcLoadingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCA95C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      math.pi * -0.4, // Start angle
      math.pi * 1.6, // Sweep angle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
