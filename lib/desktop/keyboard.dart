import 'package:flutter/services.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:window_manager/window_manager.dart';

void keyboardInit() {
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.shiftLeft:
        case LogicalKeyboardKey.shiftRight:
          shiftIsPressed = true;
          break;
        case LogicalKeyboardKey.controlLeft:
        case LogicalKeyboardKey.controlRight:
          ctrlIsPressed = true;
          break;
        case LogicalKeyboardKey.space:
          if (!isTyping && playQueue.isNotEmpty) {
            audioHandler.togglePlay();
          }
          break;
        case LogicalKeyboardKey.escape:
          if (displayLyricsPageNotifier.value && isFullScreenNotifier.value) {
            windowManager.setFullScreen(false);
            isFullScreenNotifier.value = false;
          }
          break;
        case LogicalKeyboardKey.f11:
          if (displayLyricsPageNotifier.value && !isMaximizedNotifier.value) {
            windowManager.setFullScreen(true);
            isFullScreenNotifier.value = true;
          }
          break;
      }
    } else if (event is KeyUpEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.shiftLeft:
        case LogicalKeyboardKey.shiftRight:
          shiftIsPressed = false;
          break;
        case LogicalKeyboardKey.controlLeft:
        case LogicalKeyboardKey.controlRight:
          ctrlIsPressed = false;
          break;
      }
    }
    return false;
  });
}
