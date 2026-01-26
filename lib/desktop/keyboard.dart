import 'package:flutter/services.dart';
import 'package:particle_music/common.dart';

void keyboardInit() {
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey.keyLabel == 'Shift Left' ||
          event.logicalKey.keyLabel == 'Shift Right') {
        shiftIsPressed = true;
      }
      if (event.logicalKey.keyLabel == 'Control Left' ||
          event.logicalKey.keyLabel == 'Control Right') {
        ctrlIsPressed = true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey.keyLabel == 'Shift Left' ||
          event.logicalKey.keyLabel == 'Shift Right') {
        shiftIsPressed = false;
      }
      if (event.logicalKey.keyLabel == 'Control Left' ||
          event.logicalKey.keyLabel == 'Control Right') {
        ctrlIsPressed = false;
      }
    }
    return false;
  });
}
