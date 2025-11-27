import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/desktop/pages/main_page.dart';
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

  if (isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, // only allow portrait
    ]);
  } else {
    await windowManager.ensureInitialized();
    final windowController = await WindowController.fromCurrentEngine();

    if (windowController.arguments.isNotEmpty) {
      WindowOptions windowOptions = WindowOptions(
        size: Size(800, 120),
        center: true,
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.hidden,
        skipTaskbar: true,
        alwaysOnTop: true,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setAsFrameless();
      });
      runApp(DesktopLyrics());
      return;
    }

    if (kReleaseMode) {
      await singleInstance.init();
    }

    WindowOptions windowOptions = WindowOptions(
      size: Size(1050, 700),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
      // it's weird on linux: it needs 52 extra pixels, and setMinimumSize should be invoked at last
      await windowManager.setMinimumSize(
        Platform.isLinux ? Size(1102, 752) : Size(1050, 700),
      );
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

  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    audioHandler = await AudioService.init(
      builder: () => AIMAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.afalphy.particle_music',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
      ),
    );
  } else {
    audioHandler = WLAudioHandler();
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
      theme: Platform.isWindows
          ? ThemeData(fontFamily: 'Microsoft YaHei')
          : null,
      title: 'Particle Music',
      home: isMobile ? MobileMainPage() : DesktopMainPage(),
    );
  }
}
