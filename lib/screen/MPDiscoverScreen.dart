import 'package:flutter/material.dart';

class MPDiscoverScreen extends StatelessWidget {
  const MPDiscoverScreen({super.key});

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "Discover",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Find the perfect music for your current mood.",
                style: TextStyle(
                  fontSize: 14,
                  color: textDark.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),

              // Genres / Moods Grid
              const Text(
                "MOOD PLAYLISTS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildGenreCard("Happy", Icons.sentiment_very_satisfied, const Color(0xFFE2B86C), const Color(0xFFC48E3A)),
                  _buildGenreCard("Sad", Icons.sentiment_dissatisfied, const Color(0xFF8BA6C9), const Color(0xFF567296)),
                  _buildGenreCard("Angry", Icons.sentiment_very_dissatisfied, const Color(0xFFD67373), const Color(0xFF9E4242)),
                  _buildGenreCard("Calm", Icons.sentiment_satisfied_alt, const Color(0xFF8AC79B), const Color(0xFF4C8A5D)),
                  _buildGenreCard("Energetic", Icons.bolt, const Color(0xFFD188D4), const Color(0xFF8B478E)),
                  _buildGenreCard("Focus", Icons.center_focus_strong, const Color(0xFF91B8A0), const Color(0xFF4D725B)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreCard(String title, IconData icon, Color colorLight, Color colorDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorLight, colorDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorDark.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Navigate to specific playlist
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.9), size: 36),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
