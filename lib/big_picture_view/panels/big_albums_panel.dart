import 'package:flutter/widgets.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';

class BigAlbumsPanel extends StatefulWidget {
  const BigAlbumsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigAlbumsPanelState();
}

class _BigAlbumsPanelState extends State<BigAlbumsPanel> {
  late final ValueNotifier<List<Album>> currentAlbumListNotifier;

  final textController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  late ValueNotifier<bool> randomizeNotifier;
  late ValueNotifier<bool> isAscendingNotifier;
  late ValueNotifier<bool> useLargePictureNotifier;

  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  void updateCurrentList() {
    final value = textController.text;
    currentAlbumListNotifier.value = artistAlbumManager.albumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier.value) {
      currentAlbumListNotifier.value.shuffle();
    }
  }

  @override
  void initState() {
    super.initState();
    currentAlbumListNotifier = ValueNotifier(artistAlbumManager.albumList);

    randomizeNotifier = artistAlbumManager.getIsRandomizeNotifier(false);

    isAscendingNotifier = artistAlbumManager.getIsAscendingNotifier(false);

    useLargePictureNotifier = artistAlbumManager.getUseLargePictureNotifier(
      false,
    );

    updateCurrentList();
    textController.addListener(updateCurrentList);
    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    textController.dispose();
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: ValueListenableBuilder(
        valueListenable: currentAlbumListNotifier,
        builder: (context, list, child) {
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              childAspectRatio: 0.9,
            ),
            itemCount: list.length,
            itemBuilder: (context, index) {
              return ValueListenableBuilder(
                valueListenable: list[index].songListManager.sourceTypeNotifier,
                builder: (context, value, child) {
                  final coverSong = list[index].getCoverSong();
                  return ValueListenableBuilder(
                    valueListenable: coverSong.updateNotifier,
                    builder: (_, _, _) {
                      bool focus = false;
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return Focus(
                            onFocusChange: (value) {
                              setState(() {
                                focus = value;
                              });
                            },
                            child: Transform.scale(
                              scale: focus ? 1.0 : 0.9,
                              child: LayoutBuilder(
                                builder: (context, constraint) {
                                  return Column(
                                    children: [
                                      CoverArtWidget(
                                        size: constraint.maxWidth,
                                        borderRadius: constraint.maxWidth / 10,
                                        song: coverSong,
                                      ),
                                      Transform.translate(
                                        offset: Offset(0, 10),
                                        child: SizedBox(
                                          width: constraint.maxWidth - 15,
                                          child: Text(
                                            list[index].name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
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
