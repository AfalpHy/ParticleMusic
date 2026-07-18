import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';

class BigSongsPanel extends StatefulWidget {
  const BigSongsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigSongsPanelState();
}

class _BigSongsPanelState extends State<BigSongsPanel> {
  final textController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  late SongListManager songListManager;
  late List<MyAudioMetadata> songList;

  final currentSongListNotifier = ValueNotifier<List<MyAudioMetadata>>([]);

  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  void updateSongList() {
    final value = textController.text;
    final filteredSongList = filterSongList(songList, value);
    sortSongList(sortTypeNotifier.value, filteredSongList);
    currentSongListNotifier.value = filteredSongList;
  }

  @override
  void initState() {
    super.initState();
    songListManager = library.songListManager;
    songList = songListManager.getSongList2(.navidrome);
    updateSongList();
    textController.addListener(updateSongList);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: ValueListenableBuilder(
        valueListenable: currentSongListNotifier,
        builder: (context, currentSongList, child) {
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              childAspectRatio: 0.8,
            ),
            itemCount: currentSongList.length,
            itemBuilder: (context, index) {
              final song = currentSongList[index];
              return ValueListenableBuilder(
                valueListenable: song.updateNotifier,
                builder: (_, _, _) {
                  bool focus = false;
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return Transform.scale(
                        scale: focus ? 1.0 : 0.9,
                        child: LayoutBuilder(
                          builder: (context, constraint) {
                            return InkWell(
                              mouseCursor: SystemMouseCursors.click,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              onFocusChange: (value) {
                                setState(() {
                                  focus = value;
                                });
                              },
                              onTap: () async {
                                audioHandler.currentIndex = index;
                                await audioHandler.setPlayQueue(
                                  currentSongList,
                                );
                                await audioHandler.load();
                                audioHandler.play();
                              },
                              child: Column(
                                children: [
                                  CoverArtWidget(
                                    size: constraint.maxWidth,
                                    borderRadius: constraint.maxWidth / 10,
                                    song: song,
                                  ),
                                  ListTile(
                                    mouseCursor: SystemMouseCursors.click,
                                    title: Text(
                                      getTitle(song),
                                      style: .new(overflow: .ellipsis),
                                    ),
                                    subtitle: Text(
                                      '${getArtist(song)} - ${getAlbum(song)}',
                                      style: .new(overflow: .ellipsis),
                                    ),
                                    visualDensity: .new(vertical: -4),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
