import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/scale_widget.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_album_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_artist_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_folder_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_playlist_panel.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

class BigHomePanel extends StatefulWidget {
  const BigHomePanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigHomePanelState();
}

class _BigHomePanelState extends State<BigHomePanel> {
  final verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isStreamSource) {
        if (artistAlbumManager.artistList.isEmpty) {
          artistAlbumManager.loadArtists().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }

        if (artistAlbumManager.albumList.isEmpty) {
          artistAlbumManager.loadAlbums().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }

        if (sourceType == .navidrome) {
          if (history.rankingAlbumList.isEmpty) {
            history.loadAlbums(true).then((_) {
              if (mounted) {
                setState(() {});
              }
            });
          }
          if (history.recentlyAlbumList.isEmpty) {
            history.loadAlbums(false).then((_) {
              if (mounted) {
                setState(() {});
              }
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      controller: verticalController,
      padding: EdgeInsets.symmetric(vertical: 75 + getTopOffset(context)),
      children: [
        _ListView(
          title: l10n.artists,
          count: artistAlbumManager.artistList.length,
          getPicture: (index) => artistAlbumManager.artistList[index].picture,
          onTap: (index) {
            Navigator.of(context).push(
              ZoomPageRoute(
                builder: (context) {
                  return BigSingleArtistPanel(
                    artist: artistAlbumManager.artistList[index],
                  );
                },
              ),
            );
          },
          getBottomWidget: (index) {
            return ListTile(
              contentPadding: .zero,
              mouseCursor: SystemMouseCursors.click,
              title: Text(
                artistAlbumManager.artistList[index].name,
                style: .new(overflow: .ellipsis),
              ),

              visualDensity: .new(vertical: -4),
            );
          },
          verticalController: verticalController,
        ),

        _ListView(
          title: l10n.albums,
          count: artistAlbumManager.albumList.length,
          getPicture: (index) => artistAlbumManager.albumList[index].picture,
          onTap: (index) async {
            final baseColor = await computeColor(
              artistAlbumManager.albumList[index].picture,
            );
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).push(
              ZoomPageRoute(
                builder: (context) {
                  return BigSingleAlbumPanel(
                    album: artistAlbumManager.albumList[index],
                    baseColor: baseColor,
                  );
                },
              ),
            );
          },
          getBottomWidget: (index) {
            return ListTile(
              contentPadding: .zero,
              mouseCursor: SystemMouseCursors.click,
              title: Text(
                artistAlbumManager.albumList[index].name,
                style: .new(overflow: .ellipsis),
              ),

              visualDensity: .new(vertical: -4),
            );
          },
          getTag: (index) =>
              'big${artistAlbumManager.albumList[index].picture.id}${artistAlbumManager.albumList[index].name}',

          verticalController: verticalController,
        ),

        _ListView(
          title: l10n.folders,
          count: library.folderList.length,
          getPicture: (index) =>
              getFirstSong(library.folderList[index].songList)?.picture,
          onTap: (index) async {
            final folder = library.folderList[index];
            final baseColor = await computeColor(
              getFirstSong(folder.songList)?.picture,
            );
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).push(
              ZoomPageRoute(
                builder: (context) {
                  return BigSingleFolderPanel(
                    folder: folder,
                    baseColor: baseColor,
                  );
                },
              ),
            );
          },
          getBottomWidget: (index) {
            return ListTile(
              contentPadding: .zero,
              mouseCursor: SystemMouseCursors.click,
              title: Text(
                library.folderList[index].id,
                style: .new(overflow: .ellipsis),
              ),

              visualDensity: .new(vertical: -4),
            );
          },
          getTag: (index) {
            final folder = library.folderList[index];

            return 'big${getFirstSong(folder.songList)?.id}${folder.id}';
          },
          verticalController: verticalController,
          changeNotifier: (index) {
            return library.folderList[index].changeNotifier;
          },
        ),

        _ListView(
          title: l10n.ranking,
          count: sourceType == .navidrome
              ? history.rankingAlbumList.length
              : history.rankingSongList.length,
          getPicture: (index) => sourceType == .navidrome
              ? history.rankingAlbumList[index].picture
              : history.rankingSongList[index].picture,
          onTap: (index) async {
            if (sourceType == .navidrome) {
              final album = history.rankingAlbumList[index];
              final baseColor = await computeColor(album.picture);
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).push(
                ZoomPageRoute(
                  builder: (context) {
                    return BigSingleAlbumPanel(
                      album: album,
                      baseColor: baseColor,
                    );
                  },
                ),
              );
            } else {
              showSongOptions(
                context: context,
                song: history.rankingSongList[index],
                includeGoToArtist: true,
                includeGoToAlbum: true,
              );
            }
          },
          getBottomWidget: (index) {
            if (sourceType == .navidrome) {
              return ListTile(
                contentPadding: .zero,
                mouseCursor: SystemMouseCursors.click,
                title: Text(
                  history.rankingAlbumList[index].name,
                  style: .new(overflow: .ellipsis),
                ),
                visualDensity: .new(vertical: -4),
              );
            }
            final song = history.rankingSongList[index];
            return ListTile(
              contentPadding: .zero,
              mouseCursor: SystemMouseCursors.click,
              title: Text(getTitle(song), style: .new(overflow: .ellipsis)),
              subtitle: Text(
                '${getArtist(song)} - ${getAlbum(song)}',
                style: .new(overflow: .ellipsis),
              ),

              visualDensity: .new(vertical: -4),
            );
          },
          verticalController: verticalController,
        ),

        _ListView(
          title: l10n.recently,
          count: sourceType == .navidrome
              ? history.recentlyAlbumList.length
              : history.recentlySongList.length,
          getPicture: (index) => sourceType == .navidrome
              ? history.recentlyAlbumList[index].picture
              : history.recentlySongList[index].picture,
          onTap: (index) async {
            if (sourceType == .navidrome) {
              final album = history.recentlyAlbumList[index];
              final baseColor = await computeColor(album.picture);
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).push(
                ZoomPageRoute(
                  builder: (context) {
                    return BigSingleAlbumPanel(
                      album: album,
                      baseColor: baseColor,
                    );
                  },
                ),
              );
            } else {
              showSongOptions(
                context: context,
                song: history.recentlySongList[index],
                includeGoToArtist: true,
                includeGoToAlbum: true,
              );
            }
          },
          getBottomWidget: (index) {
            if (sourceType == .navidrome) {
              return ListTile(
                contentPadding: .zero,
                mouseCursor: SystemMouseCursors.click,
                title: Text(
                  history.recentlyAlbumList[index].name,
                  style: .new(overflow: .ellipsis),
                ),
                visualDensity: .new(vertical: -4),
              );
            }
            final song = history.recentlySongList[index];
            return ListTile(
              contentPadding: .zero,
              mouseCursor: SystemMouseCursors.click,
              title: Text(getTitle(song), style: .new(overflow: .ellipsis)),
              subtitle: Text(
                '${getArtist(song)} - ${getAlbum(song)}',
                style: .new(overflow: .ellipsis),
              ),

              visualDensity: .new(vertical: -4),
            );
          },
          verticalController: verticalController,
        ),

        ValueListenableBuilder(
          valueListenable: playlistManager.updateNotifier,
          builder: (context, value, child) {
            return _ListView(
              title: l10n.playlists,
              count: playlistManager.playlists.length,
              getPicture: (index) =>
                  playlistManager.playlists[index].getCoverSong()?.picture,
              onTap: (index) async {
                final baseColor = await computeColor(
                  playlistManager.playlists[index].getCoverSong()?.picture,
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).push(
                  ZoomPageRoute(
                    builder: (context) {
                      return BigSinglePlaylistPanel(
                        playlist: playlistManager.playlists[index],
                        baseColor: baseColor,
                      );
                    },
                  ),
                );
              },
              getBottomWidget: (index) {
                return ListTile(
                  contentPadding: .zero,
                  mouseCursor: SystemMouseCursors.click,
                  title: Text(
                    index == 0
                        ? l10n.favorites
                        : playlistManager.playlists[index].name,
                    style: .new(overflow: .ellipsis),
                  ),

                  visualDensity: .new(vertical: -4),
                );
              },
              getTag: (index) =>
                  'big${playlistManager.playlists[index].getCoverSong()?.id}${index == 0 ? l10n.favorites : playlistManager.playlists[index].name}',
              verticalController: verticalController,
              changeNotifier: (index) =>
                  playlistManager.playlists[index].changeNotifier,
            );
          },
        ),
      ],
    );
  }
}

class _ListView extends StatefulWidget {
  final String title;
  final int count;
  final MyPicture? Function(int) getPicture;
  final void Function(int) onTap;
  final Widget Function(int) getBottomWidget;
  final String Function(int)? getTag;
  final ScrollController verticalController;
  final ValueNotifier Function(int)? changeNotifier;

  const _ListView({
    required this.title,
    required this.count,
    required this.getPicture,
    required this.onTap,
    required this.getBottomWidget,
    this.getTag,
    required this.verticalController,
    this.changeNotifier,
  });

  @override
  State<StatefulWidget> createState() => _ListViewState();
}

class _ListViewState extends State<_ListView> {
  final rowKey = GlobalKey();
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) {
      return SizedBox.shrink();
    }
    return Column(
      mainAxisSize: .min,
      children: [
        Row(
          children: [
            SizedBox(width: isTooNarrow(context) ? 20 : 40),
            Text(widget.title, style: .new(fontSize: 22, fontWeight: .bold)),
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.arrow_forward_ios_rounded),
            ),
          ],
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            key: rowKey,
            controller: controller,
            padding: EdgeInsets.symmetric(
              horizontal: isTooNarrow(context) ? 20 : 40,
            ),
            scrollDirection: .horizontal,
            itemCount: widget.count,
            separatorBuilder: (context, index) {
              return const SizedBox(width: 30);
            },
            itemBuilder: (context, index) {
              return ListenableBuilder(
                listenable: Listenable.merge([
                  widget.changeNotifier?.call(index),
                ]),
                builder: (context, _) {
                  final picture = widget.getPicture(index);
                  return ScaleWidget(
                    onTap: () {
                      widget.onTap.call(index);
                    },
                    onFocus: () {
                      final itemBox = context.findRenderObject() as RenderBox;
                      final horizontalViewport = RenderAbstractViewport.of(
                        itemBox,
                      );

                      final horizontalTarget =
                          horizontalViewport
                              .getOffsetToReveal(itemBox, 0.5)
                              .offset +
                          itemBox.size.width / 2;

                      controller.animateTo(
                        horizontalTarget.clamp(
                          controller.position.minScrollExtent,
                          controller.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      );

                      final rowBox =
                          rowKey.currentContext!.findRenderObject()
                              as RenderBox;
                      final verticalViewport = RenderAbstractViewport.of(
                        rowBox,
                      );

                      final verticalTarget =
                          verticalViewport
                              .getOffsetToReveal(rowBox, 0.5)
                              .offset +
                          rowBox.size.height / 2;

                      widget.verticalController.animateTo(
                        verticalTarget.clamp(
                          widget.verticalController.position.minScrollExtent,
                          widget.verticalController.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        SizedBox(height: 15),
                        widget.getTag != null
                            ? Hero(
                                tag: widget.getTag!.call(index),
                                child: CoverArtWidget(
                                  size: 200,
                                  borderRadius: 20,
                                  picture: picture,
                                ),
                              )
                            : CoverArtWidget(
                                size: 200,
                                borderRadius: 20,
                                picture: picture,
                              ),
                        SizedBox(
                          width: 180,
                          child: widget.getBottomWidget(index),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
