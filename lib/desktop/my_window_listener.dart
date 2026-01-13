import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

ValueNotifier<bool> isMaximizedNotifier = ValueNotifier(false);
ValueNotifier<bool> isFullScreenNotifier = ValueNotifier(false);

class MyWindowListener extends WindowListener {
  @override
  void onWindowMaximize() {
    isMaximizedNotifier.value = true;
  }

  @override
  void onWindowUnmaximize() {
    isMaximizedNotifier.value = false;
  }
}
