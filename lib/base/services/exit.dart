import 'dart:io';

import 'package:sylvakru/base/extensions/window_controller_extension.dart';
import 'package:sylvakru/base/services/single_instance.dart';
import 'package:sylvakru/landscape_view/desktop_lyrics.dart';
import 'package:window_manager/window_manager.dart';

bool _exited = false;

void exitApp() async {
  if (_exited) {
    return;
  }

  // Fire-and-forget: initDesktopLyrics() may have failed to create this
  // window (controller null) and the call is best-effort anyway, so it
  // must never block or fail the actual app shutdown below.
  lyricsWindowController?.close();

  await SingleInstance.end();
  // only this allows quick exit on Windows
  if (Platform.isWindows) {
    await windowManager.setPreventClose(false);
    _exited = true;
    windowManager.close();
    return;
  }

  exit(0);
}
