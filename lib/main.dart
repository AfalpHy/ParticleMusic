import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:particle_music/desktop/my_tray_listener.dart';
import 'package:particle_music/desktop/my_window_listener.dart';
import 'package:particle_music/desktop/pages/main_page.dart';
import 'package:particle_music/desktop/single_instance.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/logger.dart';
import 'package:particle_music/mobile/pages/main_page.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:particle_music/setting.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isMobile) {
    await logger.init();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, // only allow portrait
    ]);
  } else {
    await windowManager.ensureInitialized();
    final windowController = await WindowController.fromCurrentEngine();

    if (windowController.arguments == 'desktop_lyrics') {
      await windowController.desktopLyricsCustomInitialize();
      WindowOptions windowOptions = WindowOptions(
        size: Size(800, 120),
        center: true,
        backgroundColor: Colors.transparent,
        titleBarStyle: TitleBarStyle.hidden,
        // prevent hiding the Dock on macOS
        skipTaskbar: Platform.isMacOS ? false : true,
        alwaysOnTop: true,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setAsFrameless();
      });
      runApp(DesktopLyrics());
      return;
    }

    await windowController.mainCustomInitialize();
    await logger.init();

    logger.output('App init');

    if (kReleaseMode) {
      await startAsSingleInstance();
    }

    WindowOptions windowOptions = WindowOptions(
      size: Size(1050, 700),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (Platform.isMacOS) {
        await windowManager.setAsFrameless();
      }
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

    keyboardInit();

    windowManager.addListener(MyWindowListener());
    trayManager.addListener(MyTrayListener());
  }

  audioHandler = await AudioService.init(
    builder: () => Platform.isWindows || Platform.isLinux
        ? WLAudioHandler()
        : AIMAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.afalphy.particle_music',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    ),
  );

  await libraryLoader.initial();

  runApp(
    ValueListenableBuilder(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: Platform.isWindows
              ? ThemeData(fontFamily: 'Microsoft YaHei')
              : null,
          title: 'Particle Music',
          home: ValueListenableBuilder(
            valueListenable: loadingLibraryNotifier,
            builder: (context, value, child) {
              if (!value) {
                return ValueListenableBuilder(
                  valueListenable: colorChangeNotifier,
                  builder: (_, _, _) {
                    return isMobile ? MobileMainPage() : DesktopMainPage();
                  },
                );
              }
              final l10n = AppLocalizations.of(context);

              return Scaffold(
                backgroundColor: commonColor,
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: iconColor),
                      SizedBox(height: 15),
                      ValueListenableBuilder(
                        valueListenable: currentLoadingFolderNotifier,
                        builder: (context, value, child) {
                          return Text('${l10n.loadingFolder}: $value');
                        },
                      ),
                      SizedBox(height: 5),

                      ValueListenableBuilder(
                        valueListenable: loadedCountNotifier,
                        builder: (context, value, child) {
                          return Text('${l10n.loadedSongs}: $value');
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
  logger.output('App start');
  await libraryLoader.load();
  await initDesktopLyrics();
}
