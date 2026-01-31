import 'dart:io';

import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:particle_music/desktop/single_instance.dart';
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
      // make sure the music stops after exiting
      await audioHandler.stop();

      lyricsWindowController!.close();
      await windowManager.setPreventClose(false);
      await SingleInstance.end();
      windowManager.close();

      // only exit can quit on macos
      if (Platform.isMacOS) {
        exit(0);
      }
    } else if (menuItem.key == 'skipToPrevious') {
      await audioHandler.skipToPrevious();
    } else if (menuItem.key == 'togglePlay') {
      await audioHandler.togglePlay();
    } else if (menuItem.key == 'skipToNext') {
      await audioHandler.skipToNext();
    } else if (menuItem.key == 'unlock') {
      await lyricsWindowController?.unlock();
    }
  }
}
