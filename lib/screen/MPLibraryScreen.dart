import 'package:flutter/material.dart';

class MPLibraryScreen extends StatelessWidget {
  const MPLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgTop = Color(0xFFDCE7CD);
    const Color bgMid = Color(0xFF6A8A53);
    const Color bgBottom = Color(0xFF1A2A14);
    const Color textDark = Color(0xFF293B1F);
    
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Your Library",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: textDark, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            // Categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildCategoryChip("Playlists", true),
                  _buildCategoryChip("Liked Songs", false),
                  _buildCategoryChip("Albums", false),
                  _buildCategoryChip("Artists", false),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Playlists List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildPlaylistItem("Favorite Pop", "12 songs • Created by You", Icons.queue_music, const Color(0xFFD8A854)),
                  _buildPlaylistItem("Relaxing Evening", "8 songs • Created by Famotion", Icons.nature, const Color(0xFF6A8A53)),
                  _buildPlaylistItem("Workout Grind", "24 songs • Created by You", Icons.fitness_center, const Color(0xFFB57062)),
                  _buildPlaylistItem("Upbeat Motivation", "15 songs • Created by Famotion", Icons.mood, const Color(0xFF729CA3)),
                  _buildPlaylistItem("Sleep Sounds", "10 songs • Created by Famotion", Icons.nights_stay, const Color(0xFF5D668A)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoryChip(String label, bool isSelected) {
    const Color accentGold = Color(0xFFD8A854);
    const Color textDark = Color(0xFF293B1F);
    
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? accentGold : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? accentGold : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : textDark.withOpacity(0.8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(String title, String subtitle, IconData icon, Color iconBgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
        ],
      ),
    );
  }
}
