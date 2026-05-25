import 'package:flutter/material.dart';
import '../services/playlist_manager.dart';
import '../services/audio_manager.dart';
import '../player_page.dart';
import '../utils/notification_helper.dart';

class MPLibraryScreen extends StatefulWidget {
  const MPLibraryScreen({super.key});

  @override
  State<MPLibraryScreen> createState() => _MPLibraryScreenState();
}

class _MPLibraryScreenState extends State<MPLibraryScreen> {
  static const Color bgTop = Color(0xFFDCE7CD);
  static const Color bgMid = Color(0xFF6A8A53);
  static const Color bgBottom = Color(0xFF1A2A14);
  static const Color textDark = Color(0xFF293B1F);
  static const Color accentGold = Color(0xFFD8A854);

  // 0 = Semua, 1 = Liked Songs, 2 = Playlists
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Library",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: textDark, size: 28),
                    onPressed: () => _showCreatePlaylistDialog(context),
                    tooltip: 'Buat Playlist Baru',
                  ),
                ],
              ),
            ),

            // Category Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _buildTab("Semua", 0),
                  _buildTab("Liked Songs", 1),
                  _buildTab("Playlists", 2),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: PlaylistManager.instance.likedSongsNotifier,
                builder: (context, likedSongs, _) {
                  return ValueListenableBuilder<Map<String, List<Map<String, dynamic>>>>(
                    valueListenable: PlaylistManager.instance.playlistsNotifier,
                    builder: (context, playlists, _) {
                      if (_selectedTab == 1) {
                        // Liked Songs list
                        return _buildLikedSongsList(likedSongs);
                      } else if (_selectedTab == 2) {
                        // Playlists
                        return _buildPlaylistsList(playlists);
                      } else {
                        // All: show liked songs card + playlist cards
                        return _buildAllView(likedSongs, playlists);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentGold : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentGold : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textDark.withValues(alpha: 0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ALL VIEW
  // ─────────────────────────────────────────
  Widget _buildAllView(
    List<Map<String, dynamic>> likedSongs,
    Map<String, List<Map<String, dynamic>>> playlists,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      physics: const BouncingScrollPhysics(),
      children: [
        // Liked Songs Card
        _buildCollectionCard(
          title: "Liked Songs",
          subtitle: "${likedSongs.length} lagu",
          icon: Icons.favorite,
          iconColor: const Color(0xFFD8A854),
          onTap: () => setState(() => _selectedTab = 1),
          trailing: likedSongs.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.play_circle_filled, color: accentGold, size: 36),
                  onPressed: () => _playAllLiked(likedSongs),
                )
              : null,
        ),

        const SizedBox(height: 8),

        // Custom Playlists
        ...playlists.entries.map((entry) {
          final name = entry.key;
          final tracks = entry.value;
          return _buildCollectionCard(
            title: name,
            subtitle: "${tracks.length} lagu",
            icon: Icons.queue_music,
            iconColor: const Color(0xFF6A8A53),
            onTap: () => _openPlaylistDetail(context, name, tracks),
            trailing: tracks.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.play_circle_filled, color: accentGold, size: 36),
                    onPressed: () => _playPlaylist(tracks),
                  )
                : null,
            onLongPress: () => _showDeletePlaylistDialog(context, name),
          );
        }),

        if (playlists.isEmpty && likedSongs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: Text(
                "Belum ada lagu tersimpan.\nSuka lagu? Tekan ❤️ di pemutar!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // LIKED SONGS LIST
  // ─────────────────────────────────────────
  Widget _buildLikedSongsList(List<Map<String, dynamic>> songs) {
    if (songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "Belum ada Liked Songs.\nTekan ❤️ di pemutar untuk menyimpan lagu.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Play All / Shuffle row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _playAllLiked(songs),
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text("Putar Semua", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.shuffle, color: Colors.white70, size: 28),
                onPressed: () {
                  final shuffled = List<Map<String, dynamic>>.from(songs)..shuffle();
                  _playPlaylist(shuffled);
                },
                tooltip: "Shuffle",
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: songs.length,
            itemBuilder: (context, index) => _buildTrackItem(songs[index], songs, index),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // PLAYLISTS LIST (collection cards only)
  // ─────────────────────────────────────────
  Widget _buildPlaylistsList(Map<String, List<Map<String, dynamic>>> playlists) {
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Belum ada Playlist.",
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showCreatePlaylistDialog(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Buat Playlist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      physics: const BouncingScrollPhysics(),
      children: playlists.entries.map((entry) {
        final name = entry.key;
        final tracks = entry.value;
        return _buildCollectionCard(
          title: name,
          subtitle: "${tracks.length} lagu",
          icon: Icons.queue_music,
          iconColor: const Color(0xFF6A8A53),
          onTap: () => _openPlaylistDetail(context, name, tracks),
          trailing: tracks.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.play_circle_filled, color: accentGold, size: 36),
                  onPressed: () => _playPlaylist(tracks),
                )
              : null,
          onLongPress: () => _showDeletePlaylistDialog(context, name),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────
  // COLLECTION CARD (Liked Songs / Playlist entry)
  // ─────────────────────────────────────────
  Widget _buildCollectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    Widget? trailing,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // TRACK ITEM (inside liked/playlist detail)
  // ─────────────────────────────────────────
  Widget _buildTrackItem(Map<String, dynamic> track, List<Map<String, dynamic>> allTracks, int index) {
    final title = track['title'] ?? 'Unknown';
    final artist = track['artist'] ?? 'Unknown';
    final imageUrl = track['imageUrl'] ?? '';

    return GestureDetector(
      onTap: () => _playTrack(track, allTracks, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon())
                  : _placeholderIcon(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_outline, color: accentGold, size: 30),
              onPressed: () => _playTrack(track, allTracks, index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(width: 52, height: 52, color: Colors.white10,
        child: const Icon(Icons.music_note, color: Colors.white54, size: 26));
  }

  // ─────────────────────────────────────────
  // PLAYLIST DETAIL BOTTOM SHEET
  // ─────────────────────────────────────────
  void _openPlaylistDetail(BuildContext context, String name, List<Map<String, dynamic>> tracks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2A14),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("${tracks.length} lagu", style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(width: 12),
                  if (tracks.isNotEmpty)
                    GestureDetector(
                      onTap: () { Navigator.pop(context); _playPlaylist(tracks); },
                      child: const Icon(Icons.play_circle_filled, color: accentGold, size: 36),
                    ),
                ],
              ),
            ),
            Expanded(
              child: tracks.isEmpty
                  ? const Center(child: Text("Playlist ini kosong", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: tracks.length,
                      itemBuilder: (_, i) => _buildTrackItem(tracks[i], tracks, i),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────
  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF293B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Buat Playlist Baru", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Nama playlist...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentGold),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await PlaylistManager.instance.createPlaylist(controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Buat", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF293B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Playlist", style: TextStyle(color: Colors.white)),
        content: Text("Hapus playlist \"$name\"?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await PlaylistManager.instance.deletePlaylist(name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // PLAY HELPERS
  // ─────────────────────────────────────────
  void _playTrack(Map<String, dynamic> track, List<Map<String, dynamic>> allTracks, int startIndex) {
    final videoId = track['videoId'] ?? '';
    final title = track['title'] ?? 'Unknown';
    final artist = track['artist'] ?? 'Unknown';
    final imageUrl = track['imageUrl'] ?? '';
    final durationMs = track['durationMs'] as int?;

    showSlidingInfoNotification(context, "Memutar: $title");

    // Isi queue dengan semua lagu di list, mulai dari yang dipilih
    final reordered = [
      ...allTracks.sublist(startIndex),
      ...allTracks.sublist(0, startIndex),
    ];
    AudioManager.instance.upcomingSongsNotifier.value = reordered.map((t) => Map<String, dynamic>.from(t)).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          videoId: videoId.isNotEmpty ? videoId : '',
          title: title,
          artist: artist,
          imageUrl: imageUrl,
          durationMs: durationMs,
        ),
      ),
    );
  }

  void _playAllLiked(List<Map<String, dynamic>> songs) {
    if (songs.isEmpty) return;
    _playTrack(songs.first, songs, 0);
  }

  void _playPlaylist(List<Map<String, dynamic>> tracks) {
    if (tracks.isEmpty) return;
    _playTrack(tracks.first, tracks, 0);
  }
}
