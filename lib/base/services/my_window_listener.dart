import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/exit.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:window_manager/window_manager.dart';

late final MyWindowListener myWindowListener;

ValueNotifier<bool> isMaximizedNotifier = ValueNotifier(false);
ValueNotifier<bool> isFullScreenNotifier = ValueNotifier(false);

Offset? mainPosition;
Offset? miniPosition;
late Size mainSize;
late Size miniSize;
late bool mainMaximized;

class MyWindowListener extends WindowListener {
  late File windowConfigFile;

  Timer? writeTimer;

  final Size _defaultMainSize = Size(
    1050 + (Platform.isWindows ? 16 : 0),
    700 + (Platform.isWindows ? 9 : 0),
  );

  final Size _defaultMiniSize = Size(
    325 + (Platform.isWindows ? 16 : 0),
    325 + (Platform.isWindows ? 9 : 0),
  );

  MyWindowListener() {
    windowConfigFile = File('${appSupportDir.path}/window_config.json');
    initFile(windowConfigFile, false);
    loadConfig();
  }

  Map<String, dynamic> toJson() => {
    'mainMaximized': mainMaximized,
    'mainPosition': {'dx': mainPosition?.dx, 'dy': mainPosition?.dy},
    'miniPosition': {'dx': miniPosition?.dx, 'dy': miniPosition?.dy},
    'mainSize': {'width': mainSize.width, 'height': mainSize.height},
    'miniSize': {'width': miniSize.width, 'height': miniSize.height},
    'miniViewMainHeight': miniViewMainHeight,
    'miniViewDisplayBottom': miniViewDisplayBottom,
    'miniViewDisplayLyrics': miniViewDisplayLyricsNotifier.value,
  };

  void fromJson(Map<String, dynamic> json) {
    mainMaximized = json['mainMaximized'] ?? false;

    final mainPos = json['mainPosition'] as Map<String, dynamic>?;
    if (mainPos != null && mainPos['dx'] != null && mainPos['dy'] != null) {
      mainPosition = Offset(mainPos['dx'] as double, mainPos['dy'] as double);
    }

    final miniPos = json['miniPosition'] as Map<String, dynamic>?;
    if (miniPos != null && miniPos['dx'] != null && miniPos['dy'] != null) {
      miniPosition = Offset(miniPos['dx'] as double, miniPos['dy'] as double);
    }

    final mainSz = json['mainSize'] as Map<String, dynamic>?;
    mainSize = Size(
      mainSz?['width'] ?? _defaultMainSize.width,
      mainSz?['height'] ?? _defaultMainSize.height,
    );

    final miniSz = json['miniSize'] as Map<String, dynamic>?;
    miniSize = Size(
      miniSz?['width'] ?? _defaultMiniSize.width,
      miniSz?['height'] ?? _defaultMiniSize.height,
    );

    miniViewMainHeight = json['miniViewMainHeight'] as double? ?? 325.0;
    miniViewDisplayBottom = json['miniViewDisplayBottom'] as bool? ?? false;
    miniViewDisplayLyricsNotifier.value =
        json['miniViewDisplayLyrics'] as bool? ?? true;
  }

  void saveConfig() {
    writeTimer?.cancel();
    writeTimer = Timer(
      Duration(milliseconds: 250),
      () async => await windowConfigFile.writeAsString(jsonEncode(toJson())),
    );
  }

  void loadConfig() {
    final String content = windowConfigFile.readAsStringSync();
    fromJson(jsonDecode(content));
  }

  @override
  void onWindowMoved() async {
    if (viewModeNotifier.value == .mini) {
      miniPosition = await windowManager.getPosition();
    } else {
      mainPosition = await windowManager.getPosition();
    }
    saveConfig();
  }

  @override
  void onWindowMaximize() {
    isMaximizedNotifier.value = true;
    mainMaximized = true;
    saveConfig();
  }

  @override
  void onWindowUnmaximize() {
    isMaximizedNotifier.value = false;
    mainMaximized = false;
    saveConfig();
  }

  @override
  void onWindowClose() {
    if (exitOnCloseNotifier.value) {
      exitApp();
    } else {
      windowManager.hide();
    }
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    if (viewModeNotifier.value == .mini) {
      miniSize = size;
      final gap =
          size.height - (Platform.isWindows ? 9 : 0) - miniViewMainHeight;

      if (gap > 0 && gap < 120) {
        await Future.delayed(Duration(milliseconds: 100));
        if (Platform.isWindows) {
          miniSize = Size(size.width, miniViewMainHeight + 9);
        } else {
          miniSize = Size(size.width, miniViewMainHeight);
        }
        await windowManager.setSize(miniSize);
      }
      miniModeHideOverlayTimer = Timer(const Duration(milliseconds: 1000), () {
        miniModeDisplayOverlayNotifier.value = false;
      });
    } else {
      mainSize = size;
    }
    saveConfig();
  }
}
