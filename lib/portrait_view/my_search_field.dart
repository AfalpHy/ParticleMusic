import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';

class MySearchField extends StatefulWidget {
  final String hintText;

  final TextEditingController textController;

  final void Function()? onSearchTextChanged;

  final MyAudioMetadata? song;
  final bool useCurrentSong;
  final ValueNotifier<bool> isSearchNotifier;

  const MySearchField({
    super.key,
    required this.hintText,
    required this.textController,
    required this.isSearchNotifier,
    this.onSearchTextChanged,
    this.song,
    this.useCurrentSong = true,
  });

  @override
  State<StatefulWidget> createState() => _MySearchFieldState();
}

class _MySearchFieldState extends State<MySearchField> {
  bool isInside = true;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isSearchNotifier,
      builder: (context, value, child) {
        if (!value) {
          return IconButton(
            onPressed: () {
              widget.isSearchNotifier.value = true;
            },
            icon: const Icon(Icons.search),
          );
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(50, 0, 0, 0),
            child: SizedBox(
              height: 30,
              child: TapRegion(
                onTapOutside: (_) {
                  if (!isInside) {
                    return;
                  }
                  isInside = false;
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                onTapInside: (_) {
                  isInside = true;
                },
                child: TextField(
                  autofocus: true,
                  controller: widget.textController,
                  decoration: InputDecoration(
                    hint: Text(
                      widget.hintText,
                      style: TextStyle(color: textColor.value),
                    ),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () {
                        widget.isSearchNotifier.value = false;
                        widget.textController.clear();
                        FocusScope.of(context).unfocus();
                        widget.onSearchTextChanged?.call();
                      },
                      icon: const Icon(Icons.clear),
                      padding: EdgeInsets.zero,
                    ),
                    filled: true,
                    fillColor: colorManager
                        .getSpecificMainPageSearchFieldColorForm(
                          widget.useCurrentSong
                              ? currentSongNotifier.value
                              : widget.song,
                        ),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    widget.onSearchTextChanged?.call();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
