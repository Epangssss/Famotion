import 'package:flutter/material.dart';
import 'MPLoginScreen.dart';

class MPProfileScreen extends StatelessWidget {
  const MPProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgTop = Color(0xFFDCE7CD);
    const Color bgMid = Color(0xFF6A8A53);
    const Color bgBottom = Color(0xFF1A2A14);
    const Color textDark = Color(0xFF293B1F);
    const Color accentGold = Color(0xFFD8A854);

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
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header & Profile Info
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: textDark.withOpacity(0.15),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: accentGold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "User Profile",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "user@famotion.com",
                      style: TextStyle(
                        fontSize: 14,
                        color: textDark.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),

              // Statistics Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem("Playlists", "12", textDark),
                    Container(height: 40, width: 1, color: Colors.white.withOpacity(0.3)),
                    _buildStatItem("Followers", "128", textDark),
                    Container(height: 40, width: 1, color: Colors.white.withOpacity(0.3)),
                    _buildStatItem("Following", "45", textDark),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Settings List
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF293B1F).withOpacity(0.6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildSettingsItem(Icons.person_outline, "Account Details", "Manage your personal information", () {}),
                    _buildSettingsItem(Icons.notifications_outlined, "Notifications", "Communication preferences", () {}),
                    _buildSettingsItem(Icons.privacy_tip_outlined, "Privacy & Security", "Manage data and app security", () {}),
                    _buildSettingsItem(Icons.history, "Listening History", "View your recent tracks", () {}),
                    _buildSettingsItem(Icons.help_outline, "Help & Support", "Get help or send feedback", () {}),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Divider(color: Colors.white24),
                    ),
                    
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout, color: Colors.redAccent),
                      ),
                      title: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        _showLogoutConfirmationDialog(context);
                      },
                    ),
                    const SizedBox(height: 100), // Padding for bottom nav bar
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color textDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textDark.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 16),
      onTap: onTap,
    );
  }

  // Dialog Konfirmasi Keluar (Sama seperti di Dashboard)
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF293B1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  MaterialPageRoute(builder: (context) => const MPLoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text(
                "Keluar",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
