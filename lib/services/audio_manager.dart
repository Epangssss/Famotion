import 'dart:io' show Platform;
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class AudioManager {
  // Singleton pattern
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;

  AudioManager._internal() {
    audioPlayer = AudioPlayer();

    // Catch native backend errors so they don't crash the Dart isolate
    audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        debugPrint('Ignored playback event stream error: $e');
      },
    );

    audioPlayer.playerStateStream.listen(
      (state) {
        isPlayingNotifier.value = state.playing;
        if (state.processingState == ProcessingState.completed) {
          final position = audioPlayer.position.inMilliseconds;
          final duration = audioPlayer.duration?.inMilliseconds ?? 0;
          
          if (duration > 0 && position >= duration - 2000) {
            isPlayingNotifier.value = false;
            playNext();
          } else {
            isPlayingNotifier.value = false;
          }
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Ignored player state error: $e');
      },
    );
  }

  late final AudioPlayer audioPlayer;
  final YoutubeExplode yt = YoutubeExplode();

  // Notifiers so that the UI can update when these change
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentUrlNotifier =
      ValueNotifier<String?>(null);

  // Title, artist, image for UI display
  final ValueNotifier<String?> titleNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> artistNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> imageUrlNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<int?> durationMsNotifier = ValueNotifier<int?>(null);

  // History stack for previous tracks
  final List<Map<String, dynamic>> _playbackHistory = [];

  // Upcoming tracks / recommendations
  final ValueNotifier<List<Map<String, dynamic>>> upcomingSongsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  int currentIndex = 0;
  int _playRequestId = 0;

  Future<void> playMusic({
    required String audioUrl,
    required String title,
    required String artist,
    required String imageUrl,
    int? durationMs,
    bool isFromHistory = false,
  }) async {
    final int requestId = ++_playRequestId;

    try {
      if (currentUrlNotifier.value == audioUrl && isPlayingNotifier.value) {
        await audioPlayer.pause();
        return;
      } else if (currentUrlNotifier.value == audioUrl &&
          !isPlayingNotifier.value) {
        await audioPlayer.play();
        return;
      }

      // Save to history before changing track, provided it's not a go-back action
      if (!isFromHistory && currentUrlNotifier.value != null && currentUrlNotifier.value != audioUrl) {
        _playbackHistory.add({
          'audioUrl': currentUrlNotifier.value,
          'title': titleNotifier.value,
          'artist': artistNotifier.value,
          'imageUrl': imageUrlNotifier.value,
          'durationMs': durationMsNotifier.value,
        });
        if (_playbackHistory.length > 50) _playbackHistory.removeAt(0);
      }

      currentUrlNotifier.value = audioUrl;
      titleNotifier.value = title;
      artistNotifier.value = artist;
      imageUrlNotifier.value = imageUrl;
      durationMsNotifier.value = durationMs;
      // Reset current index when explicitly playing a new search/dashboard song
      // (This will be overridden if playNext or playFromPlaylist is called)
      currentIndex = 0;
      isPlayingNotifier.value = false; // will be true when playing

      if (_playRequestId != requestId) return;
      
      // Removed audioPlayer.stop(); because setUrl implicitly does it.
      // Calling stop() immediately followed by setUrl() crashes the Windows Media Foundation backend.
      await audioPlayer.setUrl(audioUrl);
      
      if (_playRequestId != requestId) return;
      await audioPlayer.play();

      // Fire and forget recommendation fetcher
      // Gunakan backend api ketimbang youtube dart search agar lebih variatif
      _fetchRecommendations(title, artist, imageUrl);
    } catch (e) {
      if (_playRequestId == requestId) {
        debugPrint("Error playing music: $e");
      }
    }
  }

  Future<void> _fetchRecommendations(
      String currentTitle, String currentArtist, String currentImageUrl) async {
    try {
      // Pilih emotion secara acak supaya hasilnya selalu variatif dan tidak stuck 1 artis.
      const emotions = ['happy', 'sad', 'stress', 'angry'];
      final emotion = emotions[Random().nextInt(emotions.length)];

      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final uri = Uri.parse('http://$host:3000/music?emotion=$emotion&limit=25');
      final response = await http.get(uri);

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final List<dynamic> songs = (data['songs'] ?? []) as List;

      List<Map<String, dynamic>> newUpcomingList = [];
      // Prepend current track
      newUpcomingList.add({
        'videoId': '',
        'title': currentTitle,
        'artist': currentArtist,
        'imageUrl': currentImageUrl,
        'durationMs': durationMsNotifier.value,
      });

      int parseDuration(String? dur) {
        if (dur == null || dur.isEmpty) return 0;
        final p = dur.split(':');
        try {
          if (p.length == 2) return (int.parse(p[0]) * 60 + int.parse(p[1])) * 1000;
          if (p.length == 3) return (int.parse(p[0]) * 3600 + int.parse(p[1]) * 60 + int.parse(p[2])) * 1000;
        } catch (_) {}
        return 0;
      }

      for (var song in songs) {
        if (song['title'] == currentTitle) continue; // skip lagu yang sama
        final String streamUrl = song['stream_url'] ?? '';
        // Ubah localhost ke 10.0.2.2 kalau running di Android
        final String adjustedUrl = Platform.isAndroid
            ? streamUrl.replaceAll('localhost', '10.0.2.2')
            : streamUrl;
        newUpcomingList.add({
          'videoId': '', // pakai audioUrl langsung, bukan re-fetch video id
          'audioUrl': adjustedUrl,
          'title': song['title'] ?? 'Unknown',
          'artist': song['artist'] ?? 'Unknown',
          'imageUrl': song['thumbnail'] ?? '',
          'durationMs': parseDuration(song['duration']),
        });
      }

      upcomingSongsNotifier.value = newUpcomingList;
    } catch (e) {
      debugPrint('Failed to fetch recommendations from backend: $e');
    }
  }

  Future<void> playYoutubeVideo({
    required String videoId,
    required String title,
    required String artist,
    required String imageUrl,
    int? durationMs,
  }) async {
    final int requestId = ++_playRequestId;
    try {
      // Menggunakan backend Node.js untuk bypass youtube_explode_dart error.
      final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      final String audioUrl = "http://$host:3000/stream?videoId=$videoId";

      if (_playRequestId != requestId) return;

      await playMusic(
        audioUrl: audioUrl,
        title: title,
        artist: artist,
        imageUrl: imageUrl,
        durationMs: durationMs,
      );
    } catch (e) {
      debugPrint("Failed to play youtube video: $e");
    }
  }

  Future<void> playNext() async {
    final upcoming = upcomingSongsNotifier.value;
    if (upcoming.length <= 1) return;

    // Pilih lagu acak, excludes lagu yang sedang diputar (index 0 selalu current)
    int randomIndex;
    do {
      randomIndex = 1 + Random().nextInt(upcoming.length - 1);
    } while (randomIndex == currentIndex && upcoming.length > 2);

    final track = upcoming[randomIndex];

    // Update notifier langsung agar UI album art dll berubah seketika tanpa menunggu API
    List<Map<String, dynamic>> newUpcomingList = List.from(upcoming);
    newUpcomingList.removeAt(randomIndex);
    newUpcomingList.insert(0, track);
    upcomingSongsNotifier.value = newUpcomingList;
    
    // Index 0 adalah track yang baru dipilih
    currentIndex = 0;

    final videoId = track['videoId'] as String?;

    if (videoId != null && videoId.isNotEmpty) {
      await playYoutubeVideo(
        videoId: videoId,
        title: track['title'] as String,
        artist: track['artist'] as String,
        imageUrl: track['imageUrl'] as String,
      );
    } else if (track['audioUrl'] != null) {
      await playMusic(
        audioUrl: track['audioUrl'] as String,
        title: track['title'] as String,
        artist: track['artist'] as String,
        imageUrl: track['imageUrl'] as String,
        durationMs: track['durationMs'] as int?,
      );
    }
  }

  Future<void> playPrevious() async {
    // If audio has played for more than 3 seconds or no history, just seek to start
    if (audioPlayer.position.inSeconds > 3 || _playbackHistory.isEmpty) {
      await audioPlayer.seek(Duration.zero);
      return;
    }

    final prevTrack = _playbackHistory.removeLast();
    
    // UI update helper: re-insert it as index 0 in upcoming list so the view jumps smoothly
    final upcoming = upcomingSongsNotifier.value;
    List<Map<String, dynamic>> newUpcomingList = List.from(upcoming);
    newUpcomingList.insert(0, {
      'videoId': '', 
      'audioUrl': prevTrack['audioUrl'],
      'title': prevTrack['title'],
      'artist': prevTrack['artist'],
      'imageUrl': prevTrack['imageUrl'],
      'durationMs': prevTrack['durationMs'],
    });
    upcomingSongsNotifier.value = newUpcomingList;
    currentIndex = 0;

    await playMusic(
      audioUrl: prevTrack['audioUrl'] as String,
      title: prevTrack['title'] as String,
      artist: prevTrack['artist'] as String,
      imageUrl: prevTrack['imageUrl'] as String,
      durationMs: prevTrack['durationMs'] as int?,
      isFromHistory: true, // prevents it from being added to history again
    );
  }

  void dispose() {
    audioPlayer.dispose();
    yt.close();
  }
}
