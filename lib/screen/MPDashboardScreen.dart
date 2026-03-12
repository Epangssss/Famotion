import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import '../player_page.dart';



class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> _musicList = [];
  bool _isLoading = true;

  // Audio Player and YT Explode instance
  final AudioPlayer _audioPlayer = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();

  // State for currently playing track tracking
  String? _currentlyPlayingVideoId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _fetchMusic();

    // Listen to player state changes to update UI across the app
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _currentlyPlayingVideoId = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _fetchMusic() async {
    try {
      // 10.0.2.2 is local host for Android Emulators. Change to 'localhost' if running on desktop/web.
      final response = await http.get(Uri.parse('http://10.0.2.2:3000/music'));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _musicList = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      // Fallback for desktop/web
      try {
        final response =
            await http.get(Uri.parse('http://localhost:3000/music'));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _musicList = json.decode(response.body);
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (e2) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(dynamic durationInSeconds) {
    if (durationInSeconds == null) return "--:--";
    int totalSeconds = durationInSeconds is int
        ? durationInSeconds
        : int.tryParse(durationInSeconds.toString()) ?? 0;
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _playMusic(String videoId) async {
    try {
      if (_currentlyPlayingVideoId == videoId && _isPlaying) {
        // Pause if already playing this song
        await _audioPlayer.pause();
        return;
      } else if (_currentlyPlayingVideoId == videoId && !_isPlaying) {
        // Resume if paused
        await _audioPlayer.play();
        return;
      }

      // Indicate loading for feedback (optional, but good UX)
      if (mounted) {
        setState(() {
          _currentlyPlayingVideoId = videoId;
          _isPlaying = false; // Will be true when actually starts playing
        });
      }

      // Fetch the audio stream URL using youtube_explode_dart
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      // Set the audio source and play
      await _audioPlayer.setUrl(audioStreamInfo.url.toString());
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Error playing music: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not play the selected track.")),
        );
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Back, Title, Profile)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.arrow_back, color: textDark),
                    const Text(
                      "Your Mood Today",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: textDark.withOpacity(0.15),
                      child: const Icon(
                        Icons.person,
                        size: 20,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. Mood Result Card (Soft Gradient/Glassmorphism)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                      const Text(
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
                        "lagi galau dan bingung mau mendengarkan musik, mau dengar hal baru?",
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
                    const Text(
                      "EXPLORE RECOMMENDATIONS",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: textDark.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "View All",
                        style: TextStyle(
                            fontSize: 11,
                            color: textDark,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Horizontal ListView for Cards
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(
                            child:
                                CircularProgressIndicator(color: accentGold)),
                      )
                    : _musicList.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: Center(
                                child: Text("No recommendations available",
                                    style: TextStyle(color: Colors.white54))),
                          )
                        : SizedBox(
                            height: 210,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount:
                                  _musicList.length > 3 ? 3 : _musicList.length,
                              itemBuilder: (context, index) {
                                final track = _musicList[index];
                                final videoId = track['videoId'];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: _buildImageTrackCard(
                                    track['title'] ?? 'Unknown',
                                    track['artist'] ?? 'Unknown',
                                    _formatDuration(track['duration']),
                                    track['thumbnail'] ??
                                        'https://images.unsplash.com/photo-1518837695005-2083093ee35b?q=80&w=256&auto=format&fit=crop',
                                    videoId,
                                  ),
                                );
                              },
                            ),
                          ),
                const SizedBox(height: 32),

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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                        child: CircularProgressIndicator(color: accentGold)),
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
                      .skip(3)
                      .take(3)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    var track = entry.value;
                    final videoId = track['videoId'];
                    bool isTrackPlaying =
                        _currentlyPlayingVideoId == videoId && _isPlaying;

                    return _buildPlaylistItem(
                      track['title'] ?? 'Unknown',
                      _formatDuration(track['duration']),
                      isTrackPlaying,
                      track['thumbnail'] ??
                          'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?q=80&w=150&auto=format&fit=crop',
                      videoId,
                    );
                  }),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      // Bottom Navigation Bar matching the image
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF1E2E17),
          selectedItemColor: accentGold,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_filled), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined), label: 'Discover'),
            BottomNavigationBarItem(
                icon: Icon(Icons.library_music_outlined), label: 'Library'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // Widget for the Image-based Tracks in the Horizontal List
  Widget _buildImageTrackCard(String title, String subtitle, String duration,
      String imageUrl, String? videoId) {
    bool isTrackPlaying = _currentlyPlayingVideoId == videoId && _isPlaying;
    return GestureDetector(
        onTap: () {
          if (videoId != null) {
            _playMusic(videoId);
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
              color: isTrackPlaying ? const Color(0xFFD8A854) : Colors.transparent,
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
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 110,
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
                      if (videoId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerPage(
                              videoId: videoId,
                              title: title,
                            ),
                          ),
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
  Widget _buildPlaylistItem(String title, String duration, bool isPlaying,
      String imageUrl, String? videoId) {
    return GestureDetector(
        onTap: () {
          if (videoId != null) {
            _playMusic(videoId);
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
                    if (videoId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerPage(
                            videoId: videoId,
                            title: title,
                          ),
                        ),
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
                    if (videoId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerPage(
                            videoId: videoId,
                            title: title,
                          ),
                        ),
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
