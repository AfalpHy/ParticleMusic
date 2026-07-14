import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/my_tray_listener.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/base/services/single_instance.dart';
import 'package:sylvakru/base/widgets/usb_audio_event_listener.dart';
import 'package:sylvakru/base/widgets/usb_exclusive_volume_overlay.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/l10n/generated/app_localizations_en.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/portrait_view/custom_page_transition_builder.dart';
import 'package:sylvakru/view_entry.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'base/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  appDocsDir = await getApplicationDocumentsDirectory();
  appSupportDir = await getApplicationSupportDirectory();
  tmpDir = await getTemporaryDirectory();

  await logger.init();
  if (isMobile) {
    screenRadius = await ScreenCornerRadius.get();
  } else {
    if (kReleaseMode) {
      await SingleInstance.start();
    }

    keyboardInit();

    await _setupMainWindow();
    await _setupTray();
  }

  _registerLicenses();

  await initAudioService();

  await Loader.init();
  await Loader.load();
  runApp(
    ListenableBuilder(
      listenable: Listenable.merge([
        localeNotifier,
        fontFamilyNotifier,
        mainPageThemeNotifier,
      ]),
      builder: (context, child) {
        return MaterialApp(
          locale: localeNotifier.value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          title: 'Sylvaklu',
          theme: ThemeData(
            focusColor: mainPageThemeNotifier.value == .dark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(20),
            hoverColor: mainPageThemeNotifier.value == .dark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(15),
            textTheme: Theme.of(context).textTheme.apply(
              fontFamily: fontFamilyNotifier.value,
              bodyColor: textColor.value,
              displayColor: textColor.value,
            ),
            appBarTheme: AppBarTheme(
              titleTextStyle: TextStyle(
                color: textColor.value,
                fontSize: 24,
                fontFamily: fontFamilyNotifier.value,
              ),
              iconTheme: IconThemeData(color: iconColor.value),
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
          // 独占物理音量键触发的悬浮音量窗口叠在所有页面之上。
          builder: (context, navigator) {
            return Stack(
              children: [
                if (navigator != null) Positioned.fill(child: navigator),
                const UsbExclusiveVolumeOverlay(),
              ],
            );
          },
          home: child,
        );
      },
      child: Builder(
        builder: (context) {
          return UsbAudioEventListener(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true, // for mobile
              removeRight: true,
              child: ViewEntry(),
            ),
          );
        },
      ),
    ),
  );

  logger.output('App start');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      audioHandler.restoreCurrentSong().onError((error, stackTrace) {
        logger.output('Playback restore failed: $error');
      }),
    );
  });
}

Future<void> _setupMainWindow() async {
  myWindowListener = MyWindowListener();
  WindowOptions windowOptions = WindowOptions(
    size: mainSize,
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.ensureInitialized();
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
    if (mainPosition != null) {
      await windowManager.setPosition(mainPosition!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 250));
        mainPosition = await windowManager.getPosition();
      });
    }
    if (mainMaximized) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(Duration(milliseconds: 500));
        await windowManager.maximize();
      });
    }
  });
  windowManager.addListener(myWindowListener);
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
    await trayManager.setToolTip('Sylvaru');
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

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/libmpv-license.txt',
    );

    yield LicenseEntryWithLineBreaks(
      ['libmpv'],
      '''
This application uses libmpv from the MPV project.

Source code: https://github.com/mpv-player/mpv

--------------------------------------------------------------

$text
''',
    );
  });

  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/ffmpeg-license.txt',
    );

    yield LicenseEntryWithLineBreaks(
      ['FFmpeg'],
      '''
This application uses FFmpeg.

Source code: https://github.com/FFmpeg/FFmpeg

--------------------------------------------------------------

$text
''',
    );
  });
}
