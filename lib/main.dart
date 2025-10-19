import 'dart:io';
import 'package:flutter/material.dart';
import 'package:particle_music/desktop/main_page.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/main_page.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    audioHandler = await AudioService.init(
      builder: () => MobileAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.afalphy.particle_music',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
      ),
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, // only allow portrait
    ]);
  } else {
    audioHandler = DesktopAudioHandler();
  }
  await libraryLoader.initial();
  await libraryLoader.load();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Particle Music',
      home: (Platform.isAndroid || Platform.isIOS)
          ? MobileMainPage()
          : DesktopMainPage(),
    );
  }
}
