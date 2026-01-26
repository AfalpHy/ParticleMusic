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
}
