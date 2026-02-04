import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:particle_music/common.dart';

class MySwitch extends StatelessWidget {
  final bool value;
  final void Function(bool) onToggle;

  const MySwitch({super.key, required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
      builder: (_, _, _) {
        return FlutterSwitch(
          width: 45,
          height: 20,
          toggleSize: 15,
          activeColor: enableCustomColorNotifier.value || isMobile
              ? switchColor
              : vividSwitchColor,
          inactiveColor: Colors.grey.shade300,
          value: value,
          onToggle: onToggle,
        );
      },
    );
  }
}
