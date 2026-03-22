import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../player_page.dart';
import '../services/audio_manager.dart';
import '../utils/notification_helper.dart';

class MPSearchScreen extends StatefulWidget {
  const MPSearchScreen({super.key});

  @override
  State<MPSearchScreen> createState() => _MPSearchScreenState();
}

class _MPSearchScreenState extends State<MPSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Video> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = "";

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
    });

    try {
      // Tambahkan kata 'music' supaya YouTube bias ke lagu, bukan live stream / channel
      final searchList = await AudioManager.instance.yt.search.search('$query music');
      if (mounted) {
        final filtered = searchList.where((v) {
          // Filter 1: Buang live stream (isLive == true atau tidak ada durasi)
          if (v.isLive) return false;
          final dur = v.duration;
          if (dur == null) return false;
          // Filter 2: Buang video terlalu pendek (shorts < 1 mnt) atau terlalu panjang (kompilasi/podcast > 7 mnt)
          final mins = dur.inMinutes;
          return mins >= 1 && mins <= 7;
        }).take(20).toList();

        setState(() {
          _searchResults = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal melakukan pencarian: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  /// Bersihkan nama channel YouTube menjadi nama artis yang rapi.
  /// Contoh: "Ed Sheeran - Topic" → "Ed Sheeran"
  ///          "TaylorSwiftVEVO" → "TaylorSwift"
  String _cleanArtistName(String channelName, String videoTitle) {
    String artist = channelName;

    // Hapus sufiks umum channel YouTube musik
    final suffixes = [
      RegExp(r'\s*-\s*Topic', caseSensitive: false),
      RegExp(r'VEVO', caseSensitive: false),
      RegExp(r'Official', caseSensitive: false),
      RegExp(r'Records', caseSensitive: false),
      RegExp(r'Music', caseSensitive: false),
      RegExp(r'Entertainment', caseSensitive: false),
      RegExp(r'Channel', caseSensitive: false),
    ];
    for (final pattern in suffixes) {
      artist = artist.replaceAll(pattern, '').trim();
    }

    // Jika nama channel tidak informatif / terlalu pendek, coba ambil dari judul video.
    // Format umum: "[Artis] - [Judul Lagu]"
    if (artist.isEmpty || artist.length <= 2) {
      if (videoTitle.contains(' - ')) {
        artist = videoTitle.split(' - ').first.trim();
      }
    }

    return artist.isNotEmpty ? artist : channelName;
  }

  @override
  Widget build(BuildContext context) {
    // Colors matching the dashboard
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          border:
                              Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                          textInputAction: TextInputAction.search,
                          onSubmitted: _performSearch,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Cari lagu, artis, atau album...",
                            hintStyle: TextStyle(
                                color: textDark.withOpacity(0.6),
                                fontWeight: FontWeight.normal),
                            icon: Icon(Icons.search,
                                color: textDark.withOpacity(0.8), size: 24),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: textDark, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (text) {
                            setState(() {}); // Update clear button visibility
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
                    : _searchResults.isEmpty && _searchQuery.isNotEmpty
                        ? Center(
                            child: Text(
                              "Tidak ada hasil untuk '$_searchQuery'",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16),
                            ),
                          )
                        : _searchResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search,
                                        size: 70,
                                        color: textDark.withOpacity(0.3)),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Temukan lagu favoritmu",
                                      style: TextStyle(
                                        color: textDark.withOpacity(0.6),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                physics: const BouncingScrollPhysics(),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final video = _searchResults[index];
                                  return _buildSearchResultItem(video);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(Video video) {
    return GestureDetector(
      onTap: () {
        showSlidingInfoNotification(context, "Lagu akan segera diputar, mohon bersabar...");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerPage(
              videoId: video.id.value,
              title: video.title,
              artist: _cleanArtistName(video.author, video.title),
              imageUrl: video.thumbnails.highResUrl,
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
                video.thumbnails.mediumResUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.white10,
                  child: const Icon(Icons.music_note,
                      color: Colors.white54, size: 30),
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
                    video.title,
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
                    "${_cleanArtistName(video.author, video.title)} • ${_formatDuration(video.duration)}",
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
                color: const Color(0xFFD8A854).withOpacity(0.9), // accentGold
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
