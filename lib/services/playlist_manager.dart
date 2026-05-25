import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:http/http.dart' as http;
import '../utils/auth_helper.dart';

class PlaylistManager {
  static final PlaylistManager instance = PlaylistManager._internal();
  PlaylistManager._internal();

  static const String _likedSongsKey = 'liked_songs';
  static const String _playlistsKey = 'custom_playlists';

  final ValueNotifier<List<Map<String, dynamic>>> likedSongsNotifier = ValueNotifier([]);
  final ValueNotifier<Map<String, List<Map<String, dynamic>>>> playlistsNotifier = ValueNotifier({});

  Future<void> init() async {
    _loadLikedSongs();
    _loadPlaylists();
  }

  void _loadLikedSongs() {
    final String data = getStringAsync(_likedSongsKey, defaultValue: "");
    if (data.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        likedSongsNotifier.value = decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint("Error loading liked songs: $e");
      }
    }
  }

  void _loadPlaylists() {
    final String data = getStringAsync(_playlistsKey, defaultValue: "");
    if (data.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(data);
        final Map<String, List<Map<String, dynamic>>> mapped = {};
        decoded.forEach((key, value) {
          mapped[key] = (value as List).cast<Map<String, dynamic>>();
        });
        playlistsNotifier.value = mapped;
      } catch (e) {
        debugPrint("Error loading playlists: $e");
      }
    }
  }

  // --- Cloud Sync Methods ---

  Future<void> syncFromCloud() async {
    final String userId = getStringAsync('userId', defaultValue: "");
    if (userId.isEmpty) return;

    final url = Uri.parse(getBackendUrl('/api/playlist/$userId'));
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded != null) {
          if (decoded['likedSongs'] != null) {
            likedSongsNotifier.value = (decoded['likedSongs'] as List).cast<Map<String, dynamic>>();
            await _saveLikedSongsLocalOnly();
          }
          if (decoded['playlists'] != null) {
            final Map<String, dynamic> playlistsData = decoded['playlists'];
            final Map<String, List<Map<String, dynamic>>> mapped = {};
            playlistsData.forEach((key, value) {
               mapped[key] = (value as List).cast<Map<String, dynamic>>();
            });
            playlistsNotifier.value = mapped;
            await _savePlaylistsLocalOnly();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching cloud playlist: $e");
    }
  }

  Future<void> _backupToCloud() async {
    final String userId = getStringAsync('userId', defaultValue: "");
    if (userId.isEmpty) return;

    final url = Uri.parse(getBackendUrl('/api/playlist/sync'));
    try {
      await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
          'userId': userId,
          'likedSongs': likedSongsNotifier.value,
          'playlists': playlistsNotifier.value,
        }));
    } catch (e) {
      debugPrint("Error backup to cloud: $e");
    }
  }

  // --- Local Save Methods ---

  Future<void> _saveLikedSongsLocalOnly() async {
    final String data = jsonEncode(likedSongsNotifier.value);
    await setValue(_likedSongsKey, data);
    likedSongsNotifier.value = List.from(likedSongsNotifier.value);
  }

  Future<void> _savePlaylistsLocalOnly() async {
    final String data = jsonEncode(playlistsNotifier.value);
    await setValue(_playlistsKey, data);
    playlistsNotifier.value = Map.from(playlistsNotifier.value);
  }

  Future<void> _saveLikedSongs() async {
    await _saveLikedSongsLocalOnly();
    _backupToCloud(); // Fire and forget (tanpa await agar aplikasi cepat)
  }

  Future<void> _savePlaylists() async {
    await _savePlaylistsLocalOnly();
    _backupToCloud(); // Fire and forget
  }

  // --- Liked Songs Methods ---
  bool isLiked(String? idOrUrl) {
    if (idOrUrl == null || idOrUrl.isEmpty) return false;
    return likedSongsNotifier.value.any((track) => track['videoId'] == idOrUrl || track['audioUrl'] == idOrUrl);
  }

  Future<bool> toggleLike(Map<String, dynamic> track) async {
    final idOrUrl = track['videoId'] ?? track['audioUrl'];
    if (idOrUrl == null || idOrUrl.isEmpty) return false;

    bool resultIsLiked = false;

    if (isLiked(idOrUrl)) {
      likedSongsNotifier.value.removeWhere((t) => t['videoId'] == idOrUrl || t['audioUrl'] == idOrUrl);
      resultIsLiked = false;
    } else {
      likedSongsNotifier.value.insert(0, track); // Add to top
      resultIsLiked = true;
    }
    await _saveLikedSongs();
    return resultIsLiked;
  }

  // --- Playlist Methods ---
  Future<void> createPlaylist(String name) async {
    if (name.trim().isEmpty) return;
    if (!playlistsNotifier.value.containsKey(name)) {
      playlistsNotifier.value[name] = [];
      await _savePlaylists();
    }
  }

  Future<void> addToPlaylist(String playlistName, Map<String, dynamic> track) async {
    if (!playlistsNotifier.value.containsKey(playlistName)) {
      await createPlaylist(playlistName);
    }
    
    final idOrUrl = track['videoId'] ?? track['audioUrl'];
    if (idOrUrl == null || idOrUrl.isEmpty) return;

    final currentList = playlistsNotifier.value[playlistName]!;
    
    // Check if already exists in this playlist
    if (!currentList.any((t) => t['videoId'] == idOrUrl || t['audioUrl'] == idOrUrl)) {
      currentList.insert(0, track);
      await _savePlaylists();
    }
  }

  Future<void> removeFromPlaylist(String playlistName, String idOrUrl) async {
    if (!playlistsNotifier.value.containsKey(playlistName)) return;
    
    playlistsNotifier.value[playlistName]?.removeWhere((t) => t['videoId'] == idOrUrl || t['audioUrl'] == idOrUrl);
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String name) async {
    final current = Map<String, List<Map<String, dynamic>>>.from(playlistsNotifier.value);
    current.remove(name);
    playlistsNotifier.value = current;
    await _savePlaylists();
  }
}
