import 'dart:async';
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
      if (gap > 0 && gap < 100) {
        await Future.delayed(Duration(milliseconds: 100));
        await windowManager.setSize(Size(size.width, size.width - 7));
      }
    }
  }
}
