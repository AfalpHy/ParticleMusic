import 'dart:async';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_location.dart';
import 'package:particle_music/song_list_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:searchfield/searchfield.dart';

class SongsScaffold extends StatelessWidget {
  final listIsScrollingNotifier = ValueNotifier(false);
  final songListNotifer = ValueNotifier<List<AudioMetadata>>(librarySongs);

  final itemScrollController = ItemScrollController();

  final Future<void> Function() reload;

  SongsScaffold({super.key, required this.reload});

  @override
  Widget build(BuildContext context) {
    Timer? timer;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text("Songs"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                builder: (context) {
                  return mySheet(
                    Column(
                      children: [
                        ListTile(
                          title: Text(
                            'Library',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                        Divider(
                          color: Colors.grey.shade300,
                          thickness: 0.5,
                          height: 1,
                        ),

                        ListTile(
                          leading: Icon(Icons.refresh_rounded),
                          title: Text(
                            'Reload Library',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          onTap: () async {
                            await reload();
                            songListNotifer.value = librarySongs;
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                if (playQueue.isNotEmpty) {
                  listIsScrollingNotifier.value = true;
                  if (timer != null) {
                    timer!.cancel();
                    timer = null;
                  }
                }
              } else {
                if (listIsScrollingNotifier.value) {
                  timer ??= Timer(const Duration(milliseconds: 3000), () {
                    listIsScrollingNotifier.value = false;
                    timer = null;
                  });
                }
              }
              return false;
            },
            child: Column(
              children: [
                searchAndUpdateWidget(context),
                ValueListenableBuilder(
                  valueListenable: songListNotifer,
                  builder: (context, songList, child) {
                    return Expanded(
                      child: ScrollablePositionedList.builder(
                        itemScrollController: itemScrollController,
                        itemCount: songList.length + 1,
                        itemBuilder: (context, index) {
                          if (index < songList.length) {
                            return SongListTile(index: index, source: songList);
                          } else {
                            return SizedBox(height: 90);
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: MyLocation(
              itemScrollController: itemScrollController,
              listIsScrollingNotifier: listIsScrollingNotifier,
              songListNotifer: songListNotifer,
            ),
          ),
        ],
      ),
    );
  }

  Widget searchAndUpdateWidget(BuildContext context) {
    final textController = TextEditingController();
    ValueNotifier<bool> textIsNotEmptyNotifier = ValueNotifier(false);
    return Row(
      children: [
        SizedBox(width: 20),

        Expanded(
          child: SizedBox(
            height: 35,
            child: SearchField(
              controller: textController,
              suggestions: [],
              searchInputDecoration: SearchInputDecoration(
                hintText: 'Search songs',
                prefixIcon: Icon(Icons.search),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: textIsNotEmptyNotifier,
                  builder: (context, value, child) {
                    return value
                        ? IconButton(
                            onPressed: () {
                              textIsNotEmptyNotifier.value = false;
                              songListNotifer.value = librarySongs;
                              textController.clear();
                              FocusScope.of(context).unfocus();
                            },
                            icon: Icon(Icons.clear),
                            padding: EdgeInsets.zero,
                          )
                        : SizedBox();
                  },
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSearchTextChanged: (value) {
                textIsNotEmptyNotifier.value = value.isNotEmpty;
                songListNotifer.value = librarySongs
                    .where(
                      (song) =>
                          (value.isEmpty) ||
                          (song.title?.toLowerCase().contains(
                                value.toLowerCase(),
                              ) ??
                              false) ||
                          (song.artist?.toLowerCase().contains(
                                value.toLowerCase(),
                              ) ??
                              false) ||
                          (song.album?.toLowerCase().contains(
                                value.toLowerCase(),
                              ) ??
                              false),
                    )
                    .toList();
                return null;
              },
            ),
          ),
        ),
        SizedBox(width: 20),
      ],
    );
  }
}
