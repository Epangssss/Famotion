import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../player_page.dart';
import '../services/audio_manager.dart';
import '../utils/notification_helper.dart';
import '../widgets/empty_state_widget.dart';
import 'MPSearchScreen.dart';
import 'MPCameraScreen.dart';
import 'MPLoginScreen.dart';
import 'MPDiscoverScreen.dart';
import 'MPLibraryScreen.dart';
import 'MPProfileScreen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> _musicList = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";

  // State for currently playing track tracking
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;
  bool _isStartingPlayback = false;

  // State for bottom navigation
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchMusic();

    AudioManager.instance.isPlayingNotifier.addListener(_onPlayerStateChanged);
    AudioManager.instance.currentUrlNotifier.addListener(_onPlayerStateChanged);
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {
        _isPlaying = AudioManager.instance.isPlayingNotifier.value;
        _currentlyPlayingUrl = AudioManager.instance.currentUrlNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    AudioManager.instance.isPlayingNotifier
        .removeListener(_onPlayerStateChanged);
    AudioManager.instance.currentUrlNotifier
        .removeListener(_onPlayerStateChanged);
    super.dispose();
  }

  Future<void> _fetchMusic() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = "";
    });

    try {
      // 10.0.2.2 is local host for Android Emulators. Change to 'localhost' if running on desktop/web.
      final response = await http.get(Uri.parse('http://10.0.2.2:3000/music'));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            var data = json.decode(response.body);
            List<dynamic> songs = data['songs'] ?? [];
            songs.shuffle();
            _musicList = songs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = "Gagal memuat data dari server (${response.statusCode}).";
          });
        }
      }
    } catch (e) {
      // Fallback for desktop/web
      try {
        final response = await http.get(Uri.parse('http://localhost:3000/music'));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              var data = json.decode(response.body);
              List<dynamic> songs = data['songs'] ?? [];
              songs.shuffle();
              _musicList = songs;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = "Gagal memuat data dari server lokal (${response.statusCode}).";
            });
          }
        }
      } catch (e2) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = "Koneksi ke server musik gagal. Pastikan server lokal berjalan.";
          });
        }
      }
    }
  }

  int _parseDuration(String? dur) {
    if (dur == null || dur.trim().isEmpty || dur.trim().toLowerCase() == 'full') return 0;
    final p = dur.split(':');
    try {
      if (p.length == 2) return (int.parse(p[0]) * 60 + int.parse(p[1])) * 1000;
      if (p.length == 3) return (int.parse(p[0]) * 3600 + int.parse(p[1]) * 60 + int.parse(p[2])) * 1000;
    } catch (_) {}
    return 0;
  }

  Future<void> _playAndNavigate({
    required String audioUrl,
    required String title,
    required String artist,
    required String imageUrl,
    String? durationStr,
    bool navigate = true,
  }) async {
    if (_isStartingPlayback) return;
    setState(() => _isStartingPlayback = true);
    
    if (mounted) {
      showSlidingInfoNotification(context, "Lagu akan segera diputar, mohon bersabar...");
    }

    try {
      await AudioManager.instance.playMusic(
        audioUrl: audioUrl,
        title: title,
        artist: artist,
        imageUrl: imageUrl,
        durationMs: _parseDuration(durationStr),
      );

      if (navigate && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerPage(
              videoId: '', // Not using YouTube if playing from dashboard
              title: title,
              artist: artist,
              imageUrl: imageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error playing music: $e");
      if (mounted) {
        showSlidingErrorNotification(
          context,
          "Gagal memutar lagu. Mungkin tidak ada preview yang tersedia.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingPlayback = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Palet warna cerah, sejuk, dan hangat
    const Color bgTop = Color(0xFFDCE7CD);
    const Color bgMid = Color(0xFF6A8A53);
    const Color bgBottom = Color(0xFF1A2A14);
    const Color cardGradientStart = Color(0xFFF5F2D8);
    const Color cardGradientEnd = Color(0xFFE0AF84);
    const Color textDark = Color(0xFF293B1F);
    const Color textBrown = Color(0xFF534A31);
    const Color accentGold = Color(0xFFD8A854);

    // Daftar layar yang akan ditampilkan sesuai index Bottom Navigation
    final List<Widget> _screens = [
      _buildHomeContent(bgTop, bgMid, bgBottom, cardGradientStart,
          cardGradientEnd, textDark, textBrown, accentGold),
      const MPDiscoverScreen(),
      const MPLibraryScreen(),
      const MPProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: bgBottom,
      endDrawer: _buildProfileDrawer(context),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Mini Player — tampil di atas Bottom Nav saat ada lagu yang diputar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMiniPlayer(accentGold),
          ),
        ],
      ),
      // Bottom Navigation Bar with Center Camera FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigasi ke Halaman Deteksi Emosi (Kamera)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MPCameraScreen(),
            ),
          );
        },
        backgroundColor: accentGold,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.sentiment_satisfied_alt, // Emote/camera icon
          color: Colors.white,
          size: 32,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1E2E17),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        height: 85, // Ditinggikan sedikit untuk menghindari overflow
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            _buildBottomNavItem(
                Icons.home_filled, 'Home', _currentIndex == 0, 0),
            _buildBottomNavItem(
                Icons.explore_outlined, 'Discover', _currentIndex == 1, 1),
            const SizedBox(
                width:
                    56), // Spasi yang lebih luas untuk tombol kamera di tengah
            _buildBottomNavItem(
                Icons.library_music_outlined, 'Library', _currentIndex == 2, 2),
            _buildBottomNavItem(
                Icons.person_outline, 'Profile', _currentIndex == 3, 3),
          ],
        ),
      ),
    );
  }

  // Konten Utama Dashboard (Home)
  Widget _buildHomeContent(
      Color bgTop,
      Color bgMid,
      Color bgBottom,
      Color cardGradientStart,
      Color cardGradientEnd,
      Color textDark,
      Color textBrown,
      Color accentGold) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgMid, bgBottom],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchMusic,
          color: accentGold,
          backgroundColor: bgBottom,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Header (Right Aligned Profile)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Builder(builder: (context) {
                      return GestureDetector(
                        onTap: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: textDark.withOpacity(0.15),
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: textDark,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),

                // Search Bar (Navigasi ke MPSearchScreen)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MPSearchScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ]),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            color: textDark.withOpacity(0.8), size: 24),
                        const SizedBox(width: 12),
                        Text(
                          "Cari lagu, artis, atau album...",
                          style: TextStyle(
                            color: textDark.withOpacity(0.7),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Mood Result Card (Soft Gradient/Glassmorphism)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [cardGradientStart, cardGradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Famotion",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textBrown,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Mockup Emoticon / Logo Custom (Hati, Gelombang, & Daun)
                      _buildCustomHeartLogo(
                          const Color(0xFF556942), const Color(0xFFF9F6D6)),
                      const SizedBox(height: 24),
                      Text(
                        "lagi galau dan bingung mau mendengarkan musik, mau mendengar hal baru?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: textBrown.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Famotion hadir untuk menemukan mood musik yang tepat untuk perasaan anda.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textBrown.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Analysis based on your activity and input.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textBrown.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Section: Explore Recommendations
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "EXPLORE RECOMMENDATIONS",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: textDark,
                      ),
                    ),
                    // Tombol Refresh
                    GestureDetector(
                      onTap: () {
                        setState(() => _isLoading = true);
                        _fetchMusic();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: textDark.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 14, color: textDark),
                            const SizedBox(width: 4),
                            Text(
                              "Refresh",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: textDark,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Horizontal ListView for Cards
                _isLoading
                    // Shimmer skeleton loading cards
                    ? SizedBox(
                        height: 230,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 4,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: _buildSkeletonCard(accentGold),
                            );
                          },
                        ),
                      )
                    : _hasError
                        ? MPEmptyStateWidget(
                            icon: Icons.wifi_off_rounded,
                            title: "Gagal Memuat Data",
                            description: _errorMessage,
                            buttonText: "Coba Lagi",
                            onRetry: _fetchMusic,
                            iconColor: Colors.redAccent,
                            textColor: textDark,
                          )
                        : _musicList.isEmpty
                            ? MPEmptyStateWidget(
                                icon: Icons.music_off_rounded,
                                title: "Tidak Ada Rekomendasi",
                                description: "Kami belum memiliki rekomendasi lagu untukmu saat ini.",
                                buttonText: "Refresh",
                                onRetry: _fetchMusic,
                                iconColor: accentGold,
                                textColor: textDark,
                              )
                        : SizedBox(
                            height: 230,
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                },
                              ),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                clipBehavior: Clip.none,
                                itemCount: _musicList.length > 20
                                    ? 20
                                    : _musicList.length,
                                itemBuilder: (context, index) {
                                final track = _musicList[index];
                                final previewUrl = track['preview'];
                                final streamUrl = track['stream_url'];
                                final audioUrl = streamUrl ?? previewUrl;
                                // Fallback if there's no preview url provided, though this disables playback
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildImageTrackCard(
                                    track['title'] ?? 'Unknown',
                                    track['artist'] ?? 'Unknown',
                                    track['duration'] ??
                                        'Full', // previously "Full"
                                    track['thumbnail'] ??
                                        'https://images.unsplash.com/photo-1518837695005-2083093ee35b?q=80&w=256&auto=format&fit=crop',
                                    audioUrl,
                                  ),
                                );
                              },
                            ), // ends ListView.builder
                          ), // ends ScrollConfiguration
                        ), // ends SizedBox
                const SizedBox(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 4. Section: For You
                      Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "FOR YOU",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.white70,
                      ),
                    ),
                    Icon(Icons.more_horiz,
                        color: Colors.white.withOpacity(0.7)),
                  ],
                ),
                const SizedBox(height: 16),

                // Vertical List of Tracks
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                        child: CircularProgressIndicator(color: accentGold)),
                  )
                else if (_hasError)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                        child: Text("Gagal memuat daftar lagu.",
                            style: TextStyle(color: Colors.white54))),
                  )
                else if (_musicList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                        child: Text("No tracks available",
                            style: TextStyle(color: Colors.white54))),
                  )
                else
                  ..._musicList
                      .skip(10)
                      .take(20)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    var track = entry.value;
                    final previewUrl = track['preview'];
                    final streamUrl = track['stream_url'];
                    final audioUrl = streamUrl ?? previewUrl;
                    bool isTrackPlaying = _currentlyPlayingUrl == audioUrl &&
                        _isPlaying &&
                        audioUrl != null;

                    return _buildPlaylistItem(
                      track['title'] ?? 'Unknown',
                      track['artist'] ?? 'Unknown',
                      track['duration'] ?? 'Full',
                      isTrackPlaying,
                      track['thumbnail'] ??
                          'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?q=80&w=150&auto=format&fit=crop',
                      audioUrl,
                    );
                  }),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MINI PLAYER WIDGET
  // ==========================================
  Widget _buildMiniPlayer(Color accentGold) {
    return ValueListenableBuilder<String?>(
      valueListenable: AudioManager.instance.currentUrlNotifier,
      builder: (context, currentUrl, _) {
        // Hanya tampil jika ada lagu yang aktif
        if (currentUrl == null || currentUrl.isEmpty) return const SizedBox.shrink();

        return ValueListenableBuilder<String?>(
          valueListenable: AudioManager.instance.titleNotifier,
          builder: (context, title, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: AudioManager.instance.artistNotifier,
              builder: (context, artist, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: AudioManager.instance.imageUrlNotifier,
                  builder: (context, imageUrl, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: AudioManager.instance.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerPage(
                                  videoId: '',
                                  title: title ?? 'Unknown',
                                  artist: artist ?? 'Unknown',
                                  imageUrl: imageUrl ?? '',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF253B1D),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, -4),
                                )
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Album Art
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 46,
                                          height: 46,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 46,
                                            height: 46,
                                            color: Colors.white10,
                                            child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
                                          ),
                                        )
                                      : Container(
                                          width: 46,
                                          height: 46,
                                          color: Colors.white10,
                                          child: const Icon(Icons.music_note, color: Colors.white54, size: 24),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Title + Artist
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        title ?? 'Unknown',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        artist ?? 'Unknown',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Play / Pause
                                IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    if (isPlaying) {
                                      AudioManager.instance.audioPlayer.pause();
                                    } else {
                                      AudioManager.instance.audioPlayer.play();
                                    }
                                  },
                                ),
                                // Skip Next
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color: accentGold,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    AudioManager.instance.playNext();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Widget custom untuk item BottomAppBar
  Widget _buildBottomNavItem(
      IconData icon, String label, bool isSelected, int index) {
    const Color accentGold = Color(0xFFD8A854);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? accentGold : Colors.white54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? accentGold : Colors.white54,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Profile Drawer Widget
  Widget _buildProfileDrawer(BuildContext context) {
    const Color bgBottom = Color(0xFF1A2A14);
    const Color accentGold = Color(0xFFD8A854);

    return Drawer(
      backgroundColor: bgBottom,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF253B1D),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: accentGold.withOpacity(0.2),
                    child:
                        const Icon(Icons.person, size: 40, color: accentGold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "User Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "user@famotion.com",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white70),
              title: const Text("Baru Diputar",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Implementation for Recently Played
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: const Text("Pengaturan dan Privasi",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Implementation for Settings & Privacy
              },
            ),
            const Spacer(),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Keluar",
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context); // Menutup drawer terlebih dahulu
                _showLogoutConfirmationDialog(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Dialog Konfirmasi Keluar
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF293B1F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Konfirmasi Keluar",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Apakah Anda yakin ingin keluar dari aplikasi?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Tutup dialog
              },
              child: const Text(
                "Batal",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Tutup dialog
                Navigator.pop(dialogContext);
                // Navigasi ke Halaman Login
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const MPLoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text(
                "Keluar",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Animated shimmer skeleton card for loading state
  Widget _buildSkeletonCard(Color accentGold) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedOpacity(
          opacity: value,
          duration: const Duration(milliseconds: 400),
          child: child,
        );
      },
      onEnd: () {},
      child: SizedBox(
        width: 150,
        height: 220,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: _ShimmerBox(width: 150, height: 150),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 110, height: 10),
                    const SizedBox(height: 6),
                    _ShimmerBox(width: 75, height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageTrackCard(String title, String subtitle, String duration,
      String imageUrl, String? audioUrl) {
    bool isTrackPlaying =
        _currentlyPlayingUrl == audioUrl && _isPlaying && audioUrl != null;
    return GestureDetector(
        onTap: () {
          if (audioUrl != null) {
            _playAndNavigate(
              audioUrl: audioUrl,
              title: title,
              artist: subtitle,
              imageUrl: imageUrl,
              durationStr: duration,
              navigate: true,
            );
          }
        },
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isTrackPlaying
                ? const Color(0xFFD8A854).withOpacity(0.15)
                : const Color(0xFF587744).withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isTrackPlaying ? const Color(0xFFD8A854) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image / Album Art
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  imageUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 100,
                    width: double.infinity,
                    color: Colors.white10,
                    child: const Icon(Icons.music_note,
                        color: Colors.white54, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 6),
              // Duration & Play Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    duration,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD8A854), // Accent Gold
                      ),
                      child: Icon(
                          isTrackPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16),
                    ),
                    onPressed: () {
                      if (audioUrl != null) {
                        _playAndNavigate(
                          audioUrl: audioUrl,
                          title: title,
                          artist: subtitle,
                          imageUrl: imageUrl,
                          durationStr: duration,
                          navigate: false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  // Widget for the List Items in the "For You" Section
  Widget _buildPlaylistItem(String title, String subtitle, String duration,
      bool isPlaying, String imageUrl, String? audioUrl) {
    return GestureDetector(
        onTap: () {
          if (audioUrl != null) {
            _playAndNavigate(
              audioUrl: audioUrl,
              title: title,
              artist: subtitle,
              imageUrl: imageUrl,
              durationStr: duration,
              navigate: true,
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          child: Row(
            children: [
              // Thumbnail Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.white10,
                    child: const Icon(Icons.music_note,
                        color: Colors.white54, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              if (isPlaying) ...[
                const Icon(Icons.favorite_border,
                    color: Colors.white54, size: 20),
                const SizedBox(width: 16),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD7A85C), // Accent Gold
                    ),
                    child:
                        const Icon(Icons.pause, color: Colors.white, size: 16),
                  ),
                  onPressed: () {
                    if (audioUrl != null) {
                      _playAndNavigate(
                        audioUrl: audioUrl,
                        title: title,
                        artist: subtitle,
                        imageUrl: imageUrl,
                        durationStr: duration,
                        navigate: false,
                      );
                    }
                  },
                ),
              ] else ...[
                Icon(
                  Icons.more_horiz,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(width: 16),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  onPressed: () {
                    if (audioUrl != null) {
                      _playAndNavigate(
                        audioUrl: audioUrl,
                        title: title,
                        artist: subtitle,
                        imageUrl: imageUrl,
                        durationStr: duration,
                        navigate: false,
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ));
  }

  // Widget khusus untuk logo tengah (Hati dengan Gelombang & Daun)
  Widget _buildCustomHeartLogo(Color iconColor, Color goldColor) {
    return SizedBox(
      height: 140,
      width: 140,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Dekorasi Daun dan Hati di luar lingkaran
          Positioned(
            top: 15,
            left: 30,
            child: Icon(
              Icons.favorite,
              size: 16,
              color: iconColor.withOpacity(0.8),
            ),
          ),
          Positioned(
            top: 10,
            right: 35,
            child: Icon(
              Icons.favorite,
              size: 20,
              color: iconColor.withOpacity(0.8),
            ),
          ),
          Positioned(
            top: 45,
            left: 5,
            child: Transform.rotate(
              angle: -0.5,
              child: Icon(Icons.eco, size: 24, color: iconColor),
            ),
          ),
          Positioned(
            bottom: 25,
            left: 15,
            child: Transform.rotate(
              angle: 3.5,
              child: Icon(Icons.eco, size: 28, color: iconColor),
            ),
          ),
          Positioned(
            top: 55,
            right: 5,
            child: Transform.rotate(
              angle: 1.0,
              child: Icon(Icons.eco, size: 24, color: iconColor),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 15,
            child: Transform.rotate(
              angle: -3.5,
              child: Icon(Icons.eco, size: 28, color: iconColor),
            ),
          ),

          // Lingkaran utama
          Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.85),
              border: Border.all(
                color: goldColor.withOpacity(0.4),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: goldColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Icon(Icons.favorite, size: 38, color: goldColor),
                const SizedBox(height: 2),
                SizedBox(
                  width: 44,
                  height: 16,
                  child: CustomPaint(
                    painter: WavePainter(color: goldColor),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter untuk Menggambar 3 Garis Gelombang Pendek
class WavePainter extends CustomPainter {
  final Color color;
  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Gelombang Atas (Melengkung penuh)
    final path1 = Path();
    path1.moveTo(0, size.height * 0.3);
    path1.quadraticBezierTo(size.width * 0.25, -size.height * 0.4,
        size.width * 0.5, size.height * 0.3);
    path1.quadraticBezierTo(
        size.width * 0.75, size.height * 1.0, size.width, size.height * 0.3);

    // Gelombang Tengah (Sedikit lebih pendek ke kanan dan kiri)
    final path2 = Path();
    path2.moveTo(size.width * 0.15, size.height * 0.65);
    path2.quadraticBezierTo(size.width * 0.35, size.height * 0.0,
        size.width * 0.6, size.height * 0.65);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 1.3,
        size.width * 0.9, size.height * 0.65);

    // Gelombang Bawah (Paling pendek)
    final path3 = Path();
    path3.moveTo(size.width * 0.3, size.height * 1.0);
    path3.quadraticBezierTo(size.width * 0.45, size.height * 0.5,
        size.width * 0.6, size.height * 1.0);
    path3.quadraticBezierTo(size.width * 0.7, size.height * 1.5,
        size.width * 0.8, size.height * 1.0);

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Shimmer / Skeleton placeholder box widget
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 0.45).animate(
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
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_anim.value),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
