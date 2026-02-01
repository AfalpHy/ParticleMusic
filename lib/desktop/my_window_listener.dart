import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:particle_music/common.dart';
import 'package:window_manager/window_manager.dart';

class MyWindowListener extends WindowListener {
  @override
  void onWindowMaximize() {
    isMaximizedNotifier.value = true;
  }

  @override
  void onWindowUnmaximize() {
    isMaximizedNotifier.value = false;
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  void onWindowResized() async {
    if (miniModeNotifier.value) {
      final size = await windowManager.getSize();
      final gap = size.height - size.width;
      if (gap > 0 && gap < 120) {
        await Future.delayed(Duration(milliseconds: 100));
        if (Platform.isWindows) {
          await windowManager.setSize(Size(size.width, size.width - 7));
        } else {
          await windowManager.setSize(Size(size.width, size.width));
        }
      }
    }
  }
}
