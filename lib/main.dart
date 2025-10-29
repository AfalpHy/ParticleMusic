import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/desktop/main_page.dart';
import 'package:particle_music/desktop/single_instance.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/main_page.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
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
    await windowManager.ensureInitialized();

    if (kReleaseMode) {
      await singleInstance.init();
    }

    audioHandler = DesktopAudioHandler();

    WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(1050, 700),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });

    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
    );

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Show App'),
          MenuItem(key: 'skipToPrevious', label: 'Skip to Previous'),
          MenuItem(key: 'togglePlay', label: 'Play/Pause'),
          MenuItem(key: 'skipToNext', label: 'Skip to Next'),

          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Exit'),
        ],
      ),
    );
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
