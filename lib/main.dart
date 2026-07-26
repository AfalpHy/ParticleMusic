import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gamepads/flutter_gamepads.dart';
import 'package:liquid_glass_widgets/liquid_glass_setup.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/my_tray_listener.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/base/services/single_instance.dart';
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

  if (isTV) {
    viewModeNotifier.value = .bigPicture;
  } else {
    final viewModeFile = File("${appSupportDir.path}/viewMode.json");
    String viewMode = 'normal';
    if (viewModeFile.existsSync()) {
      viewMode = viewModeFile.readAsStringSync();
    }
    viewModeNotifier.value = ViewMode.values.firstWhere(
      (e) => e.name == viewMode,
      orElse: () => .normal,
    );
    viewModeNotifier.addListener(() {
      viewModeFile.writeAsString(viewModeNotifier.value.name);
    });
  }

  await logger.init();
  if (isMobile) {
    screenRadius = await ScreenCornerRadius.get();
  } else {
    if (kReleaseMode) {
      await SingleInstance.start();
    }

    keyboardInit();

    await _setupWindow();
    await _setupTray();
  }

  _registerLicenses();

  await initAudioService();

  await Loader.init();
  await Loader.load();
  await LiquidGlassWidgets.initialize();
  if (isTV) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }
  runApp(
    ListenableBuilder(
      listenable: Listenable.merge([
        localeNotifier,
        fontFamilyNotifier,
        mainPageThemeNotifier,
        lightHoverFocusColorNotifier,
      ]),
      builder: (context, child) {
        return MaterialApp(
          locale: localeNotifier.value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          title: 'Sylvaklu',
          theme: ThemeData(
            focusColor: lightHoverFocusColorNotifier.value
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(20),
            hoverColor: lightHoverFocusColorNotifier.value
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
          home: child,
        );
      },
      child: Builder(
        builder: (context) {
          return GamepadControl(
            shortcuts: {
              GamepadActivatorButton.a(): const ActivateIntent(),
              GamepadActivatorButton.b(): const DismissIntent(),
              GamepadActivatorButton.leftBumper(): const DirectionalFocusIntent(
                TraversalDirection.left,
              ),
              GamepadActivatorButton.rightBumper():
                  const DirectionalFocusIntent(TraversalDirection.right),

              GamepadActivatorButton.dpadUp(): const DirectionalFocusIntent(
                TraversalDirection.up,
              ),
              GamepadActivatorButton.dpadDown(): const DirectionalFocusIntent(
                TraversalDirection.down,
              ),
              GamepadActivatorButton.dpadLeft(): const DirectionalFocusIntent(
                TraversalDirection.left,
              ),
              GamepadActivatorButton.dpadRight(): const DirectionalFocusIntent(
                TraversalDirection.right,
              ),

              GamepadActivatorAxis.leftStickUp(): const DirectionalFocusIntent(
                TraversalDirection.up,
              ),
              GamepadActivatorAxis.leftStickDown():
                  const DirectionalFocusIntent(TraversalDirection.down),
              GamepadActivatorAxis.leftStickLeft():
                  const DirectionalFocusIntent(TraversalDirection.left),
              GamepadActivatorAxis.leftStickRight():
                  const DirectionalFocusIntent(TraversalDirection.right),

              GamepadActivatorAxis.rightStickUp(): const ScrollIntent(
                direction: AxisDirection.up,
              ),
              GamepadActivatorAxis.rightStickDown(): const ScrollIntent(
                direction: AxisDirection.down,
              ),
              GamepadActivatorAxis.rightStickLeft(): const ScrollIntent(
                direction: AxisDirection.left,
              ),
              GamepadActivatorAxis.rightStickRight(): const ScrollIntent(
                direction: AxisDirection.right,
              ),
            },
            repeatIntents: {
              // add your new intents for hold repeat
              const DirectionalFocusIntent(TraversalDirection.up),
              const DirectionalFocusIntent(TraversalDirection.down),
              const DirectionalFocusIntent(TraversalDirection.left),
              const DirectionalFocusIntent(TraversalDirection.right),
              // keep old ones if you still use them
              const PreviousFocusIntent(),
              const NextFocusIntent(),

              const ScrollIntent(direction: AxisDirection.up),
              const ScrollIntent(direction: AxisDirection.down),
              const ScrollIntent(direction: AxisDirection.left),
              const ScrollIntent(direction: AxisDirection.right),
            },
            onBeforeIntent: (p0, p1) {
              FocusManager.instance.highlightStrategy =
                  FocusHighlightStrategy.alwaysTraditional;

              if (p1 is DismissIntent) {
                Navigator.of(context).maybePop();
                return false;
              }
              return true;
            },
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true, // for mobile
              removeRight: true,
              // semantics sometimes crash on ios simulator, I don't know why
              child: ExcludeSemantics(child: ViewEntry()),
            ),
          );
        },
      ),
    ),
  );

  logger.output('App start');
}

Future<void> _setupWindow() async {
  myWindowListener = MyWindowListener();
  WindowOptions windowOptions = WindowOptions(
    size: viewModeNotifier.value == .mini ? miniSize : mainSize,
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
    if (viewModeNotifier.value == .mini) {
      if (Platform.isWindows) {
        await windowManager.setMinimumSize(Size(325 + 16, 150 + 9));
        await windowManager.setMaximumSize(Size(600 + 16, 950 + 9));
      } else {
        await windowManager.setMinimumSize(Size(325, 150));
        await windowManager.setMaximumSize(Size(600, 950));
      }

      if (miniPosition != null) {
        await windowManager.setPosition(miniPosition!);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future.delayed(Duration(milliseconds: 250));
          miniPosition = await windowManager.getPosition();
        });
      }
      await windowManager.setAlwaysOnTop(true);
    } else {
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
