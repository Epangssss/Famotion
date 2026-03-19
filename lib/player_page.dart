import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

class PlayerPage extends StatefulWidget {
  final String videoId;
  final String title;
  final String? searchQuery;

  const PlayerPage({
    super.key,
    required this.videoId,
    required this.title,
    this.searchQuery,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Video? _currentVideo;
  List<Video> _upcomingSongs = [];
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            // Play next song if any
            if (_upcomingSongs.isNotEmpty) {
              _playNext(_upcomingSongs.first);
            }
          }
        });
      }
    });
  }

  Future<void> _initPlayer() async {
    if (widget.videoId.isNotEmpty) {
      await _loadVideo(widget.videoId, widget.title);
    } else if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _isPlaying = false;
      });
      try {
        final searchResults = await _yt.search.search(widget.searchQuery!);
        if (searchResults.isNotEmpty) {
          final video = searchResults.firstWhere((v) {
            final duration = v.duration;
            if (duration == null) return false;
            final totalMinutes = duration.inMinutes;
            return totalMinutes >= 2 && totalMinutes <= 4;
          }, orElse: () => searchResults.first);
          
          await _loadVideo(video.id.value, video.title);
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVideo(String id, String title) async {
    setState(() {
      _isLoading = true;
      _isPlaying = false;
    });

    try {
      final video = await _yt.videos.get(id);
      
      // Get audio stream URL
      final manifest = await _yt.videos.streamsClient.getManifest(id);
      
      // Prefer mp4 container for better compatibility across platforms (like just_audio on iOS/Windows)
      final audioOnlyStreams = manifest.audioOnly;
      final mp4Streams = audioOnlyStreams.where((stream) => stream.container.name.toLowerCase() == 'mp4');
      final audioInfo = mp4Streams.isNotEmpty 
          ? mp4Streams.withHighestBitrate() 
          : audioOnlyStreams.withHighestBitrate();
          
      // Get related/upcoming songs using search based on the author
      final searchResults = await _yt.search.search(video.author);
      // Filter for duration between 2 and 4 minutes (inclusive)
      final upcoming = searchResults.where((v) {
        if (v.id.value == id) return false;
        final duration = v.duration;
        if (duration == null) return false;
        final totalMinutes = duration.inMinutes;
        // Allows anything >= 2 minutes and < 5 minutes (i.e. up to 4:59)
        return totalMinutes >= 2 && totalMinutes <= 4;
      }).take(10).toList();

      if (mounted) {
        setState(() {
          _currentVideo = video;
          _upcomingSongs = upcoming;
          _isLoading = false;
        });
        
        await _audioPlayer.setUrl(audioInfo.url.toString());
        await _audioPlayer.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load track: $e')),
        );
      }
    }
  }

  Future<void> _playNext(Video nextVideo) async {
    await _audioPlayer.stop();
    await _loadVideo(nextVideo.id.value, nextVideo.title);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _yt.close();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // Shared color palette from dashboard
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
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.keyboard_arrow_down, color: textDark, size: 30),
                      ),
                    ),
                    const Text(
                      "Sedang Diputar",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 46), // For visual balance
                  ],
                ),
              ),

              // Player Content
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: accentGold))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            // IMAGE (Central focus)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Image.network(
                                  _currentVideo?.thumbnails.highResUrl ?? '',
                                  width: MediaQuery.of(context).size.width * 0.8,
                                  height: MediaQuery.of(context).size.width * 0.8,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: MediaQuery.of(context).size.width * 0.8,
                                    height: MediaQuery.of(context).size.width * 0.8,
                                    color: Colors.white10,
                                    child: const Icon(Icons.music_note, color: Colors.white54, size: 100),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 36),
                            
                            // Title & Author
                            Text(
                              _currentVideo?.title ?? widget.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentVideo?.author ?? 'Unknown Artist',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Progress Bar
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      activeTrackColor: accentGold,
                                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                                      thumbColor: accentGold,
                                      overlayColor: accentGold.withOpacity(0.2),
                                    ),
                                    child: Slider(
                                      value: _position.inSeconds.toDouble(),
                                      min: 0.0,
                                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
                                      onChanged: (value) {
                                        _audioPlayer.seek(Duration(seconds: value.toInt()));
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // PLAY BUTTONS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.shuffle, color: Colors.white.withOpacity(0.7), size: 28),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                                  onPressed: () {
                                    // Not implemented for previous song yet
                                  },
                                ),
                                GestureDetector(
                                  onTap: () {
                                    if (_isPlaying) {
                                      _audioPlayer.pause();
                                    } else {
                                      _audioPlayer.play();
                                    }
                                  },
                                  child: Container(
                                    width: 75,
                                    height: 75,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentGold,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x40D8A854),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                                  onPressed: () {
                                    if (_upcomingSongs.isNotEmpty) {
                                      _playNext(_upcomingSongs.first);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.repeat, color: Colors.white.withOpacity(0.7), size: 28),
                                  onPressed: () {},
                                ),
                              ],
                            ),

                            const SizedBox(height: 40),
                            
                            // UPCOMING SONGS (Lanjutan Lagu)
                            Row(
                              children: [
                                const Text(
                                  "Lagu Selanjutnya",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.queue_music, color: Colors.white.withOpacity(0.6)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // List Map for Upcoming Songs
                            ..._upcomingSongs.map((video) {
                              return GestureDetector(
                                onTap: () => _playNext(video),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          video.thumbnails.mediumResUrl,
                                          width: 55,
                                          height: 55,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              video.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              video.author,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.more_vert, color: Colors.white54),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
