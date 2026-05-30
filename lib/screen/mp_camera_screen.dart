import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:nb_utils/nb_utils.dart';
import '../utils/auth_helper.dart';

class MPCameraScreen extends StatefulWidget {
  const MPCameraScreen({super.key});

  @override
  State<MPCameraScreen> createState() => _MPCameraScreenState();
}

class _MPCameraScreenState extends State<MPCameraScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isDetecting = false;
  String? _capturedImagePath;

  late AnimationController _scanController;
  /// 'dark' | 'normal' | 'bright'
  String _lightStatus = 'normal';
  bool _isScanningFrame = false;

  // 5-detik countdown sebelum auto-capture
  int  _countdown       = 0;
  bool _isCountingDown  = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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

      _controller = CameraController(
        frontCamera, 
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      _controller!.startImageStream((image) => _checkBrightness(image));

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

  void _checkBrightness(CameraImage image) {
    if (_isScanningFrame) return;
    _isScanningFrame = true;

    try {
      if (image.planes.isEmpty) return;
      final bytes = image.planes[0].bytes;
      int totalLuminance = 0;
      int skip = bytes.length ~/ 1000;
      if (skip == 0) skip = 1;

      int samples = 0;
      for (int i = 0; i < bytes.length; i += skip) {
        totalLuminance += bytes[i];
        samples++;
      }

      final double avg = totalLuminance / samples;
      final String newStatus;
      if (avg < 40) {
        newStatus = 'dark';
      } else if (avg > 210) {
        newStatus = 'bright';
      } else {
        newStatus = 'normal';
      }

      if (newStatus != _lightStatus && mounted) {
        setState(() => _lightStatus = newStatus);
      }
    } catch (e) {
      // ignore
    } finally {
      _isScanningFrame = false;
    }
  }

  // Endpoint prediksi emosi — VIDEO
  // Primary: /predict_video (VPS app.py yang baru)
  // Fallback: /predict (legacy)
  static const List<String> _predictEndpoints = [
    '/predict_video',
  ];

  Future<Map<String, dynamic>> sendToModel(String path) async {
    const String baseUrl = 'http://192.168.0.106:5000';

    // Ambil userId dari local storage (disimpan saat login)
    final String userId = getStringAsync('userId');

    for (final endpoint in _predictEndpoints) {
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl$endpoint'),
        );

        // VPS butuh field 'file' untuk video
        request.files.add(await http.MultipartFile.fromPath('file', path));

        // VPS butuh userId sebagai form field
        if (userId.isNotEmpty) {
          request.fields['userId'] = userId;
        }

        debugPrint('📤 Mengirim ke $endpoint | userId=$userId');
        var response = await request.send().timeout(const Duration(seconds: 90));
        var res = await http.Response.fromStream(response);

        debugPrint('📥 ${res.statusCode} — ${res.body}');

        if (res.statusCode == 404) {
          debugPrint('⚠️ $endpoint → 404, skip.');
          continue;
        }

        if (res.statusCode == 200) {
          debugPrint('✅ Berhasil via $endpoint');
          return jsonDecode(res.body);
        }

        // 400 atau error lain — tampilkan pesan asli dari server
        try {
          final body = jsonDecode(res.body);
          return {'error': body['error'] ?? 'Server error ${res.statusCode}'};
        } catch (_) {
          return {'error': 'Server error ${res.statusCode}: ${res.body}'};
        }

      } catch (e) {
        debugPrint('❌ $endpoint error: $e');
        continue;
      }
    }
    return {'error': 'Tidak dapat terhubung ke server deteksi emosi.'};
  }

  // Mulai hitung mundur 5 detik + langsung mulai merekam video
  void _startCountdown() {
    if (_isCountingDown || _isDetecting) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_lightStatus != 'normal') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_lightStatus == 'dark'
            ? '⚠️ Pencahayaan gelap — hasil deteksi mungkin kurang akurat'
            : '⚠️ Pencahayaan terlalu terang — hindari cahaya langsung'),
        duration: const Duration(seconds: 2),
      ));
    }

    // Stop image stream dulu sebelum mulai record
    if (_controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }

    setState(() {
      _countdown      = 5;
      _isCountingDown = true;
    });

    // Mulai merekam video bersamaan dengan countdown
    _controller!.startVideoRecording().then((_) {
      debugPrint('📹 Video recording started');
    }).catchError((e) {
      debugPrint('❌ Gagal mulai recording: $e');
      if (mounted) setState(() => _isCountingDown = false);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        setState(() => _isCountingDown = false);
        _stopRecordingAndPredict(); // Stop record lalu kirim ke VPS
      }
    });
  }

  // Hentikan rekaman lalu kirim video ke VPS untuk analisis emosi
  Future<void> _stopRecordingAndPredict() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isDetecting = true);

    try {
      final video = await _controller!.stopVideoRecording();
      debugPrint('📹 Video saved: ${video.path}');

      // Jangan tampilkan preview video sebagai gambar — langsung analisis
      var result = await sendToModel(video.path);

      if (mounted) {
        setState(() => _isDetecting = false);
        if (result.containsKey('error')) {
          _showErrorDialog(result['error'] ?? 'Deteksi gagal');
          return;
        }
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetecting = false);
        _showErrorDialog('Error: $e');
      }
    }
  }

  // Legacy: masih dipakai jika diperlukan fallback foto
  Future<void> captureAndPredict() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isDetecting = true);

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      await Future.delayed(const Duration(milliseconds: 200));
      final image = await _controller!.takePicture();
      setState(() => _capturedImagePath = image.path);

      var result = await sendToModel(image.path);

      if (mounted) {
        setState(() => _isDetecting = false);
        if (result.containsKey('error')) {
          _showErrorDialog(result['error'] ?? 'Wajah tidak terdeteksi');
          return;
        }
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetecting = false);
        _showErrorDialog('Error: $e');
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
    }
    _scanController.dispose();
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
          _capturedImagePath != null
              ? SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.file(
                    File(_capturedImagePath!),
                    fit: BoxFit.cover,
                  ),
                )
              : _controller != null && _controller!.value.isInitialized
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        _buildFaceOverlay(),
                      ],
                    )
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
                            color: Colors.white.withValues(alpha: 0.3),
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
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Capture Button
                GestureDetector(
                  onTap: (_isDetecting || _isCountingDown) ? null : _startCountdown,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
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
                        child: const Icon(Icons.camera, color: textDark, size: 30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Countdown Overlay — kamera tetap terlihat, hanya overlay tipis di atas
          if (_isCountingDown)
            Positioned.fill(
              child: Stack(
                children: [
                  // REC indicator kiri atas
                  Positioned(
                    top: 100,
                    left: 24,
                    child: Row(
                      children: [
                        _PulsingDot(),
                        const SizedBox(width: 6),
                        const Text(
                          'REC',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Countdown number di tengah layar (atas oval)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Lingkaran progress transparan
                              TweenAnimationBuilder<double>(
                                key: ValueKey(_countdown),
                                tween: Tween(begin: 1.0, end: 0.0),
                                duration: const Duration(milliseconds: 980),
                                builder: (_, v, __) => CircularProgressIndicator(
                                  value: v,
                                  strokeWidth: 7,
                                  color: accentGold,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                              // Lingkaran latar belakang semi-transparan
                              Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.45),
                                ),
                              ),
                              Text(
                                '$_countdown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Pastikan wajah Anda terlihat jelas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Layar Analisis (full-screen, proper design, bukan "bocor") ──
          if (_isDetecting)
            AnimatedOpacity(
              opacity: _isDetecting ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1A2A14),
                      Color(0xFF253B1D),
                      Color(0xFF1A2A14),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulsing rings + face icon
                      _AnalyzingRings(color: accentGold),

                      const SizedBox(height: 40),

                      // Judul
                      const Text(
                        'Menganalisis Emosi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Famotion sedang membaca ekspresi wajah Anda...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Step indicators
                      _buildAnalysisStep(Icons.videocam_rounded,       'Rekaman selesai',      true,  accentGold),
                      const SizedBox(height: 14),
                      _buildAnalysisStep(Icons.cloud_upload_outlined,  'Mengirim ke server',   true,  accentGold),
                      const SizedBox(height: 14),
                      _buildAnalysisStep(Icons.psychology_outlined,    'Mendeteksi emosi...',  false, accentGold),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step indicator untuk layar analisis ──
  Widget _buildAnalysisStep(IconData icon, String label, bool done, Color gold) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: done ? gold : Colors.white24,
              width: 1.5,
            ),
          ),
          child: done
              ? Icon(icon, color: gold, size: 18)
              : SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: gold.withValues(alpha: 0.7),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: done ? Colors.white : Colors.white54,
            fontSize: 14,
            fontWeight: done ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
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
              onPressed: () {
                setState(() => _capturedImagePath = null);
                Navigator.pop(context);
                if (_controller != null && !_controller!.value.isStreamingImages) {
                  _controller!.startImageStream((image) => _checkBrightness(image));
                }
              },
              child: const Text("Coba Lagi",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(Map<String, dynamic> result) {
    // Log respon asli VPS agar bisa didiagnosis
    debugPrint('🎯 Raw VPS response: $result');

    // VPS bisa pakai key berbeda untuk nama emosi dominan
    String dominant = (
      result['prediction'] ??
      result['emotion'] ??
      result['label'] ??
      result['dominant'] ??
      'Unknown'
    ).toString();
    if (dominant == 'Unknown' && result.isNotEmpty) dominant = result.keys.first;

    // VPS mengembalikan 'scores' (Map) dan 'confidence' (float)
    // Prioritaskan 'scores' karena berisi semua emosi
    Map<String, dynamic> confidence = {};
    for (final key in ['scores', 'confidence_map', 'emotion_scores', 'probabilities']) {
      if (result[key] != null && result[key] is Map) {
        var scoreMap = result[key] as Map;
        if (scoreMap.containsKey('vote_percentage') && scoreMap['vote_percentage'] is Map) {
          confidence = Map<String, dynamic>.from(scoreMap['vote_percentage']);
        } else {
          confidence = Map<String, dynamic>.from(scoreMap);
        }
        debugPrint('📊 Score map dari key "$key": $confidence');
        break;
      }
    }

    // Normalisasi: jika SEMUA skor dalam range 0–1 (float), konversi ke 0–100
    if (confidence.isNotEmpty) {
      final allBelow1 = confidence.values.every((v) => (v as num).toDouble() <= 1.0);
      if (allBelow1) {
        // Semua nilai <= 1.0 → range 0–1, kalikan 100
        confidence = confidence.map((k, v) => MapEntry(k, (v as num).toDouble() * 100));
        debugPrint('📊 Dikonversi ke persen (×100): $confidence');
      }
    }

    // Cari maxVal dari map
    double maxVal = 0.0;
    confidence.forEach((k, v) {
      final val = (v as num).toDouble();
      if (val > maxVal) maxVal = val;
    });

    // Fallback: jika map kosong, pakai 'confidence' float dari VPS
    if (confidence.isEmpty && dominant != 'Unknown') {
      final confFloat = (result['confidence'] as num?)?.toDouble() ?? 100.0;
      confidence = {dominant: confFloat};
      maxVal = confFloat;
      debugPrint('⚠️ Map kosong — fallback confidence float: $dominant = $maxVal%');
    }

    List<String> topEmotions = [];
    confidence.forEach((k, v) {
      if ((maxVal - (v as num).toDouble()).abs() < 0.001) topEmotions.add(k);
    });
    if (topEmotions.isEmpty) topEmotions.add(dominant);

    AuthHelper().saveEmotionStatus(topEmotions.first, maxVal);

    // Urutkan dari terbesar ke terkecil
    final sorted = confidence.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _EmotionResultSheet(
        dominant: topEmotions.first,
        topEmotions: topEmotions,
        sortedEmotions: sorted,
        maxVal: maxVal,
        onPlay: () {
          Navigator.pop(context); // tutup sheet
          Navigator.pop(context, topEmotions.first); // kembalikan mood ke Dashboard
        },
        onRetry: () {
          Navigator.pop(context);
          setState(() => _capturedImagePath = null);
          if (_controller != null && !_controller!.value.isStreamingImages) {
            _controller!.startImageStream(_checkBrightness);
          }
        },
      ),
    );
  }



  Widget _buildFaceOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        
        final double ovalWidth = width * 0.7;
        final double ovalHeight = ovalWidth * 1.35;
        final double startY = height * 0.35 - ovalHeight / 2;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: FaceOverlayPainter(_lightStatus),
              size: Size(width, height),
            ),
            
            // Animated Scanning Line
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Positioned(
                  top: startY + (_scanController.value * ovalHeight),
                  left: (width - ovalWidth) / 2,
                  width: ovalWidth,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8A854),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFD8A854).withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Light status badge - di bawah oval
            Positioned(
              top: startY + ovalHeight + 16,
              left: 0,
              right: 0,
              child: Center(child: _buildLightBadge()),
            ),

            // Instruction text
            Positioned(
              top: startY + ovalHeight + 66,
              left: 20,
              right: 20,
              child: Text(
                _lightStatus == 'dark'
                    ? 'Posisikan wajah\ntepat di dalam garis oval'
                    : _lightStatus == 'bright'
                        ? 'Posisikan wajah\ntepat di dalam garis oval'
                        : 'Posisikan wajah\ntepat di dalam garis oval',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 8)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLightBadge() {
    final IconData icon;
    final String label;
    final Color color;

    switch (_lightStatus) {
      case 'dark':
        icon = Icons.nightlight_round;
        label = 'Terlalu Gelap';
        color = Colors.redAccent;
        break;
      case 'bright':
        icon = Icons.wb_sunny;
        label = 'Terlalu Terang';
        color = Colors.orangeAccent;
        break;
      default:
        icon = Icons.wb_sunny_outlined;
        label = 'Pencahayaan Baik ✓';
        color = const Color(0xFF8BC34A);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  /// 'dark' | 'normal' | 'bright'
  final String lightStatus;
  FaceOverlayPainter(this.lightStatus);

  @override
  void paint(Canvas canvas, Size size) {
    final double ovalWidth  = size.width * 0.7;
    final double ovalHeight = ovalWidth * 1.35;
    final Rect ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.35),
      width:  ovalWidth,
      height: ovalHeight,
    );

    // Dark overlay with oval hole
    final Path ovalPath = Path()..addOval(ovalRect);
    final Path bgPath   = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path overlay  = Path.combine(PathOperation.difference, bgPath, ovalPath);
    canvas.drawPath(overlay, Paint()..color = Colors.black.withValues(alpha: 0.65));

    // Oval border color by light status
    final Color borderColor = lightStatus == 'dark'
        ? Colors.redAccent
        : lightStatus == 'bright'
            ? Colors.orangeAccent
            : const Color(0xFFD8A854);

    final Paint borderPaint = Paint()
      ..color       = borderColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(ovalRect, borderPaint);

    // 4 arc segments di posisi diagonal oval (bukan sudut kotak)
    // Ini mengikuti lengkungan oval — pattern kamera face-detection
    final Paint arcPaint = Paint()
      ..color       = borderColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap   = StrokeCap.round;

    const double arcSpan = pi / 5.5; // panjang tiap arc (~33°)
    const double half    = arcSpan / 2;

    // NW — kiri atas
    canvas.drawArc(ovalRect, -3 * pi / 4 - half, arcSpan, false, arcPaint);
    // NE — kanan atas
    canvas.drawArc(ovalRect,     -pi / 4 - half, arcSpan, false, arcPaint);
    // SE — kanan bawah
    canvas.drawArc(ovalRect,      pi / 4 - half, arcSpan, false, arcPaint);
    // SW — kiri bawah
    canvas.drawArc(ovalRect,  3 * pi / 4 - half, arcSpan, false, arcPaint);
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) => lightStatus != oldDelegate.lightStatus;
}

/// Titik merah yang berkedip — indikator REC saat countdown berjalan
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Animasi lingkaran berdenyut di layar analisis emosi
class _AnalyzingRings extends StatefulWidget {
  final Color color;
  const _AnalyzingRings({required this.color});
  @override
  State<_AnalyzingRings> createState() => _AnalyzingRingsState();
}

class _AnalyzingRingsState extends State<_AnalyzingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final s = _pulse.value;
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ring terluar
              Transform.scale(
                scale: s,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.15),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Ring tengah
              Transform.scale(
                scale: 2 - s,
                child: Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.30),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Ring dalam
              Transform.scale(
                scale: s,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.08),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.55),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              // Icon wajah di tengah
              Icon(
                Icons.face_retouching_natural,
                size: 52,
                color: widget.color,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════
// EMOTION RESULT BOTTOM SHEET — Bar chart animasi emosi
// ══════════════════════════════════════════════════════
class _EmotionResultSheet extends StatefulWidget {
  final String dominant;
  final List<String> topEmotions;
  final List<MapEntry<String, dynamic>> sortedEmotions;
  final double maxVal;
  final VoidCallback onPlay;
  final VoidCallback onRetry;

  const _EmotionResultSheet({
    required this.dominant,
    required this.topEmotions,
    required this.sortedEmotions,
    required this.maxVal,
    required this.onPlay,
    required this.onRetry,
  });

  @override
  State<_EmotionResultSheet> createState() => _EmotionResultSheetState();
}

class _EmotionResultSheetState extends State<_EmotionResultSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  // Emoji & warna per emosi
  static const Map<String, String> _emoji = {
    'happy':    '😄',
    'sad':      '😢',
    'angry':    '😠',
 
  };

  static const Map<String, Color> _barColor = {
    'happy':    Color(0xFFD8A854),
    'sad':      Color(0xFF5B8DEF),
    'angry':    Color(0xFFEF5B5B),
  };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    // Mulai animasi setelah sheet selesai mount
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _dominantEmoji =>
      _emoji[widget.dominant.toLowerCase()] ?? '🎭';

  Color _colorFor(String emo) =>
      _barColor[emo.toLowerCase()] ?? const Color(0xFFD8A854);

  @override
  Widget build(BuildContext context) {
    const bg      = Color(0xFF1A2A14);
    const bgCard  = Color(0xFF253B1D);
    const gold    = Color(0xFFD8A854);

    return Container(
      decoration: const BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Emoji + dominant emotion
          Text(_dominantEmoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(
            widget.dominant.toUpperCase(),
            style: const TextStyle(
              color: gold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Emosi Dominan Terdeteksi',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),

          const SizedBox(height: 28),

          // ── Bar Chart ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ANALISIS EMOSI',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                ...widget.sortedEmotions.map((entry) {
                  final name  = entry.key;
                  final pct   = (entry.value as num).toDouble();
                  // Ratio relatif terhadap emosi dominan agar bar selalu proporsional
                  final ratio = widget.maxVal > 0 ? pct / widget.maxVal : 0.0;
                  final color = _colorFor(name);
                  final emo   = _emoji[name.toLowerCase()] ?? '🎭';
                  final isDom = (widget.maxVal - pct).abs() < 0.001;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(emo, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              name[0].toUpperCase() + name.substring(1),
                              style: TextStyle(
                                color: isDom ? Colors.white : Colors.white60,
                                fontWeight: isDom ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            AnimatedBuilder(
                              animation: _anim,
                              builder: (_, __) => Text(
                                '${(pct * _anim.value).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Bar track
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 10,
                            color: Colors.white.withValues(alpha: 0.07),
                            child: AnimatedBuilder(
                              animation: _anim,
                              builder: (_, __) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: ratio * _anim.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: color,
                                    boxShadow: isDom
                                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tombol aksi
          if (widget.topEmotions.length > 1) ...[
            const Text(
              'Persentase sama — pilih mood:',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: widget.topEmotions.map((emo) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, emo);
                },
                child: Text(emo.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )).toList(),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: widget.onPlay,
                icon: const Icon(Icons.music_note_rounded, color: Colors.white),
                label: const Text(
                  'Mainkan Musik',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: widget.onRetry,
                child: const Text('Scan Ulang',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
