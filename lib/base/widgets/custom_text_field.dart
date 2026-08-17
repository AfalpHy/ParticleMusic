import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/keyboard.dart';

class CustomTextField extends StatefulWidget {
  final String? name;
  final TextEditingController controller;
  final bool expand;
  final bool onlyNumber;
  final bool compact;
  final bool autoFocus;
  final bool needObscure;

  const CustomTextField(
    this.name,
    this.controller, {
    super.key,
    this.expand = false,
    this.onlyNumber = false,
    this.compact = true,
    this.autoFocus = false,
    this.needObscure = false,
  });

  @override
  State<StatefulWidget> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  FocusNode textFieldNode = FocusNode();
  late bool obscure;
  @override
  void initState() {
    super.initState();
    textFieldNode.addListener(() {
      isTyping = textFieldNode.hasFocus;
    });
    obscure = widget.needObscure;
  }

  @override
  void dispose() {
    textFieldNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specificTextcolor = colorManager.getSpecificTextColor();

    return Column(
      children: [
        if (widget.name != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${widget.name}:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

        Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: specificTextcolor.withAlpha(50),
              cursorColor: specificTextcolor,
              selectionHandleColor: specificTextcolor,
            ),
          ),
          child: TextField(
            focusNode: textFieldNode,
            autofocus: widget.autoFocus,
            keyboardType: widget.onlyNumber ? .number : null,
            minLines: widget.expand ? 3 : 1,
            maxLines: widget.expand ? null : 1,
            style: TextStyle(
              fontSize: widget.compact ? 12 : 14,
              color: specificTextcolor,
            ),
            controller: widget.controller,
            obscureText: obscure,
            obscuringCharacter: '●',
            decoration: InputDecoration(
              visualDensity: widget.compact ? .new(vertical: -2.5) : null,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: specificTextcolor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: specificTextcolor, width: 1.5),
              ),
              suffixIconConstraints: BoxConstraints(
                maxWidth: 40,
                maxHeight: 40,
              ),
              suffixIcon: widget.needObscure
                  ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscure = !obscure;
                        });
                      },
                    )
                  : null,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
