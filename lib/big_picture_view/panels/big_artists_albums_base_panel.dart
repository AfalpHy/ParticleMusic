import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/my_gird_delegate.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/scale_widget.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_album_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_artist_panel.dart';

abstract class BigArtistsAlbumsBasePanel extends StatefulWidget {
  const BigArtistsAlbumsBasePanel({super.key});
}

abstract class BigArtistsAlbumsBasePanelState
    extends State<BigArtistsAlbumsBasePanel> {
  late final bool isArtist;

  final currentListNotifier = ValueNotifier<List<ArtistAlbumBase>>([]);
  late final List<ArtistAlbumBase> list;

  final textController = TextEditingController();

  late final ValueNotifier<bool> randomizeNotifier;
  late final ValueNotifier<bool> isAscendingNotifier;

  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  final _scrollController = ScrollController();

  void updateCurrentList() {
    final value = textController.text;
    currentListNotifier.value = list
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier.value) {
      currentListNotifier.value.shuffle();
    }
  }

  @override
  void initState() {
    super.initState();
    updateCurrentList();
    textController.addListener(updateCurrentList);
    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    textController.dispose();
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentListNotifier,
      builder: (context, list, child) {
        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: isTooNarrow(context) ? 20 : 40,
            vertical: 75 + getTopOffset(context),
          ),
          gridDelegate: MyGirdDelegate(
            maxCrossAxisExtent: 200,
            crossAxisSpacing: 20,
            mainAxisSpacing: 10,
            textExtent: 30,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return ValueListenableBuilder(
              valueListenable: list[index].songListManager.sourceTypeNotifier,
              builder: (context, value, child) {
                final coverSong = list[index].getCoverSong();
                return ValueListenableBuilder(
                  valueListenable: coverSong.updateNotifier,
                  builder: (context, _, _) {
                    return ScaleWidget(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            children: [
                              Hero(
                                tag: 'big${coverSong.id}${list[index].name}',
                                child: CoverArtWidget(
                                  size: constraints.maxWidth,
                                  borderRadius: constraints.maxWidth * 0.1,
                                  song: coverSong,
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(0, 5),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Align(
                                    alignment: .centerLeft,
                                    child: Text(
                                      list[index].name,
                                      style: TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      onTap: () async {
                        if (isArtist) {
                          Navigator.of(context).push(
                            ZoomPageRoute(
                              builder: (context) {
                                return BigSingleArtistPanel(
                                  artist: list[index] as Artist,
                                );
                              },
                            ),
                          );
                          return;
                        }
                        final baseColor = await computeCoverArtColor(
                          list[index].getCoverSong(),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).push(
                          ZoomPageRoute(
                            builder: (context) {
                              return BigSingleAlbumPanel(
                                album: list[index] as Album,
                                baseColor: baseColor,
                              );
                            },
                          ),
                        );
                      },

                      onFocus: () {
                        final box = context.findRenderObject() as RenderBox;
                        final viewport = RenderAbstractViewport.of(box);

                        final target = viewport
                            .getOffsetToReveal(box, 0.5)
                            .offset;

                        _scrollController.animateTo(
                          target.clamp(
                            _scrollController.position.minScrollExtent,
                            _scrollController.position.maxScrollExtent,
                          ),
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
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
    );
  }
}
