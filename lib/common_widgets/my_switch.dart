import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/utils.dart';

class MySwitch extends StatelessWidget {
  final String? trueText;
  final String? falseText;
  final ValueNotifier<bool> valueNotifier;
  final void Function()? onToggleCallBack;

  const MySwitch({
    super.key,
    this.trueText,
    this.falseText,
    required this.valueNotifier,
    this.onToggleCallBack,
  });

  @override
  Widget build(BuildContext context) {
    if (trueText == null) {
      return switcher();
    }
    return Row(
      children: [
        ValueListenableBuilder(
          valueListenable: valueNotifier,
          builder: (context, value, child) {
            return Text(
              value ? trueText! : falseText!,
              style: TextStyle(color: colorManager.getSpecificTextColor()),
            );
          },
        ),
        SizedBox(width: 10),
        switcher(),
      ],
    );
  }

  Widget switcher() {
    FocusNode focusNode = FocusNode();

    return StatefulBuilder(
      builder: (context, setState) {
        return InkWell(
          focusColor: Colors.transparent,
          mouseCursor: SystemMouseCursors.click,
          focusNode: focusNode,
          onFocusChange: (value) {
            setState(() {});
          },
          onTap: () {
            valueNotifier.value = !valueNotifier.value;
            onToggleCallBack?.call();
          },
          child: AnimatedScale(
            duration: Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            scale: focusNode.hasFocus ? 1.3 : 1.0,
            child: ValueListenableBuilder(
              valueListenable: valueNotifier,
              builder: (context, value, child) {
                return ValueListenableBuilder(
                  valueListenable: switchColor.valueNotifier,
                  builder: (_, _, _) {
                    return FlutterSwitch(
                      width: 45,
                      height: 20,
                      toggleSize: 15,
                      activeColor: switchColor.value,
                      inactiveColor: Colors.grey.shade300,
                      value: value,
                      onToggle: (value) {
                        tryVibrate();
                        valueNotifier.value = value;
                        onToggleCallBack?.call();
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
