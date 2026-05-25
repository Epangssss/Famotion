import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../player_page.dart';
import '../utils/notification_helper.dart';
import '../widgets/empty_state_widget.dart';
import '../utils/auth_helper.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MPSearchScreen extends StatefulWidget {
  const MPSearchScreen({super.key});

  @override
  State<MPSearchScreen> createState() => _MPSearchScreenState();
}

class _MPSearchScreenState extends State<MPSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = "";
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchQuery = query;
      _searchResults = [];
      _hasError = false;
      _errorMessage = "";
    });

    final yt = YoutubeExplode();
    try {
      // Selalu tambahkan "official audio" agar YouTube bias ke lagu asli,
      // bukan clip/meme/short apapun kata yang diketik user
      final String musicQuery = '${query.trim()} official audio';
      
      final searchResult = await yt.search.search(musicQuery);
      
      if (mounted) {
        // Kata kunci konten yang harus dibuang — termasuk kata bahasa Indonesia
        const List<String> blockedKeywords = [
          // Shorts / Clip / Fancam
          '#shorts', '#short', 'shorts', 'short film',
          'clip', 'mv clip', 'fancam', 'fan cam',
          // Meme / Viral / Lucu
          'meme', 'funny', 'lucu', 'viral', 'tiktok',
          'ngakak', 'kocak', 'parody', 'parodi',
          // Reaction / Commentary
          'reaction', 'react', 'reacts', 'reaksi',
          // Podcast / Interview
          'podcast', 'interview',
          // Concert / Album
          'full album', 'full concert', 'live concert',
          'konser penuh', 'penampilan langsung',
          // Lainnya
          'trailer', 'teaser', 'behind the scenes',
          'compilation', 'kompilasi',
          'best of',
        ];

        List<dynamic> filtered = [];
        for (var video in searchResult) {
          final String rawTitle = video.title;
          final String lowerTitle = rawTitle.toLowerCase();

          // 1. Filter konten bermasalah berdasarkan judul
          bool isBlocked = blockedKeywords.any((kw) => lowerTitle.contains(kw));
          if (isBlocked) continue;

          // 2. Filter durasi minimum 2 menit (lagu asli hampir selalu >= 2 menit)
          final duration = video.duration;
          if (duration != null) {
            if (duration.inSeconds < 110) continue; // < ~2 menit → skip (short/meme)
          }

          filtered.add({
            'title': video.title,
            'artist': video.author,
            'duration': duration != null 
                ? '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}' 
                : '',
            'thumbnail': video.thumbnails.highResUrl,
            'videoId': video.id.value,
          });
        }

        setState(() {
          _searchResults = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "Gagal memuat hasil pencarian. Error: $e";
        });
      }
    } finally {
      yt.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgTop = Color(0xFFDCE7CD);
    const Color bgMid = Color(0xFF6A8A53);
    const Color bgBottom = Color(0xFF1A2A14);
    const Color textDark = Color(0xFF293B1F);
    const Color accentGold = Color(0xFFD8A854);

    return Scaffold(
      backgroundColor: bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgMid, bgBottom],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: textDark),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: _performSearch,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Cari lagu, artis, atau album...",
                            contentPadding: EdgeInsets.symmetric(vertical: 12), 
                            hintStyle: TextStyle(
                              color: textDark.withOpacity(0.6),
                              fontWeight: FontWeight.normal,
                            ),
                            icon: Icon(Icons.search, color: textDark.withOpacity(0.8), size: 24),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: textDark, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (text) {
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: accentGold),
                      )
                    : _hasError
                        ? MPEmptyStateWidget(
                            icon: Icons.error_outline_rounded,
                            title: "Pencarian Gagal",
                            description: _errorMessage,
                            buttonText: "Coba Lagi",
                            onRetry: () => _performSearch(_searchQuery),
                            iconColor: Colors.redAccent,
                            textColor: textDark,
                          )
                        : _searchResults.isEmpty && _searchQuery.isNotEmpty
                            ? MPEmptyStateWidget(
                                icon: Icons.search_off_rounded,
                                title: "Tidak Ditemukan",
                                description: "Tidak ada lagu untuk '$_searchQuery'. Coba kata kunci lain.",
                                iconColor: accentGold,
                                textColor: textDark,
                              )
                            : _searchResults.isEmpty
                                ? MPEmptyStateWidget(
                                    icon: Icons.search_rounded,
                                    title: "Cari Lagu",
                                    description: "Temukan lagu favoritmu di Famotion.",
                                    iconColor: textDark.withOpacity(0.4),
                                    textColor: textDark,
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      return _buildSearchResultItem(_searchResults[index]);
                                    },
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(dynamic video) {
    final String title = video['title'] ?? 'Unknown';
    final String artist = video['artist'] ?? 'Unknown';
    final String imageUrl = video['thumbnail'] ?? '';
    final String durationStr = video['duration'] ?? '';
    final String videoId = video['videoId'] ?? '';

    // Parse duration string "mm:ss" or "hh:mm:ss" → milliseconds
    int durationMs = 0;
    if (durationStr.isNotEmpty) {
      final p = durationStr.split(':');
      try {
        if (p.length == 2) {
          durationMs = (int.parse(p[0]) * 60 + int.parse(p[1])) * 1000;
        } else if (p.length == 3) {
          durationMs = (int.parse(p[0]) * 3600 + int.parse(p[1]) * 60 + int.parse(p[2])) * 1000;
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        showSlidingInfoNotification(context, "Lagu akan segera diputar, mohon bersabar...");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerPage(
              videoId: videoId,
              title: title,
              artist: artist,
              imageUrl: imageUrl,
              durationMs: durationMs,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.white10,
                  child: const Icon(Icons.music_note, color: Colors.white54, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$artist • $durationStr",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Play Button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD8A854).withOpacity(0.9),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
