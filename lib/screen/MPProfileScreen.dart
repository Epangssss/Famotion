import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'MPLoginScreen.dart';
import '../utils/auth_helper.dart';
import 'MPHistoryScreen.dart';
import 'MPAnalyticsScreen.dart';

class MPProfileScreen extends StatefulWidget {
  const MPProfileScreen({super.key});

  @override
  State<MPProfileScreen> createState() => _MPProfileScreenState();
}

class _MPProfileScreenState extends State<MPProfileScreen> {

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
                          backgroundImage: _getProfileImage() ?? const AssetImage('assets/icons/favicon.png'),
                        ),
                        GestureDetector(
                          onTap: () => _showEditProfileDialog(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accentGold,
                              shape: BoxShape.circle,
                              border: Border.all(color: bgTop, width: 2),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      getStringAsync('userName', defaultValue: 'User Profile'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getStringAsync('userEmail', defaultValue: 'user@famotion.com'),
                      style: TextStyle(
                        fontSize: 14,
                        color: textDark.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),

                     
              // Settings List
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF293B1F).withOpacity(0.6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildSettingsItem(Icons.pie_chart_outline, "Mood Analytics", "Your emotional insights in 7 days", () {
                      const MPAnalyticsScreen().launch(context);
                    }),
                    _buildSettingsItem(Icons.notifications_outlined, "Notifications", "Communication preferences", () {
                      _showComingSoon(context, "Notifications");
                    }),
                    _buildSettingsItem(Icons.lock_outline, "Change Password", "Update your account password", () {
                      _showChangePasswordDialog(context);
                    }),
                    _buildSettingsItem(Icons.history, "Listening History", "View your recent tracks", () {
                      const MPHistoryScreen().launch(context);
                    }),
                    _buildSettingsItem(Icons.help_outline, "Help & Support", "Get help or send feedback", () {
                      _showComingSoon(context, "Help & Support");
                    }),
                    
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


  ImageProvider? _getProfileImage() {
    final picUrl = getStringAsync('userPicture', defaultValue: '');
    if (picUrl.isEmpty) return null;
    
    // Check if it's base64 (very long string) or URL
    if (picUrl.length > 200 && !picUrl.startsWith('http')) {
       try {
         final bytes = base64Decode(picUrl);
         return MemoryImage(bytes);
       } catch(e) {
         return null;
       }
    } else if (picUrl.startsWith('http')) {
       return NetworkImage(picUrl);
    }
    return null;
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameCont = TextEditingController(text: getStringAsync('userName'));
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF293B1F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextFormField(
                    controller: nameCont,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD8A854)),
                  onPressed: () async {
                    if (nameCont.text.trim().isEmpty) {
                      toast('Nama tidak boleh kosong');
                      return;
                    }
                    
                    final email = getStringAsync('userEmail');
                    final success = await AuthHelper().updateProfile(
                      context, 
                      email: email, 
                      name: nameCont.text.trim(),
                      // Foto profil ditiadakan dulu untuk sementara
                    );
                    
                    if (success) {
                      if (context.mounted) Navigator.pop(dialogContext);
                      // Update main screen
                      setState(() {});
                    }
                  },
                  child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final oldPassCont = TextEditingController();
        final newPassCont = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF293B1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ubah Sandi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPassCont,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sandi Lama (Kosongkan jika mendaftar dgn Google)',
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPassCont,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Sandi Baru',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD8A854)),
              onPressed: () async {
                final oldPass = oldPassCont.text.trim();
                final newPass = newPassCont.text.trim();
                if (newPass.isEmpty) {
                  toast('Sandi baru tidak boleh kosong');
                  return;
                }
                
                final email = getStringAsync('userEmail');
                final success = await AuthHelper().changePassword(context, email: email, oldPassword: oldPass, newPassword: newPass);
                
                if (success) {
                  // Berhasil ganti sandi -> Logout paksa
                  removeKey('userName');
                  removeKey('userEmail');
                  removeKey('userToken');
                  
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MPLoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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

  // Pesan Pemberitahuan Fitur Mendatang
  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Fitur $featureName segera hadir di update selanjutnya! ✨"),
        backgroundColor: const Color(0xFF6A8A53),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
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

                // Hapus sesi pengguna lokal
                removeKey('userName');
                removeKey('userEmail');
                removeKey('userToken');

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
