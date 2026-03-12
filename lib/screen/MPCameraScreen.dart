import 'package:flutter/material.dart';

class MPCameraScreen extends StatefulWidget {
  const MPCameraScreen({super.key});

  @override
  State<MPCameraScreen> createState() => _MPCameraScreenState();
}

class _MPCameraScreenState extends State<MPCameraScreen> {
  // Dalam real-world app, di sini inisialisasi CameraController
  // Untuk mockup ini, kita tampilkan UI untuk simulasi deteksi emosi

  bool _isDetecting = false;
  
  @override
  Widget build(BuildContext context) {
    const Color bgTop = Color(0xFFDCE7CD);
    const Color bgMid = Color(0xFF6A8A53);
    const Color bgBottom = Color(0xFF1A2A14);
    const Color accentGold = Color(0xFFD8A854);
    const Color textDark = Color(0xFF293B1F);

    return Scaffold(
      backgroundColor: bgBottom,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgTop, bgMid, bgBottom],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: textDark),
                        ),
                      ),
                      const Text(
                        "Kenali Mood Anda",
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 40), // Balance the close button
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Camera View Finder Placeholder
                Center(
                  child: Container(
                    width: 300,
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: accentGold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: accentGold.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Simulating face outline
                        CustomPaint(
                          size: const Size(200, 250),
                          painter: FaceOutlinePainter(color: Colors.white.withOpacity(0.5)),
                        ),
                        
                        if (_isDetecting)
                          const CircularProgressIndicator(color: accentGold)
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.face_retouching_natural, size: 80, color: Colors.white.withOpacity(0.7)),
                              const SizedBox(height: 16),
                              Text(
                                "Posisikan wajah Anda\ndi dalam bingkai",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                              ),
                            ],
                          ),
                          
                        // Scanning animation effect overlay
                        if (_isDetecting)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: AnimatedContainer(
                              duration: const Duration(seconds: 2),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    accentGold.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Informational Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    "Aplikasi akan mendeteksi emosi Anda untuk memberikan rekomendasi musik yang tepat.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Capture Button
                GestureDetector(
                  onTap: () {
                    if (!_isDetecting) {
                      setState(() {
                        _isDetecting = true;
                      });
                      
                      // Simulate scanning delay and then show result
                      Future.delayed(const Duration(seconds: 3), () {
                        if (mounted) {
                          setState(() {
                            _isDetecting = false;
                          });
                          _showResultDialog();
                        }
                      });
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: _isDetecting ? const Icon(Icons.stop, color: textDark, size: 30) : null,
                      ),
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

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF293B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Hasil Deteksi",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied, size: 60, color: Color(0xFFD8A854)),
            const SizedBox(height: 16),
            const Text(
              "Anda terlihat sedang galau/sedih.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Kami akan menyiapkan playlist yang cocok untuk Anda.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD8A854),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to dashboard
              },
              child: const Text("Lihat Rekomendasi", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Face Outline
class FaceOutlinePainter extends CustomPainter {
  final Color color;
  
  FaceOutlinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
      
    // Draw an oval representing an abstract face
    var path = Path();
    path.addOval(Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height,
    ));
    
    // Draw crosshairs to help positioning
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.2), 
      Offset(size.width / 2, size.height * 0.3), 
      paint
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.7), 
      Offset(size.width / 2, size.height * 0.8), 
      paint
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height / 2), 
      Offset(size.width * 0.3, size.height / 2), 
      paint
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height / 2), 
      Offset(size.width * 0.8, size.height / 2), 
      paint
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
