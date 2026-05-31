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
  String _selectedFilter = 'all'; // all, today, week, month
  String _sortOrder = 'desc'; // desc, asc

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => isLoading = true);
    final list = await AuthHelper().getEmotionStats();
    if (mounted) {
      setState(() {
        statsList = list;
        isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredAndSortedStats {
    List<dynamic> filtered = [];
    final now = DateTime.now();

    for (var item in statsList) {
      // MongoDB menyimpan sebagai 'created_at', bukan 'timestamp'
      final timestampStr = (item['created_at'] ?? item['timestamp']) as String?;
      if (timestampStr == null) continue;

      DateTime? date;
      try {
        date = DateTime.parse(timestampStr);
      } catch (e) {
        continue;
      }

      bool include = false;
      if (_selectedFilter == 'all') {
        include = true;
      } else if (_selectedFilter == 'today') {
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          include = true;
        }
      } else if (_selectedFilter == 'week') {
        if (now.difference(date).inDays <= 7) {
          include = true;
        }
      } else if (_selectedFilter == 'month') {
        if (date.year == now.year && date.month == now.month) {
          include = true;
        }
      }

      if (include) {
        filtered.add(item);
      }
    }

    // Sort by created_at
    filtered.sort((a, b) {
      final tsA = (a['created_at'] ?? a['timestamp']) as String? ?? '';
      final tsB = (b['created_at'] ?? b['timestamp']) as String? ?? '';
      final dateA = DateTime.tryParse(tsA) ?? DateTime(0);
      final dateB = DateTime.tryParse(tsB) ?? DateTime(0);
      if (_sortOrder == 'desc') {
        return dateB.compareTo(dateA);
      } else {
        return dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

  // Emoji dan warna untuk setiap emosi
  Map<String, Map<String, dynamic>> _emotionStyles() => {
    'happy': {'emoji': '😊', 'color': const Color(0xFFE2B86C), 'label': 'Happy'},
    'sad': {'emoji': '😢', 'color': const Color(0xFF8BA6C9), 'label': 'Sad'},
    'angry': {'emoji': '😡', 'color': const Color(0xFFD67373), 'label': 'Angry'},
    'anger': {'emoji': '😡', 'color': const Color(0xFFD67373), 'label': 'Anger'},
    'neutral': {'emoji': '😐', 'color': const Color(0xFF8BC34A), 'label': 'Neutral'},
    'netral': {'emoji': '😐', 'color': const Color(0xFF8BC34A), 'label': 'Neutral'},
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
    final displayList = _filteredAndSortedStats;
    for (var item in displayList) {
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
                  style: TextStyle(fontSize: 14, color: textDark.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildFilterDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSortDropdown()),
                  ],
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
                  ...displayList.map((item) {
                    final em = (item['emotion'] ?? 'unknown').toString().toLowerCase();
                    final style = styles[em] ?? {'emoji': '❓', 'color': Colors.grey, 'label': em};
                    final timestamp = (item['created_at'] ?? item['timestamp'] ?? '').toString();
                    final confidence = (item['confidence'] as num?)?.toDouble() ?? 0.0;
                    return _buildTimelineItem(style, timestamp, confidence);
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

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          dropdownColor: const Color(0xFF1A2A14),
          icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          isExpanded: true,
          onChanged: (value) {
            if (value != null) setState(() => _selectedFilter = value);
          },
          items: const [
            DropdownMenuItem(value: 'all', child: Text("Semua Waktu")),
            DropdownMenuItem(value: 'today', child: Text("Hari Ini")),
            DropdownMenuItem(value: 'week', child: Text("7 Hari Terakhir")),
            DropdownMenuItem(value: 'month', child: Text("Bulan Ini")),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortOrder,
          dropdownColor: const Color(0xFF1A2A14),
          icon: const Icon(Icons.sort, color: Colors.white70, size: 16),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          isExpanded: true,
          onChanged: (value) {
            if (value != null) setState(() => _sortOrder = value);
          },
          items: const [
            DropdownMenuItem(value: 'desc', child: Text("Terbaru")),
            DropdownMenuItem(value: 'asc', child: Text("Terlama")),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
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
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
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
            moodColor.withValues(alpha: 0.35),
            moodColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: moodColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: moodColor.withValues(alpha: 0.2),
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
            "$total kali deteksi pada periode ini",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: moodColor.withValues(alpha: 0.2),
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
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: color,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> style, String timestamp, double confidence) {
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(style['emoji'] as String, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style['label'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (confidence > 0) ...
                  [
                    const SizedBox(height: 4),
                    // Mini progress bar confidence
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: confidence / 100,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              color: color,
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${confidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _getMoodAdvice(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '🌟 Kamu sedang dalam mood terbaik! Nikmati harimu!';
      case 'sad':
        return '💙 Dengarkan musik yang mengangkat semangat!';
      case 'angry':
      case 'anger':
        return '🔥 Tarik napas dalam, coba musik relaksasi.';
      case 'neutral':
      case 'netral':
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
