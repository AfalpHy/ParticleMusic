import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class MyTrayListener extends TrayListener {
  @override
  void onTrayIconMouseDown() async {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    // ignore: deprecated_member_use
    trayManager.popUpContextMenu(bringAppToFront: true);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show') {
      await windowManager.show();
    } else if (menuItem.key == 'exit') {
      final controller = WindowController.fromWindowId(lyricsWindowId!);
      controller.close();
      exit(0);
    } else if (menuItem.key == 'skipToPrevious') {
      await audioHandler.skipToPrevious();
    } else if (menuItem.key == 'togglePlay') {
      await audioHandler.togglePlay();
    } else if (menuItem.key == 'skipToNext') {
      await audioHandler.skipToNext();
    }
  }
}
