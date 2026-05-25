import 'package:google_sign_in/google_sign_in.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:nb_utils/nb_utils.dart';
import 'package:flutter/material.dart';
import '../screen/MPDashboardScreen.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/playlist_manager.dart';

const String vpsIp = '103.247.11.142'; // VPS Database and Node.js Music Server

String getBackendUrl(String endpoint) {
  return 'http://$vpsIp$endpoint';
}

String getMusicApiUrl(String endpoint) {
  return 'http://$vpsIp$endpoint';
}

class AuthHelper {
  Future<void> authWithGoogle(BuildContext context, {bool isSignUp = false}) async {
    try {
      // PERHATIAN: Masukkan Client ID tipe "Web Application" kamu di bawah ini
      const String webClientId = "449350254702-jfm20t2q7uencjae54uq1fhens4opf7n.apps.googleusercontent.com";
      
      // Inisialisasi GoogleSignIn (Wajib di v7.0.0+)
      await gauth.GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? webClientId : null,
        serverClientId: webClientId,
      );

      // 1. Munculkan popup login Google
      final gauth.GoogleSignInAccount googleUser = await gauth.GoogleSignIn.instance.authenticate();
      if (googleUser == null) {
        toast("Login dibatalkan");
        return; 
      }

      // 2. Dapatkan ID Token
      final gauth.GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      toast('Berhasil masuk Google, memverifikasi ke server...');

      // 3. Kirim Token ke Backend
      await _sendTokenToBackend(context, idToken, isSignUp: isSignUp);

    } catch (error) {
      toast("Error Google SignIn. Pastikan koneksi internet stabil.");
      debugPrint("Error login dengan Google: $error");
    }
  }

  Future<void> _sendTokenToBackend(BuildContext context, String? idToken, {required bool isSignUp}) async {
    if (idToken == null) return;

    final endpoint = isSignUp ? '/api/auth/google/signup' : '/api/auth/google/login';
    final url = Uri.parse(getBackendUrl(endpoint)); 
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        toast(isSignUp ? 'Sign Up Berhasil!' : 'Login Berhasil!');
        
        if (responseData['user'] != null) {
          await setValue('userName', responseData['user']['name'] ?? 'Google User');
          await setValue('userEmail', responseData['user']['email'] ?? '');
          await setValue('userToken', responseData['token'] ?? '');
          await setValue('userId', responseData['user']['_id'] ?? '');
        }

        // Panggil Playlist dari awan (Timpa data lokal dengan data database)
        await PlaylistManager.instance.syncFromCloud();

        // Arahkan pengunjung ke Dashboard jika verifikasi berhasil dan status valid
        DashboardPage().launch(context, isNewTask: true);
      } else if (response.statusCode == 404) {
        toast('Akun belum terdaftar. Silakan Sign Up terlebih dahulu!');
      } else if (response.statusCode == 409) {
        toast('Akun sudah terdaftar. Silakan lakukan Login!');
      } else {
        toast("Gagal verifikasi: ${responseData['error'] ?? 'Unknown Error'}");
      }
    } catch (e) {
      toast('Gagal menghubungi server. Pastikan server lokal menyala.');
    }
  }

  // ============== AUTHENTICATION MANUAL ============== //

  Future<void> registerWithEmail(BuildContext context, {required String name, required String email, required String password}) async {
    final url = Uri.parse(getBackendUrl('/api/auth/register'));
    toast('Sedang mendaftarkan akun...');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        toast('Akun berhasil dibuat! Silakan Sign In.');
        if (context.mounted) Navigator.pop(context); // Kembali ke halaman Login
      } else if (response.statusCode == 409) {
        toast('Email sudah terdaftar. Silakan Sign In.');
      } else {
        toast("Gagal mendaftar: ${responseData['error'] ?? 'Unknown Error'}");
      }
    } catch (e) {
      toast('Gagal menghubungi server. Pastikan server menyala.');
    }
  }

  Future<void> loginWithEmail(BuildContext context, {required String email, required String password}) async {
    final url = Uri.parse(getBackendUrl('/api/auth/login'));
    toast('Sedang masuk...');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        toast('Login Berhasil!');

        if (responseData['user'] != null) {
          await setValue('userName', responseData['user']['name'] ?? 'User');
          await setValue('userEmail', responseData['user']['email'] ?? '');
          await setValue('userToken', responseData['token'] ?? '');
          await setValue('userId', responseData['user']['_id'] ?? '');
        }

        // Panggil Playlist dari awan (Timpa data lokal dengan data database)
        await PlaylistManager.instance.syncFromCloud();

        DashboardPage().launch(context, isNewTask: true);
      } else if (response.statusCode == 404) {
        toast('Email belum terdaftar. Silakan Sign Up terlebih dahulu!');
      } else if (response.statusCode == 400) {
        toast('Akun dihubungkan ke Google. Gunakan Google Sign-In.');
      } else if (response.statusCode == 401) {
        toast('Password yang kamu masukkan salah.');
      } else {
        toast("Gagal masuk: ${responseData['error'] ?? 'Unknown Error'}");
      }
    } catch (e) {
      toast('Gagal menghubungi server. Pastikan server menyala.');
    }
  }

  Future<bool> requestPasswordReset(BuildContext context, {required String email}) async {
    final url = Uri.parse(getBackendUrl('/api/auth/forgot-password'));
    toast('Meminta OTP...');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        toast('OTP telah dikirim ke email!');
        return true;
      } else {
        toast(responseData['error'] ?? 'Gagal meminta OTP.');
        return false;
      }
    } catch (e) {
      toast('Gagal menghubungi server.');
      return false;
    }
  }

  Future<bool> resetPassword(BuildContext context, {required String email, required String otp, required String newPassword}) async {
    final url = Uri.parse(getBackendUrl('/api/auth/reset-password'));
    toast('Memverifikasi OTP...');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp, 'newPassword': newPassword}),
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        toast('Sandi berhasil direset!');
        return true;
      } else {
        toast(responseData['error'] ?? 'OTP Salah/Kedaluwarsa.');
        return false;
      }
    } catch (e) {
      toast('Gagal menghubungi server.');
      return false;
    }
  }

  Future<bool> changePassword(BuildContext context, {required String email, required String oldPassword, required String newPassword}) async {
    final url = Uri.parse(getBackendUrl('/api/auth/change-password'));
    toast('Menyimpan sandi baru...');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'oldPassword': oldPassword, 'newPassword': newPassword}),
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        toast('Sandi berhasil diubah!');
        return true;
      } else {
        toast(responseData['error'] ?? 'Gagal mengubah sandi.');
        return false;
      }
    } catch (e) {
      toast('Gagal menghubungi server.');
      return false;
    }
  }

  Future<bool> updateProfile(BuildContext context, {required String email, String? name, String? base64Image}) async {
    final url = Uri.parse(getBackendUrl('/api/user/update-profile'));
    toast('Memperbarui profil...');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
          'picture': base64Image,
        }),
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        toast('Profil berhasil diperbarui!');
        // Update memori lokal
        if (responseData['user'] != null) {
          if (responseData['user']['name'] != null) await setValue('userName', responseData['user']['name']);
          if (responseData['user']['picture'] != null) await setValue('userPicture', responseData['user']['picture']);
        }
        return true;
      } else {
        toast(responseData['error'] ?? 'Gagal memperbarui profil.');
        return false;
      }
    } catch (e) {
      debugPrint('Update Profile Error: $e');
      toast('Gagal menghubungi server.');
      return false;
    }
  }

  // =========== LISTENING HISTORY =========== //
  Future<void> saveListeningHistory(String audioUrl, String title, String artist, String imageUrl, int durationMs) async {
    final userId = getStringAsync('userId');
    if (userId.isEmpty) return;

    final url = Uri.parse(getBackendUrl('/api/history'));
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'audioUrl': audioUrl,
          'title': title,
          'artist': artist,
          'imageUrl': imageUrl,
          'durationMs': durationMs,
        }),
      );
    } catch (e) {
      debugPrint('Gagal menyimpan riwayat lagu');
    }
  }

  Future<List<dynamic>> getListeningHistory() async {
    final userId = getStringAsync('userId');
    if (userId.isEmpty) return [];

    final url = Uri.parse(getBackendUrl('/api/history/$userId'));
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Gagal menarik riwayat lagu');
    }
    return [];
  }

  // =========== EMOTION STATS =========== //
  Future<void> saveEmotionStatus(String emotion, double confidence) async {
    final userId = getStringAsync('userId');
    if (userId.isEmpty) return;

    final url = Uri.parse(getBackendUrl('/api/emotions'));
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'emotion': emotion,
          'confidence': confidence,
        }),
      );
    } catch (e) {
      debugPrint('Gagal menyimpan log emosi');
    }
  }

  Future<List<dynamic>> getEmotionStats() async {
    final userId = getStringAsync('userId');
    if (userId.isEmpty) return [];

    final url = Uri.parse(getBackendUrl('/api/emotions/$userId'));
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('Gagal menarik log emosi');
    }
    return [];
  }
}
