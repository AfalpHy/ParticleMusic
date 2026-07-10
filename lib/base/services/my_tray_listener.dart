import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/extensions/window_controller_extension.dart';
import 'package:sylvakru/base/services/exit.dart';
import 'package:sylvakru/landscape_view/desktop_lyrics.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class MyTrayListener extends TrayListener {
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    // ignore: deprecated_member_use
    trayManager.popUpContextMenu(bringAppToFront: true);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      windowManager.show();
    } else if (menuItem.key == 'exit') {
      exitApp();
    } else if (menuItem.key == 'skipToPrevious') {
      audioHandler.skipToPrevious();
    } else if (menuItem.key == 'togglePlay') {
      audioHandler.togglePlay();
    } else if (menuItem.key == 'skipToNext') {
      audioHandler.skipToNext();
    } else if (menuItem.key == 'unlock') {
      // Escape hatch for when the lyrics window is click-through locked:
      // its own unlock button is unreachable in that state.
      lyricsWindowController?.unlock();
    }
  }
}
