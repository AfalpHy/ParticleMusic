import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      controller: verticalController,
      padding: EdgeInsets.symmetric(vertical: 75 + getTopOffset(context)),
      children: [
        _ListView(
          title: l10n.artists,
          count: artistAlbumManager.artistList.length,
          getCoverSong: (index) {
            return artistAlbumManager.artistList[index].getCoverSong();
          },
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
          getBottomTitle: (index) => artistAlbumManager.artistList[index].name,
          verticalController: verticalController,
          changeNotifier: (index) => artistAlbumManager
              .artistList[index]
              .songListManager
              .changeNotifier,
        ),

        _ListView(
          title: l10n.albums,
          count: artistAlbumManager.albumList.length,
          getCoverSong: (index) =>
              artistAlbumManager.albumList[index].getCoverSong(),
          onTap: (index) async {
            final baseColor = await computeCoverArtColor(
              artistAlbumManager.albumList[index].getCoverSong(),
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
          getBottomTitle: (index) => artistAlbumManager.albumList[index].name,
          getTag: (index) =>
              'big${artistAlbumManager.albumList[index].getCoverSong().id}${artistAlbumManager.albumList[index].name}',

          verticalController: verticalController,
          changeNotifier: (index) => artistAlbumManager
              .albumList[index]
              .songListManager
              .changeNotifier,
        ),

        _ListView(
          title: l10n.folders,
          count:
              library.localFolderList.length + library.webdavFolderList.length,
          getCoverSong: (index) {
            late Folder folder;
            if (index < library.localFolderList.length) {
              folder = library.localFolderList[index];
            } else {
              folder = library
                  .webdavFolderList[index - library.localFolderList.length];
            }
            return getFirstSong(folder.songList);
          },
          onTap: (index) async {
            late Folder folder;
            if (index < library.localFolderList.length) {
              folder = library.localFolderList[index];
            } else {
              folder = library
                  .webdavFolderList[index - library.localFolderList.length];
            }
            final baseColor = await computeCoverArtColor(
              getFirstSong(folder.songList),
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
          getBottomTitle: (index) => library.localFolderList[index].id,
          getTag: (index) {
            late Folder folder;
            if (index < library.localFolderList.length) {
              folder = library.localFolderList[index];
            } else {
              folder = library
                  .webdavFolderList[index - library.localFolderList.length];
            }
            return 'big${getFirstSong(folder.songList)?.id}${folder.id}';
          },
          verticalController: verticalController,
          changeNotifier: (index) {
            late Folder folder;
            if (index < library.localFolderList.length) {
              folder = library.localFolderList[index];
            } else {
              folder = library
                  .webdavFolderList[index - library.localFolderList.length];
            }
            return folder.changeNotifier;
          },
        ),

        _ListView(
          title: l10n.ranking,
          count: history.rankingSongListManager.getSongList().length,
          getCoverSong: (index) =>
              history.rankingSongListManager.getSongList()[index],
          onTap: (index) {
            showSongOptions(
              context: context,
              song: history.rankingSongListManager.getSongList()[index],
              includeGoToArtist: true,
              includeGoToAlbum: true,
            );
          },
          verticalController: verticalController,
        ),

        _ListView(
          title: l10n.recently,
          count: history.recentlySongListManager.getSongList().length,
          getCoverSong: (index) =>
              history.recentlySongListManager.getSongList()[index],
          onTap: (index) {
            showSongOptions(
              context: context,
              song: history.recentlySongListManager.getSongList()[index],
              includeGoToArtist: true,
              includeGoToAlbum: true,
            );
          },
          verticalController: verticalController,
        ),

        _ListView(
          title: l10n.playlists,
          count: playlistManager.playlists.length,
          getCoverSong: (index) =>
              playlistManager.playlists[index].getCoverSong(),
          onTap: (index) async {
            final baseColor = await computeCoverArtColor(
              playlistManager.playlists[index].getCoverSong(),
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
          getBottomTitle: (index) => index == 0
              ? l10n.favorites
              : playlistManager.playlists[index].name,
          getTag: (index) =>
              'big${playlistManager.playlists[index].getCoverSong()?.id}${playlistManager.playlists[index].name}',
          verticalController: verticalController,
          changeNotifier: (index) =>
              playlistManager.playlists[index].songListManager.changeNotifier,
        ),
      ],
    );
  }
}

class _ListView extends StatefulWidget {
  final String title;
  final int count;
  final MyAudioMetadata? Function(int) getCoverSong;
  final void Function(int) onTap;
  final String Function(int)? getBottomTitle;
  final String Function(int)? getTag;
  final ScrollController verticalController;
  final ValueNotifier Function(int)? changeNotifier;

  const _ListView({
    required this.title,
    required this.count,
    required this.getCoverSong,
    required this.onTap,
    this.getBottomTitle,
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
          height: widget.getBottomTitle == null ? 280 : 260,
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
                  final song = widget.getCoverSong(index);
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
                      children: [
                        SizedBox(height: 15),
                        widget.getTag != null
                            ? Hero(
                                tag: widget.getTag!.call(index),
                                child: CoverArtWidget(
                                  size: 200,
                                  borderRadius: 20,
                                  song: song,
                                ),
                              )
                            : CoverArtWidget(
                                size: 200,
                                borderRadius: 20,
                                song: song,
                              ),
                        SizedBox(
                          width: 180,
                          child: ListTile(
                            contentPadding: .zero,
                            mouseCursor: SystemMouseCursors.click,
                            title: Text(
                              widget.getBottomTitle == null
                                  ? getTitle(song)
                                  : widget.getBottomTitle!.call(index),
                              style: .new(overflow: .ellipsis),
                            ),
                            subtitle: widget.getBottomTitle == null
                                ? Text(
                                    '${getArtist(song)} - ${getAlbum(song)}',
                                    style: .new(overflow: .ellipsis),
                                  )
                                : null,
                            visualDensity: .new(vertical: -4),
                          ),
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
