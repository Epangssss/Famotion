import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../utils/auth_helper.dart';

class MPAnalyticsScreen extends StatefulWidget {
  const MPAnalyticsScreen({super.key});

  @override
  State<MPAnalyticsScreen> createState() => _MPAnalyticsScreenState();
}

class _MPAnalyticsScreenState extends State<MPAnalyticsScreen> {
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

  @override
  Widget build(BuildContext context) {
    const Color bgBottom = Color(0xFF1A2A14);
    
    // Hitung jumlah kemunculan per emosi
    Map<String, int> counts = {};
    for (var item in statsList) {
      final String em = (item['emotion'] ?? 'Unknown').toString().toLowerCase();
      counts[em] = (counts[em] ?? 0) + 1;
    }

    int total = counts.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: bgBottom,
      appBar: AppBar(
        title: const Text('Mood Analytics', style: TextStyle(color: Colors.white)),
        backgroundColor: bgBottom,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8A854)))
        : statsList.isEmpty || total == 0
          ? const Center(child: Text("Belum ada data emosi, cobalah scan wajah!", style: TextStyle(color: Colors.white70)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Statistik 7 Hari Terakhir", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  ...counts.entries.map((entry) {
                    final percentage = (entry.value / total) * 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key.capitalizeFirstLetter(), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                              Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: const Color(0xFFD8A854),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white54),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Sering-sering gunakan fitur scan mood untuk mendapatkan rekomendasi musik yang lebih pas!",
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
