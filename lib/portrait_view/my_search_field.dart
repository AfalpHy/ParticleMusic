import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';

class MySearchField extends StatelessWidget {
  final String hintText;
  final ValueNotifier<bool> isSearch = ValueNotifier(false);

  final TextEditingController textController;

  final void Function()? onSearchTextChanged;

  MySearchField({
    super.key,
    required this.hintText,
    required this.textController,
    this.onSearchTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSearch,
      builder: (context, value, child) {
        return value
            ? Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(50, 0, 0, 0),
                  child: SizedBox(
                    height: 30,
                    child: TapRegion(
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: TextField(
                        autofocus: true,
                        controller: textController,
                        decoration: InputDecoration(
                          hint: Text(
                            hintText,
                            style: TextStyle(color: textColor),
                          ),
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: IconButton(
                            onPressed: () {
                              isSearch.value = false;
                              textController.clear();
                              FocusScope.of(context).unfocus();
                              onSearchTextChanged?.call();
                            },
                            icon: const Icon(Icons.clear),
                            padding: EdgeInsets.zero,
                          ),
                          filled: true,
                          fillColor: searchFieldColor,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          onSearchTextChanged?.call();
                        },
                      ),
                    ),
                  ),
                ),
              )
            : IconButton(
                onPressed: () {
                  isSearch.value = true;
                },
                icon: const Icon(Icons.search),
              );
      },
    );
  }
}
