import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'screen/MPSplashScreen.dart';
import 'services/playlist_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialize(); // from nb_utils
  await PlaylistManager.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
