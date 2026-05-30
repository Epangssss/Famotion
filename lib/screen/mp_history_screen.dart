import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import '../utils/auth_helper.dart';
import '../services/audio_manager.dart';

class MPHistoryScreen extends StatefulWidget {
  const MPHistoryScreen({super.key});

  @override
  State<MPHistoryScreen> createState() => _MPHistoryScreenState();
}

class _MPHistoryScreenState extends State<MPHistoryScreen> {
  List<dynamic> historyList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await AuthHelper().getListeningHistory();
    if (mounted) {
      setState(() {
        historyList = list;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgBottom = Color(0xFF1A2A14);

    return Scaffold(
      backgroundColor: bgBottom,
      appBar: AppBar(
        title: const Text('Listening History', style: TextStyle(color: Colors.white)),
        backgroundColor: bgBottom,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8A854)))
        : historyList.isEmpty
          ? const Center(child: Text("Belum ada riwayat lagu", style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                final song = historyList[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song['imageUrl'] != null && song['imageUrl'].toString().isNotEmpty
                        ? Image.network(song['imageUrl'], width: 50, height: 50, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(width: 50, height: 50, color: Colors.grey, child: const Icon(Icons.music_note)))
                        : Container(width: 50, height: 50, color: Colors.grey, child: const Icon(Icons.music_note)),
                  ),
                  title: Text(song['title'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1),
                  subtitle: Text(song['artist'] ?? 'Unknown', style: TextStyle(color: Colors.white.withValues(alpha: 0.6)), maxLines: 1),
                  trailing: const Icon(Icons.play_circle_fill, color: Color(0xFFD8A854)),
                  onTap: () {
                    // Mainkan ulang lagu jika ditekan
                    if (song['audioUrl'] != null) {
                       AudioManager.instance.playMusic(
                         audioUrl: song['audioUrl'],
                         title: song['title'],
                         artist: song['artist'],
                         imageUrl: song['imageUrl'],
                         durationMs: song['durationMs'],
                       );
                       toast('Memutar lagu dari riwayat...');
                    }
                  },
                );
              },
            ),
    );
  }
}
