import 'package:material_ui/material_ui.dart';

class ScaleWidget extends StatefulWidget {
  final Widget child;
  final void Function()? onTap;
  final void Function()? onFocus;

  final bool needFocusColor;
  final bool autoFocus;
  const ScaleWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onFocus,
    this.needFocusColor = false,
    this.autoFocus = false,
  });

  @override
  State<StatefulWidget> createState() => _ScaleWidgetState();
}

class _ScaleWidgetState extends State<ScaleWidget> {
  final focusNotifier = ValueNotifier(false);
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: focusNotifier,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value ? 1.1 : 1,
          child: InkWell(
            autofocus: widget.autoFocus,
            mouseCursor: SystemMouseCursors.click,
            hoverColor: Colors.transparent,
            focusColor: widget.needFocusColor ? null : Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onFocusChange: (value) {
              focusNotifier.value = !focusNotifier.value;
              if (value) {
                widget.onFocus?.call();
              }
            },
            onTap: widget.onTap ?? () {},

            child: widget.child,
          ),
        );
      },
    );
  }
}
