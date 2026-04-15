import 'package:flutter/material.dart';
import '../utils/auth_helper.dart';

class MPDiscoverScreen extends StatefulWidget {
  const MPDiscoverScreen({super.key});

  @override
  State<MPDiscoverScreen> createState() => _MPDiscoverScreenState();
}

class _MPDiscoverScreenState extends State<MPDiscoverScreen> {
  List<dynamic> statsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final list = await AuthHelper().getEmotionStats();
    if (mounted) {
      setState(() {
        statsList = list;
        isLoading = false;
      });
    }
  }

  // Emoji dan warna untuk setiap emosi
  Map<String, Map<String, dynamic>> _emotionStyles() => {
    'happy': {'emoji': '😊', 'color': const Color(0xFFE2B86C), 'label': 'Happy'},
    'sad': {'emoji': '😢', 'color': const Color(0xFF8BA6C9), 'label': 'Sad'},
    'angry': {'emoji': '😡', 'color': const Color(0xFFD67373), 'label': 'Angry'},
    'neutral': {'emoji': '😐', 'color': const Color(0xFF91B8A0), 'label': 'Neutral'},
    'fear': {'emoji': '😰', 'color': const Color(0xFFD188D4), 'label': 'Fear'},
    'surprise': {'emoji': '😲', 'color': const Color(0xFFE8C96B), 'label': 'Surprise'},
    'disgust': {'emoji': '🤢', 'color': const Color(0xFF7BAF7E), 'label': 'Disgust'},
    'stress': {'emoji': '😫', 'color': const Color(0xFFCF8B62), 'label': 'Stress'},
    'calm': {'emoji': '😌', 'color': const Color(0xFF8AC79B), 'label': 'Calm'},
  };

  @override
  Widget build(BuildContext context) {
    const Color bgTop = Color(0xFFDCE7CD);
    const Color bgMid = Color(0xFF6A8A53);
    const Color bgBottom = Color(0xFF1A2A14);
    const Color textDark = Color(0xFF293B1F);
    const Color accentGold = Color(0xFFD8A854);

    // Hitung statistik
    Map<String, int> counts = {};
    for (var item in statsList) {
      final String em = (item['emotion'] ?? 'unknown').toString().toLowerCase();
      counts[em] = (counts[em] ?? 0) + 1;
    }
    int total = counts.values.fold(0, (a, b) => a + b);

    // Cari emosi dominan
    String dominantEmotion = 'neutral';
    if (counts.isNotEmpty) {
      dominantEmotion = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    // Sortir emosi berdasarkan jumlah (terbanyak dulu)
    final sortedEntries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final styles = _emotionStyles();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgMid, bgBottom],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: accentGold,
          backgroundColor: bgBottom,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  "Mood Tracker",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  "Analisis emosi kamu berdasarkan Face Mood",
                  style: TextStyle(fontSize: 14, color: textDark.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),

                // ===== KARTU MOOD UTAMA =====
                if (isLoading)
                  _buildLoadingCard()
                else if (total == 0)
                  _buildEmptyMoodCard(textDark)
                else ...[
                  // Kartu Dominan Mood
                  _buildDominantMoodCard(dominantEmotion, total, styles, textDark),
                  const SizedBox(height: 24),

                  // ===== STATISTIK BAR =====
                  const Text(
                    "DISTRIBUSI EMOSI",
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      letterSpacing: 1.0, color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...sortedEntries.map((entry) {
                    final percentage = (entry.value / total) * 100;
                    final style = styles[entry.key] ?? {'emoji': '❓', 'color': Colors.grey, 'label': entry.key};
                    return _buildEmotionBar(style, percentage);
                  }),

                  const SizedBox(height: 24),

                  // ===== MOOD TIMELINE (Terakhir 10 deteksi) =====
                  const Text(
                    "RIWAYAT DETEKSI",
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      letterSpacing: 1.0, color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...statsList.take(10).map((item) {
                    final em = (item['emotion'] ?? 'unknown').toString().toLowerCase();
                    final style = styles[em] ?? {'emoji': '❓', 'color': Colors.grey, 'label': em};
                    final timestamp = item['timestamp'] ?? '';
                    return _buildTimelineItem(style, timestamp);
                  }),
                ],

                const SizedBox(height: 100), // Padding bottom agar tidak tertutup navbar
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====== WIDGET BUILDERS ======

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFFD8A854)),
      ),
    );
  }

  Widget _buildEmptyMoodCard(Color textDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text("😶", style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            "Belum ada data mood",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Gunakan tombol 😊 Face Mood di bawah\nuntuk mulai tracking emosi kamu hari ini!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDominantMoodCard(String emotion, int total, Map<String, Map<String, dynamic>> styles, Color textDark) {
    final style = styles[emotion] ?? {'emoji': '❓', 'color': Colors.grey, 'label': emotion};
    final Color moodColor = style['color'] as Color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            moodColor.withOpacity(0.35),
            moodColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: moodColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: moodColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(style['emoji'] as String, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            "Mood Dominan: ${style['label']}",
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "$total kali deteksi dalam 7 hari terakhir",
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: moodColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getMoodAdvice(emotion),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionBar(Map<String, dynamic> style, double percentage) {
    final Color color = style['color'] as Color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(style['emoji'] as String, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                style['label'] as String,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              color: color,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> style, String timestamp) {
    final Color color = style['color'] as Color;
    String timeStr = '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      timeStr = '${dt.day}/${dt.month} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      timeStr = timestamp;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Text(style['emoji'] as String, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              style['label'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getMoodAdvice(String emotion) {
    switch (emotion) {
      case 'happy':
        return '🌟 Kamu sedang dalam mood terbaik! Nikmati harimu!';
      case 'sad':
        return '💙 Dengarkan musik yang mengangkat semangat!';
      case 'angry':
        return '🔥 Tarik napas dalam, coba musik relaksasi.';
      case 'neutral':
        return '☺️ Tenang dan stabil, waktu yang bagus untuk eksplorasi!';
      case 'fear':
        return '🌈 Kamu aman! Dengarkan musik yang menenangkan.';
      case 'surprise':
        return '✨ Hari penuh kejutan! Coba lagu-lagu baru!';
      case 'stress':
        return '🍃 Istirahat sejenak, putar musik lo-fi.';
      case 'calm':
        return '🧘 Ketenangan adalah kekuatan! Teruskan vibes ini.';
      default:
        return '🎵 Terus dengarkan musik kesukaanmu!';
    }
  }
}
