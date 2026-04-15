import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../utils/auth_helper.dart';

class MPCameraScreen extends StatefulWidget {
  const MPCameraScreen({super.key});

  @override
  State<MPCameraScreen> createState() => _MPCameraScreenState();
}

class _MPCameraScreenState extends State<MPCameraScreen> {
  CameraController? _controller;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kamera tidak tersedia')),
          );
        }
        return;
      }

      // Pilih kamera depan (selfie) untuk deteksi wajah
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras[0],
      );

      _controller = CameraController(frontCamera, ResolutionPreset.medium);
      await _controller!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inisialisasi kamera: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> sendToModel(String path) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("http://$vpsIp:5000/predict"), // Memakai IP VPS dari settingan auth_helper
      );

      request.files.add(await http.MultipartFile.fromPath('file', path));

      var response = await request.send();
      var res = await http.Response.fromStream(response);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        return {"error": "Server error: ${res.statusCode}"};
      }
    } catch (e) {
      return {"error": "Connection error: $e"};
    }
  }

  Future<void> captureAndPredict() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isDetecting = true);

    try {
      final image = await _controller!.takePicture();
      var result = await sendToModel(image.path);

      if (mounted) {
        setState(() => _isDetecting = false);

        if (result.containsKey("error")) {
          _showErrorDialog(result["error"] ?? "Wajah tidak terdeteksi");
          return;
        }

        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetecting = false);
        _showErrorDialog("Error: $e");
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
          // Background or Camera Preview
          _controller != null && _controller!.value.isInitialized
              ? CameraPreview(_controller!)
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bgTop, bgMid, bgBottom],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: const Center(
                      child: CircularProgressIndicator(color: accentGold)),
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
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(),

                // Info Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    "Arahkan wajah Anda ke kamera untuk deteksi emosi",
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
                  onTap: _isDetecting ? null : captureAndPredict,
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
                        child: _isDetecting
                            ? const CircularProgressIndicator(color: textDark)
                            : const Icon(Icons.camera,
                                color: textDark, size: 30),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF293B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Oops!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD8A854),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Coba Lagi",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(Map<String, dynamic> result) {
    // Find dominant emotion
    String dominant = "Unknown";
    double maxValue = 0;

    result.forEach((key, value) {
      if (value is num && value > maxValue) {
        maxValue = value.toDouble();
        dominant = key;
      }
    });

    // Build emotion display text
    AuthHelper().saveEmotionStatus(dominant, maxValue);
    String emotionText = result.entries
        .where((e) => e.value is num)
        .map((e) => "${e.key}: ${(e.value as num).toStringAsFixed(1)}%")
        .join("\n");

    // Genre dikendalikan di layar Dashboard, jadi hapus logika Dropdown di sini

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
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
                  const Icon(Icons.sentiment_satisfied,
                      size: 50, color: Color(0xFFD8A854)),
                  const SizedBox(height: 12),
                  Text(
                    "Emosi Dominan: $dominant",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emotionText,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                  // Dihapus: Pemilihan Genre dipindah sepenuhnya di Layar Utama (Dashboard).
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD8A854),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Tutup Dialognya
                      Navigator.pop(context, dominant); // Kembalikan MOOD ke Dashboard (contoh: "happy")
                    },
                    child: const Text("Mainkan Musik",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
