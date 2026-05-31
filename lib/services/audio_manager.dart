import 'dart:io' show Platform;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../utils/auth_helper.dart';

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
        // Kita tidak lagi memantau ProcessingState.completed di sini 
        // karena ConcatenatingAudioSource otomatis pindah ke index berikutnya
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Ignored player state error: $e');
      },
    );

    // Pantau perubahan index dari just_audio (berjalan otomatis saat lagu habis, atau ditekan tombol next/prev di notifikasi)
    audioPlayer.currentIndexStream.listen((index) {
      if (index == null) return;
      final sequence = audioPlayer.sequence;
      if (index >= sequence.length) return;

      final mediaItem = sequence[index].tag as MediaItem;

      // Jika berpindah ke lagu baru (berdasarkan ID)
      if (currentUrlNotifier.value != mediaItem.id) {
        // 1. Masukkan lagu yang lama ke history
        if (currentUrlNotifier.value != null && currentUrlNotifier.value!.isNotEmpty) {
          _playbackHistory.add({
            'audioUrl': currentUrlNotifier.value,
            'title': titleNotifier.value,
            'artist': artistNotifier.value,
            'imageUrl': imageUrlNotifier.value,
            'durationMs': durationMsNotifier.value,
          });
          if (_playbackHistory.length > 50) _playbackHistory.removeAt(0);
        }

        // 2. Perbarui state lagu saat ini
        currentUrlNotifier.value = mediaItem.id;
        titleNotifier.value = mediaItem.title;
        artistNotifier.value = mediaItem.artist;
        imageUrlNotifier.value = mediaItem.artUri?.toString();
        // durationMs disimpan di extras saat membuat MediaItem
        durationMsNotifier.value = mediaItem.extras?['durationMs'];

        // 3. Perbarui daftar upcoming (memotong lagu-lagu sebelumnya dari antrean tampilan UI)
        List<Map<String, dynamic>> newUpcoming = [];
        for (int i = index; i < sequence.length; i++) {
          final item = sequence[i].tag as MediaItem;
          newUpcoming.add({
            'audioUrl': item.id,
            'title': item.title,
            'artist': item.artist,
            'imageUrl': item.artUri?.toString(),
            'durationMs': item.extras?['durationMs'],
            'videoId': '',
          });
        }
        upcomingSongsNotifier.value = newUpcoming;

        // 4. Jika sudah mendekati akhir antrean, fetch lebih banyak rekomendasi
        if (index >= sequence.length - 2 && sequence.length > 1) {
          _fetchRecommendations(mediaItem.title, mediaItem.artist ?? '', mediaItem.artUri?.toString() ?? '');
        }
      }
    });
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

  // Global queue preferences
  String? currentQueueGenre;
  String? currentQueueMood;

  // Shuffle state
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier<bool>(false);

  void toggleShuffle() {
    isShuffleNotifier.value = !isShuffleNotifier.value;
    if (isShuffleNotifier.value) {
      shuffleQueue();
    }
  }

  void shuffleQueue() {
    final upcoming = upcomingSongsNotifier.value;
    if (upcoming.length <= 1) return;
    final current = upcoming.first; // Pertahankan lagu yang sedang diputar di posisi 0
    final rest = upcoming.sublist(1);
    rest.shuffle();
    upcomingSongsNotifier.value = [current, ...rest];
  }

  Future<void> playMusic({
    required String audioUrl,
    required String title,
    required String artist,
    required String imageUrl,
    int? durationMs,
    bool isFromHistory = false,
    String? queueGenre,
    String? queueMood,
    List<Map<String, dynamic>>? initialQueue,
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
      
      // Update ui seketika agar gambar tidak nunggu rekomendasi selesai di-load
      if (initialQueue != null && initialQueue.isNotEmpty) {
        upcomingSongsNotifier.value = initialQueue;
      } else {
        upcomingSongsNotifier.value = [
          {
            'videoId': '',
            'audioUrl': audioUrl,
            'title': title,
            'artist': artist,
            'imageUrl': imageUrl,
            'durationMs': durationMs,
          }
        ];
      }

      // Reset current index when explicitly playing a new search/dashboard song
      // (This will be overridden if playNext or playFromPlaylist is called)
      currentIndex = 0;
      isPlayingNotifier.value = false; // will be true when playing

      if (_playRequestId != requestId) return;
      
      // Removed audioPlayer.stop() for Windows to prevent crash, BUT for Android (ExoPlayer),
      // we MUST call stop() to immediately tear down the previous HTTP connection so the VPS
      // is notified and kills the previous yt-dlp process.
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await audioPlayer.stop();
      }
      
      debugPrint('🎵 Playing: $audioUrl');
      
      // Deteksi asset lokal vs URL jaringan
      AudioSource createSource(String url, String t, String a, String img, int? dur, {String? videoId}) {
        String resolvedUrl = url;
        if (resolvedUrl.isEmpty && videoId != null && videoId.isNotEmpty) {
          if (videoId.startsWith('http://') || videoId.startsWith('https://')) {
            resolvedUrl = videoId;
          } else {
            resolvedUrl = getMusicApiUrl('/stream?videoId=$videoId');
          }
        }
        
        resolvedUrl = interceptLocalStreamUrl(resolvedUrl);
        final mediaItem = MediaItem(
          id: resolvedUrl,
          album: "Famotion",
          title: t,
          artist: a,
          artUri: Uri.tryParse(img),
          extras: {'durationMs': dur},
        );
        if (resolvedUrl.startsWith('assets/')) {
          return AudioSource.asset(resolvedUrl, tag: mediaItem);
        } else {
          return AudioSource.uri(
            Uri.parse(resolvedUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'},
            tag: mediaItem,
          );
        }
      }

      // Bangun playlist baru yang mencakup History dan lagu saat ini
      List<AudioSource> playlistChildren = [];
      
      // Tambahkan history ke playlist agar tombol 'Previous' berfungsi natural
      for (var prev in _playbackHistory) {
        playlistChildren.add(createSource(
            prev['audioUrl'], prev['title'], prev['artist'], prev['imageUrl'], prev['durationMs']));
      }
      
      if (initialQueue != null && initialQueue.isNotEmpty) {
        // Tambahkan seluruh queue dari initialQueue (dimulai dengan lagu saat ini di index 0)
        for (var item in initialQueue) {
          playlistChildren.add(createSource(
            item['audioUrl'] ?? '',
            item['title'] ?? '',
            item['artist'] ?? '',
            item['imageUrl'] ?? '',
            item['durationMs'],
            videoId: item['videoId'],
          ));
        }
      } else {
        // Tambahkan lagu yang dipilih saat ini saja
        playlistChildren.add(createSource(audioUrl, title, artist, imageUrl, durationMs));
      }

      try {
        // Mainkan tepat di lagu yang baru saja ditambahkan (di akhir list history)
        await audioPlayer.setAudioSources(playlistChildren, initialIndex: _playbackHistory.length);
      } catch (sourceError) {
        debugPrint('⚠️ setAudioSources gagal: $sourceError');
      }
      
      // Update global queue preferences so it persists through the playlist
      if (queueGenre != null) currentQueueGenre = queueGenre;
      if (queueMood != null) currentQueueMood = queueMood;
      
      if (_playRequestId != requestId) return;
      debugPrint('▶️ Starting playback...');
      await audioPlayer.play();

      // Rekam jejak lagu ke Server Cloud
      AuthHelper().saveListeningHistory(audioUrl, title, artist, imageUrl, durationMs ?? 0);

      // Fire and forget recommendation fetcher jika initialQueue kosong
      if (initialQueue == null || initialQueue.isEmpty) {
        _fetchRecommendations(title, artist, imageUrl);
      }
    } catch (e) {
      if (_playRequestId == requestId) {
        debugPrint("Error playing music: $e");
      }
    }
  }

  Future<void> _fetchRecommendations(
      String currentTitle, String currentArtist, String currentImageUrl) async {
    try {
      String queryPayload;

      if (currentQueueMood != null && currentQueueMood!.isNotEmpty) {
        // Mood dari Dashboard tersedia → gunakan mood + genre
        queryPayload = currentQueueMood!;
        if (currentQueueGenre != null && currentQueueGenre!.isNotEmpty) {
          queryPayload += ' ${currentQueueGenre!.toLowerCase()}';
        }
      } else {
        // Tidak ada mood (misalnya dari Search) → gunakan artis lagu yang sedang diputar
        // Ini memastikan rekomendasi relevan dengan lagu yang dipilih user
        queryPayload = currentArtist.isNotEmpty ? currentArtist : currentTitle;
      }

      final encodedPayload = Uri.encodeComponent(queryPayload);
      final uri = Uri.parse(getMusicApiUrl('/music?q=$encodedPayload&limit=25'));
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
        
        newUpcomingList.add({
          'videoId': '', // pakai audioUrl langsung, bukan re-fetch video id
          'audioUrl': streamUrl,
          'title': song['title'] ?? 'Unknown',
          'artist': song['artist'] ?? 'Unknown',
          'imageUrl': song['thumbnail'] ?? '',
          'durationMs': parseDuration(song['duration']),
        });
      }

      // Shuffle lagu-lagu rekomendasi (kecuali lagu saat ini) agar pemutaran terasa dinamis
      if (newUpcomingList.length > 1) {
        final currentTrack = newUpcomingList.removeAt(0);
        newUpcomingList.shuffle();
        newUpcomingList.insert(0, currentTrack);
      }

      upcomingSongsNotifier.value = newUpcomingList;

      // Sisipkan lagu-lagu rekomendasi ini ke dalam pemutar musik agar bisa dimainkan otomatis
      List<AudioSource> upcomingSources = [];
      for (int i = 1; i < newUpcomingList.length; i++) {
        final t = newUpcomingList[i];
        String resolvedUrl = t['audioUrl'] ?? '';
        resolvedUrl = interceptLocalStreamUrl(resolvedUrl);

        final mediaItem = MediaItem(
          id: resolvedUrl,
          album: "Famotion",
          title: t['title'],
          artist: t['artist'],
          artUri: Uri.tryParse(t['imageUrl']),
          extras: {'durationMs': t['durationMs']},
        );
        if (resolvedUrl.startsWith('assets/')) {
          upcomingSources.add(AudioSource.asset(resolvedUrl, tag: mediaItem));
        } else {
          upcomingSources.add(AudioSource.uri(
            Uri.parse(resolvedUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'},
            tag: mediaItem,
          ));
        }
      }
      try {
        await audioPlayer.addAudioSources(upcomingSources);
      } catch (e) {
        debugPrint('⚠️ addAudioSources gagal: $e');
      }
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
    String? queueGenre,
    String? queueMood,
    List<Map<String, dynamic>>? initialQueue,
  }) async {
    final int requestId = ++_playRequestId;
    try {
      String audioUrl;
      if (videoId.startsWith('http://') || videoId.startsWith('https://')) {
        audioUrl = videoId;
      } else {
        audioUrl = getMusicApiUrl('/stream?videoId=$videoId');
      }

      if (_playRequestId != requestId) return;

      await playMusic(
        audioUrl: audioUrl,
        title: title,
        artist: artist,
        imageUrl: imageUrl,
        durationMs: durationMs,
        queueGenre: queueGenre,
        queueMood: queueMood,
        initialQueue: initialQueue,
      );
    } catch (e) {
      debugPrint("Failed to play youtube video: $e");
    }
  }

  Future<void> jumpToQueueIndex(int queueIndex) async {
    final sequence = audioPlayer.sequence;
    
    // Indeks lagu saat ini di dalam sequence
    final currentSeqIndex = audioPlayer.currentIndex ?? 0;
    
    // Target index di sequence adalah: index lagu saat ini + queueIndex
    // Karena queueIndex 0 adalah lagu yang sedang diputar
    final targetSeqIndex = currentSeqIndex + queueIndex;
    if (targetSeqIndex >= 0 && targetSeqIndex < sequence.length) {
      await audioPlayer.seek(Duration.zero, index: targetSeqIndex);
    }
  }

  Future<void> playNext() async {
    if (audioPlayer.hasNext) {
      await audioPlayer.seekToNext();
    } else {
      // Jika queue kosong, fetch rekomendasi baru
      await _fetchRecommendations(titleNotifier.value ?? '', artistNotifier.value ?? '', imageUrlNotifier.value ?? '');
      if (audioPlayer.hasNext) {
        await audioPlayer.seekToNext();
      }
    }
  }

  Future<void> playPrevious() async {
    // Jika lagu sudah berjalan lebih dari 3 detik, restart lagu tersebut
    if (audioPlayer.position.inSeconds > 3) {
      await audioPlayer.seek(Duration.zero);
    } else if (audioPlayer.hasPrevious) {
      await audioPlayer.seekToPrevious();
    } else {
      await audioPlayer.seek(Duration.zero);
    }
  }

  Future<void> stopAndClear() async {
    await audioPlayer.stop();
    isPlayingNotifier.value = false;
    currentUrlNotifier.value = null;
    titleNotifier.value = null;
    artistNotifier.value = null;
    imageUrlNotifier.value = null;
    durationMsNotifier.value = null;
    upcomingSongsNotifier.value = [];
  }

  void dispose() {
    audioPlayer.dispose();
    yt.close();
  }
}
