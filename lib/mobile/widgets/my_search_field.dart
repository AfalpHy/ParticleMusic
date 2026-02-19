import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class MySearchField extends StatelessWidget {
  final ValueNotifier<bool> isSearch = ValueNotifier(false);

  final TextEditingController textController;

  final void Function() onSearchTextChanged;

  MySearchField({
    super.key,
    required this.textController,
    required this.onSearchTextChanged,
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
                    child: TextSelectionTheme(
                      data: TextSelectionThemeData(
                        selectionColor: textColor.withAlpha(50),
                        cursorColor: textColor,
                        selectionHandleColor: textColor,
                      ),
                      child: TextField(
                        autofocus: true,
                        controller: textController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hint: Text(
                            AppLocalizations.of(context).searchSongs,
                            style: TextStyle(color: textColor),
                          ),
                          prefixIcon: Icon(Icons.search, color: iconColor),
                          suffixIcon: IconButton(
                            color: iconColor,
                            onPressed: () {
                              isSearch.value = false;
                              textController.clear();
                              FocusScope.of(context).unfocus();
                              onSearchTextChanged();
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
                          onSearchTextChanged();
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
