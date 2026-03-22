import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'services/audio_manager.dart';

class PlayerPage extends StatefulWidget {
  final String videoId;
  final String title;
  final String artist;
  final String imageUrl;
  final String? searchQuery;

  const PlayerPage({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.searchQuery,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final PageController _pageController = PageController(viewportFraction: 0.85); // Back to larger fraction for mobile mainly
  bool _isPlaying = false;
  int _currentIndex = 0;
  double _volume = 1.0;
  bool _showVolumeSlider = false; // For minimizing volume on desktop
  Color _backgroundColor = const Color(0xFF1E2E17); // Default

  @override
  void initState() {
    super.initState();

    if (widget.videoId.isNotEmpty) {
      AudioManager.instance.playYoutubeVideo(
        videoId: widget.videoId,
        title: widget.title,
        artist: widget.artist,
        imageUrl: widget.imageUrl,
      );
    } else if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchAndPlay(widget.searchQuery!);
    }

    _isPlaying = AudioManager.instance.isPlayingNotifier.value;
    AudioManager.instance.isPlayingNotifier.addListener(_onPlayerStateChanged);
    AudioManager.instance.upcomingSongsNotifier.addListener(_onPlaylistChanged);
    AudioManager.instance.imageUrlNotifier.addListener(_onImageUrlChanged);
    _updatePalette(AudioManager.instance.imageUrlNotifier.value);
  }

  void _onImageUrlChanged() {
    _updatePalette(AudioManager.instance.imageUrlNotifier.value);
  }

  Future<void> _updatePalette(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      if (mounted) setState(() { _backgroundColor = const Color(0xFF1E2E17); });
      return;
    }
    try {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 20,
      );
      if (mounted) {
        setState(() {
          _backgroundColor = paletteGenerator.dominantColor?.color ?? 
                             paletteGenerator.darkMutedColor?.color ?? 
                             const Color(0xFF1E2E17);
        });
      }
    } catch (e) {
      debugPrint("Error extracting palette: $e");
    }
  }

  Future<void> _searchAndPlay(String query) async {
    try {
      final searchResults = await AudioManager.instance.yt.search.search(query);
      if (searchResults.isNotEmpty) {
        final video = searchResults.firstWhere((v) {
          final duration = v.duration;
          if (duration == null) return false;
          return duration.inMinutes >= 2 && duration.inMinutes <= 4;
        }, orElse: () => searchResults.first);
        await AudioManager.instance.playYoutubeVideo(
          videoId: video.id.value,
          title: video.title,
          artist: video.author,
          imageUrl: video.thumbnails.highResUrl,
        );
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  void _onPlayerStateChanged() {
    if (mounted) {
      setState(() {
        _isPlaying = AudioManager.instance.isPlayingNotifier.value;
        _volume = AudioManager.instance.audioPlayer.volume;
      });
    }
  }

  void _onPlaylistChanged() {
    if (mounted) {
      setState(() {});
      if (_currentIndex != 0 && _pageController.hasClients) {
        _currentIndex = 0;
        _pageController.jumpToPage(0);
      }
    }
  }

  Future<void> _playFromList(int index) async {
    final upcoming = AudioManager.instance.upcomingSongsNotifier.value;
    if (index < 0 || index >= upcoming.length) return;

    setState(() => _currentIndex = index);

    final track = upcoming[index];
    final videoId = track['videoId'] as String;

    if (videoId.isNotEmpty) {
      await AudioManager.instance.playYoutubeVideo(
        videoId: videoId,
        title: track['title'] as String,
        artist: track['artist'] as String,
        imageUrl: track['imageUrl'] as String,
      );
    } else if (track['audioUrl'] != null) {
      await AudioManager.instance.playMusic(
        audioUrl: track['audioUrl'] as String,
        title: track['title'] as String,
        artist: track['artist'] as String,
        imageUrl: track['imageUrl'] as String,
      );
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null || duration.inMilliseconds < 0 || duration.inHours > 99) {
      return "0:00";
    }
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = duration.inMinutes.toString();
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    AudioManager.instance.isPlayingNotifier.removeListener(_onPlayerStateChanged);
    AudioManager.instance.upcomingSongsNotifier.removeListener(_onPlaylistChanged);
    AudioManager.instance.imageUrlNotifier.removeListener(_onImageUrlChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = AudioManager.instance.upcomingSongsNotifier.value;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // We change viewport fraction dynamically based on device
    if (_pageController.hasClients) {
       // A bit hacky but keeps it neat
       // _pageController is final, so we just use a different scale in builder
    }

    return Scaffold(
      backgroundColor: Colors.black, // Fallback underlying color
      body: Stack(
        children: [
          // 1. Dynamic Animated Gradient Background adapting to album art color
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _backgroundColor,
                    _backgroundColor.withOpacity(0.5),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // 2. Responsive UI Content
          isDesktop
              ? _buildDesktopLayout(upcoming, context)
              : _buildMobileLayout(upcoming, context),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE LAYOUT
  // ==========================================
  Widget _buildMobileLayout(List<Map<String, dynamic>> upcoming, BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Top Bar
          _buildTopBar(),
          
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                
                if (details.primaryVelocity! > 300) {
                  // Swipe Kanan (Sebelumnya)
                  if (_currentIndex > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    // Kalau di awal, ulangi lagunya / skip previous
                    AudioManager.instance.playPrevious();
                  }
                } else if (details.primaryVelocity! < -300) {
                  // Swipe Kiri (Selanjutnya)
                  if (_currentIndex < upcoming.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    // Paksa next track logic kalau sudah di ujung
                    AudioManager.instance.playNext();
                  }
                }
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                   const SizedBox(height: 20),
                   // Album Art Carousel
                   _buildAlbumCarousel(upcoming, context, 0.85, 340),
                   
                   const SizedBox(height: 32),
                   // Title & Artist
                   _buildTitleAndArtist(),
                   
                   const SizedBox(height: 24),
                   // Progress Bar
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     child: _buildProgressBar(true),
                   ),
                   
                   const SizedBox(height: 16),
                   // Playback Controls
                   _buildPlaybackControls(true),

                   const SizedBox(height: 32),
                   // Recommendations
                   _buildRecommendations(upcoming),
                 ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (Spotify-style with bottom bar)
  // ==========================================
  Widget _buildDesktopLayout(List<Map<String, dynamic>> upcoming, BuildContext context) {
    return Column(
      children: [
        // Main Scrollable Area
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 40),
                
                // Centered Album Art
                _buildAlbumCarousel(upcoming, context, 0.4, 400),
                
                const SizedBox(height: 50),
                
                // Recommendations directly under picture
                _buildRecommendations(upcoming),
              ],
            ),
          ),
        ),

        // Pinned Bottom Playback Bar
        Container(
          height: 90,
          color: Colors.black.withOpacity(0.85), // Solid dark bottom bar spanning full width
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Left: Info
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: AudioManager.instance.imageUrlNotifier,
                      builder: (context, imageUrl, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          imageUrl ?? 'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?q=80',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56, height: 56, color: Colors.white10,
                            child: const Icon(Icons.music_note, color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValueListenableBuilder<String?>(
                            valueListenable: AudioManager.instance.titleNotifier,
                            builder: (context, title, _) => Text(
                              title ?? 'Title',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ValueListenableBuilder<String?>(
                            valueListenable: AudioManager.instance.artistNotifier,
                            builder: (context, artist, _) => Text(
                              artist ?? 'Artist',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite_border, color: Colors.white70, size: 20),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Center: Controls & Progress
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPlaybackControls(false),
                    const SizedBox(height: 4),
                    _buildProgressBar(false),
                  ],
                ),
              ),

              // Right: Extra Tools (Volume)
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(icon: const Icon(Icons.mic_none, color: Colors.white70, size: 20), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.queue_music, color: Colors.white70, size: 20), onPressed: () {}),
                    // Minimized volume support
                    GestureDetector(
                      onTap: () {
                        setState(() => _showVolumeSlider = !_showVolumeSlider);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.volume_up, color: Colors.white70, size: 20),
                      ),
                    ),
                    if (_showVolumeSlider)
                      SizedBox(
                        width: 100,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _volume,
                            onChanged: (v) {
                              setState(() => _volume = v);
                              AudioManager.instance.audioPlayer.setVolume(v);
                            },
                          ),
                        ),
                      ),
                    IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 20), onPressed: () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // SHARED WIDGET COMPONENTS
  // ==========================================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Column(
            children: [
              Text("PLAYING FROM THE APP", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
              SizedBox(height: 4),
              Text("Famotion", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerRight,
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCarousel(List<Map<String, dynamic>> upcoming, BuildContext context, double mobileScale, double maxHeight) {
    if (upcoming.isEmpty) {
      return SizedBox(
        height: maxHeight, 
        child: const Center(child: CircularProgressIndicator(color: Colors.white))
      );
    }
    
    // Adjust height intelligently based on screen width/height for both desktop and mobile
    final h = math.min(MediaQuery.of(context).size.width * 0.85, maxHeight);

    return SizedBox(
      height: h,
      child: PageView.builder(
        controller: _pageController, // using the 0.85 fraction viewport
        itemCount: upcoming.length,
        onPageChanged: (index) {
          if (index != _currentIndex) {
             _playFromList(index);
          }
        },
        itemBuilder: (context, index) {
          final track = upcoming[index];
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
              }
              // If desktop, apply extra manual shrinking so it doesn't look gigantic in the 0.85 viewport
              final scaleMultiplier = MediaQuery.of(context).size.width > 600 ? mobileScale : 1.0;
              
              return Center(
                child: Transform.scale(
                  scale: value * scaleMultiplier,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 20),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        track['imageUrl'] ?? '',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white10,
                          child: const Icon(Icons.music_note, color: Colors.white54, size: 80),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTitleAndArtist() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: AudioManager.instance.titleNotifier,
            builder: (context, title, _) => Text(
              title ?? 'Loading...',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String?>(
            valueListenable: AudioManager.instance.artistNotifier,
            builder: (context, artist, _) => Text(
              artist ?? 'Waiting for track info',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(bool isMobile) {
    return StreamBuilder<Duration>(
      stream: AudioManager.instance.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: AudioManager.instance.audioPlayer.durationStream,
          builder: (context, durationSnapshot) {
            Duration duration = durationSnapshot.data ?? Duration.zero;

            // Fallback ke durasi aslinya jika stream just_audio belum siap atau nyangkut di 0:00
            final upcoming = AudioManager.instance.upcomingSongsNotifier.value;
            if (_currentIndex >= 0 && _currentIndex < upcoming.length) {
              final track = upcoming[_currentIndex];
              if (track['durationMs'] != null && 
                  (duration.inMilliseconds == 0 || duration.inHours > 99)) {
                duration = Duration(milliseconds: track['durationMs'] as int);
              }
            }

            final positionMill = position.inMilliseconds.toDouble();
            final durationMill = duration.inMilliseconds.toDouble();
            double sliderValue = 0.0;
            if (durationMill > 0 && positionMill <= durationMill && positionMill >= 0) {
              sliderValue = positionMill / durationMill;
            }

            if (isMobile) {
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: sliderValue,
                      onChanged: (value) {
                        AudioManager.instance.audioPlayer.seek(Duration(milliseconds: (value * durationMill).round()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Desktop Row layout
              return Row(
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: sliderValue,
                        onChanged: (value) {
                          AudioManager.instance.audioPlayer.seek(Duration(milliseconds: (value * durationMill).round()));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              );
            }
          },
        );
      },
    );
  }

  Widget _buildPlaybackControls(bool isMobile) {
    double sizeMult = isMobile ? 1.4 : 1.0; 
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle, color: Colors.white70, size: 24 * sizeMult),
          onPressed: () {},
        ),
        SizedBox(width: isMobile ? 16 : 8),
        IconButton(
          icon: Icon(Icons.skip_previous, color: Colors.white, size: 36 * sizeMult),
          onPressed: () {
            // Check if playing position > 3 seconds, if yes, seek to 0. Else play previous song.
            AudioManager.instance.playPrevious();
          },
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: 56 * sizeMult,
          height: 56 * sizeMult,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 32 * sizeMult),
            onPressed: () {
              if (_isPlaying) {
                AudioManager.instance.audioPlayer.pause();
              } else {
                AudioManager.instance.audioPlayer.play();
              }
            },
          ),
        ),
        IconButton(
          icon: Icon(Icons.skip_next, color: Colors.white, size: 36 * sizeMult),
          onPressed: () {
            AudioManager.instance.playNext();
          },
        ),
        SizedBox(width: isMobile ? 16 : 8),
        StreamBuilder<LoopMode>(
          stream: AudioManager.instance.audioPlayer.loopModeStream,
          builder: (context, snapshot) {
            final loopMode = snapshot.data ?? LoopMode.off;
            final isRepeatOne = loopMode == LoopMode.one;
            return IconButton(
              icon: Icon(
                isRepeatOne ? Icons.repeat_one : Icons.repeat,
                color: isRepeatOne ? Colors.greenAccent : Colors.white70,
                size: 24 * sizeMult,
              ),
              onPressed: () {
                if (isRepeatOne) {
                  AudioManager.instance.audioPlayer.setLoopMode(LoopMode.off);
                } else {
                  AudioManager.instance.audioPlayer.setLoopMode(LoopMode.one);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecommendations(List<Map<String, dynamic>> upcoming) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            "Rekomendasi Mood Hari Ini",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        if (upcoming.length > 1)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32),
            itemCount: upcoming.length - 1, // Skip current track
            itemBuilder: (context, index) {
              final trackIndex = index + 1;
              final track = upcoming[trackIndex];
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      trackIndex,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            track['imageUrl'] ?? '',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white54, size: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track['title'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track['artist'] ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.more_horiz, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
