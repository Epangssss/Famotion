import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'screen/mp_splash_screen.dart';
import 'services/playlist_manager.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.famotion.app.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  
  await initialize(); // from nb_utils
  await PlaylistManager.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Famotion',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Provided by nb_utils
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
      ),
      home: const MPSplashScreen(),
    );
  }
}
