import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:particle_music/desktop/my_tray_listener.dart';
import 'package:particle_music/desktop/my_window_listener.dart';
import 'package:particle_music/desktop/pages/main_page.dart';
import 'package:particle_music/desktop/pages/mini_mode_page.dart';
import 'package:particle_music/desktop/single_instance.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/library_manager.dart';
import 'package:particle_music/mobile/overlay_lyrics.dart';
import 'package:particle_music/mobile/pages/main_page.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  appDocs = await getApplicationDocumentsDirectory();
  appSupportDir = await getApplicationSupportDirectory();

  if (isMobile) {
    await logger.init();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, // only allow portrait
    ]);
  } else {
    await windowManager.ensureInitialized();
    final windowController = await WindowController.fromCurrentEngine();

    if (windowController.arguments == 'desktop_lyrics') {
      _setupDesktopLyricsWindow(windowController);
      runApp(DesktopLyrics());
      return;
    }

    await logger.init();

    if (kReleaseMode) {
      await SingleInstance.start();
    }

    keyboardInit();

    await _setupMainWindow(windowController);
    await _setupTray();
  }

  await initAudioService();

  await libraryManager.init();

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
              ? ThemeData(
                  textTheme: GoogleFonts.notoSansTextTheme(
                    ThemeData.light().textTheme,
                  ).apply(fontFamilyFallback: ['Microsoft YaHei']),
                )
              : null,
          title: 'Particle Music',
          home: ValueListenableBuilder(
            valueListenable: loadingLibraryNotifier,
            builder: (context, value, child) {
              if (value) {
                return _loadingPage(context);
              }

              return isMobile
                  ? MobileMainPage()
                  : ValueListenableBuilder(
                      valueListenable: miniModeNotifier,
                      builder: (context, miniMode, child) {
                        if (miniMode) {
                          return MiniModePage();
                        }
                        return DesktopMainPage();
                      },
                    );
            },
          ),
        );
      },
    ),
  );
  logger.output('App start');
  await libraryManager.load();
  if (!isMobile) {
    await initDesktopLyrics();
  }
}

Future<void> _setupMainWindow(WindowController windowController) async {
  await windowController.mainCustomInitialize();
  WindowOptions windowOptions = WindowOptions(
    size: Platform.isWindows ? Size(1050 + 16, 700 + 9) : Size(1050, 700),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
    // it's weird on linux: it needs 52 extra pixels, and setMinimumSize should be invoked at last
    // windows need 16:9 extra pixels
    await windowManager.setMinimumSize(
      Platform.isLinux
          ? Size(1102, 752)
          : Platform.isWindows
          ? Size(1050 + 16, 700 + 9)
          : Size(1050, 700),
    );
  });
  windowManager.addListener(MyWindowListener());
}

Future<void> _setupDesktopLyricsWindow(
  WindowController windowController,
) async {
  await windowController.desktopLyricsCustomInitialize();
  WindowOptions windowOptions = WindowOptions(
    title: "Desktop Lyrics",
    size: Platform.isLinux ? Size(850, 200) : Size(800, 150),
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
}

Future<void> _setupTray() async {
  await trayManager.setIcon(
    Platform.isWindows
        ? 'assets/app_icon.ico'
        : Platform.isMacOS
        ? 'assets/mac_tray.png'
        : 'assets/linux_tray.png',
    isTemplate: true,
  );

  if (!Platform.isLinux) {
    await trayManager.setToolTip('Particle Music');
  }

  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'show', label: 'Show App'),
        MenuItem.separator(),

        MenuItem(key: 'skipToPrevious', label: 'Skip to Previous'),
        MenuItem(key: 'togglePlay', label: 'Play/Pause'),
        MenuItem(key: 'skipToNext', label: 'Skip to Next'),
        MenuItem.separator(),

        MenuItem(key: 'unlock', label: 'Unlock Desktop Lyrics'),

        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit'),
      ],
    ),
  );

  trayManager.addListener(MyTrayListener());
}

Widget _loadingPage(BuildContext context) {
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
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: OverlayLyrics()));
}
