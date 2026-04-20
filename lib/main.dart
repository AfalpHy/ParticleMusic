import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/desktop_lyrics.dart';
import 'package:particle_music/landscape_view/extensions/window_controller_extension.dart';
import 'package:particle_music/landscape_view/keyboard.dart';
import 'package:particle_music/landscape_view/my_tray_listener.dart';
import 'package:particle_music/landscape_view/my_window_listener.dart';
import 'package:particle_music/landscape_view/single_instance.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/l10n/generated/app_localizations_en.dart';
import 'package:particle_music/loader.dart';
import 'package:particle_music/portrait_view/overlay_lyrics.dart';
import 'package:particle_music/portrait_view/custom_page_transition_builder.dart';
import 'dart:async';
import 'package:particle_music/view_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  appDocs = await getApplicationDocumentsDirectory();
  appSupportDir = await getApplicationSupportDirectory();
  tmpDir = await getTemporaryDirectory();

  folderConfigDir = Directory('${appSupportDir.path}/folder_config');
  if (!folderConfigDir.existsSync()) {
    folderConfigDir.createSync();
  }

  playlistConfigDir = Directory('${appSupportDir.path}/playlist_config');
  if (!playlistConfigDir.existsSync()) {
    playlistConfigDir.createSync();
  }

  cacheConfigDir = Directory('${appSupportDir.path}/cache_config');
  if (!cacheConfigDir.existsSync()) {
    cacheConfigDir.createSync();
  }

  if (isMobile) {
    await logger.init();
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

  await Loader.init();

  runApp(
    ListenableBuilder(
      listenable: Listenable.merge([
        localeNotifier,
        iconColor.valueNotifier,
        textColor.valueNotifier,
      ]),
      builder: (context, child) {
        return MaterialApp(
          locale: localeNotifier.value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          title: 'Particle Music',
          theme: ThemeData(
            appBarTheme: AppBarTheme(
              titleTextStyle: TextStyle(color: textColor.value, fontSize: 24),
              iconTheme: IconThemeData(color: iconColor.value),
            ),
            textTheme: Platform.isWindows
                ? GoogleFonts.notoSerifScTextTheme().copyWith(
                    bodyLarge: GoogleFonts.notoSerifSc(
                      color: textColor.value,
                      fontWeight: .w500,
                    ),
                    bodyMedium: GoogleFonts.notoSerifSc(
                      color: textColor.value,
                      fontWeight: .w500,
                    ),
                  )
                : TextTheme(
                    bodyLarge: TextStyle(color: textColor.value),
                    bodyMedium: TextStyle(color: textColor.value),
                    displayLarge: TextStyle(
                      color: textColor.value,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            iconTheme: IconThemeData(color: iconColor.value),
            listTileTheme: ListTileThemeData(
              iconColor: iconColor.value,
              textColor: textColor.value,
            ),

            // adjust magnifier color
            cupertinoOverrideTheme: Platform.isIOS
                ? CupertinoThemeData(primaryColor: textColor.value)
                : null,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {TargetPlatform.android: CustomPageTransitionBuilder()},
            ),

            splashColor: isMobile ? null : Colors.transparent,
            highlightColor: isMobile ? null : Colors.transparent,

            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                enabledMouseCursor: SystemMouseCursors.click,
              ),
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                enabledMouseCursor: SystemMouseCursors.click,
              ),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                enabledMouseCursor: SystemMouseCursors.click,
                elevation: 1,
                foregroundColor: textColor.value,
                shadowColor: Colors.black12,
                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            textSelectionTheme: TextSelectionThemeData(
              selectionColor: textColor.value.withAlpha(50),
              cursorColor: textColor.value,
              selectionHandleColor: textColor.value,
            ),
          ),
          home: child,
        );
      },
      child: ValueListenableBuilder(
        valueListenable: loadingLibraryNotifier,
        builder: (context, value, child) {
          if (value) {
            return _loadingPage(context);
          }

          return MediaQuery.removePadding(
            context: context,
            removeLeft: true, // for mobile
            removeRight: true,
            child: ViewEntry(),
          );
        },
      ),
    ),
  );
  logger.output('App start');
  await Loader.load();
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
    size: Platform.isLinux ? Size(1000, 250) : Size(1000, 200),
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

Future<void> _setTrayMemu(Locale locale) async {
  late AppLocalizations l10n;
  try {
    l10n = lookupAppLocalizations(locale);
  } catch (_) {
    l10n = AppLocalizationsEn();
  }
  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'show', label: l10n.showApp),
        MenuItem.separator(),

        MenuItem(key: 'skipToPrevious', label: l10n.skip2Previous),
        MenuItem(key: 'togglePlay', label: l10n.playOrPause),
        MenuItem(key: 'skipToNext', label: l10n.skip2Next),
        MenuItem.separator(),

        MenuItem(key: 'unlock', label: l10n.unlockDeskLrc),

        MenuItem.separator(),
        MenuItem(key: 'exit', label: l10n.exit),
      ],
    ),
  );
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

  Locale systemLocale = PlatformDispatcher.instance.locale;
  await _setTrayMemu(systemLocale);

  localeNotifier.addListener(() async {
    Locale? locale = localeNotifier.value;
    locale ??= PlatformDispatcher.instance.locale;
    await _setTrayMemu(locale);
  });

  trayManager.addListener(MyTrayListener());
}

Widget _loadingPage(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  return Scaffold(
    backgroundColor: isMobile
        ? pageBackgroundColor.value.withAlpha(255)
        : panelColor.value.withAlpha(255),
    body: ValueListenableBuilder(
      valueListenable: loadingNavidromeNotifier,
      builder: (context, value, child) {
        if (value) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: iconColor.value),
                SizedBox(height: 15),
                Text(l10n.loadingNavidrome),
              ],
            ),
          );
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: iconColor.value),
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
        );
      },
    ),
  );
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: OverlayLyrics()));
}
