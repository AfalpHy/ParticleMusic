import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:searchfield/searchfield.dart';

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
                    child: SearchField(
                      autofocus: true,
                      controller: textController,
                      suggestions: const [],
                      searchInputDecoration: SearchInputDecoration(
                        hintText: AppLocalizations.of(context).searchSongs,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
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
                      onSearchTextChanged: (value) {
                        onSearchTextChanged();
                        return null;
                      },
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
