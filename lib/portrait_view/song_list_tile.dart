import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/common_widgets/playlist_widgets.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/edit_metadata.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/common_widgets/song_info.dart';
import 'package:particle_music/utils.dart';
import '../common_widgets/cover_art_widget.dart';

class SongListTile extends StatelessWidget {
  final int index;
  final List<MyAudioMetadata> songList;
  final Folder? folder;
  final Playlist? playlist;

  final bool isLibrary;
  final bool isRanking;
  final bool reorderable;

  const SongListTile({
    super.key,
    required this.index,
    required this.songList,
    required this.folder,
    required this.playlist,
    required this.isLibrary,
    required this.isRanking,
    required this.reorderable,
  });

  @override
  Widget build(BuildContext context) {
    final song = songList[index];

    return ValueListenableBuilder(
      valueListenable: song.updateNotifier,
      builder: (context, value, child) {
        return ListTile(
          contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
          leading: CoverArtWidget(size: 40, borderRadius: 4, song: song),
          title: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (_, currentSong, _) {
              return ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (context, value, child) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong ? highlightTextColor : null,
                      fontWeight: song == currentSong ? FontWeight.bold : null,
                    ),
                  );
                },
              );
            },
          ),

          subtitle: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: song.isFavoriteNotifier,
                builder: (_, value, _) {
                  return value
                      ? SizedBox(
                          width: 20,
                          child: Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 15,
                          ),
                        )
                      : SizedBox();
                },
              ),
              Expanded(
                child: Text(
                  "${getArtist(song)} - ${getAlbum(song)}",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          onTap: () async {
            audioHandler.currentIndex = index;
            await audioHandler.setPlayQueue(songList);
            await audioHandler.load();
            audioHandler.play();
          },
          trailing: isRanking
              ? SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Spacer(),
                      ImageIcon(playOutlinedImage, size: 15),
                      Text(song.playCount.toString()),
                      moreButton(context),
                    ],
                  ),
                )
              : moreButton(context),
        );
      },
    );
  }

  Widget moreButton(BuildContext context) {
    final song = songList[index];
    final l10n = AppLocalizations.of(context);

    return IconButton(
      icon: Icon(Icons.more_vert, size: 15),
      onPressed: () {
        tryVibrate();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (context) {
            return MySheet(
              Column(
                children: [
                  SizedBox(height: 5),

                  ListTile(
                    leading: CoverArtWidget(
                      size: 50,
                      borderRadius: 5,
                      song: song,
                    ),
                    title: Text(
                      getTitle(song),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "${getArtist(song)} - ${getAlbum(song)}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  SizedBox(height: 5),
                  Divider(color: dividerColor, thickness: 0.5, height: 1),
                  SizedBox(height: 5),

                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      children: [
                        if (reorderable)
                          ListTile(
                            leading: Icon(Icons.vertical_align_top_rounded),
                            title: Text(
                              l10n.move2Top,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -4,
                            ),
                            onTap: () {
                              Navigator.pop(context);

                              if (isLibrary) {
                                final item = library.songList.removeAt(index);
                                library.songList.insert(0, item);
                                library.update();
                              } else if (folder != null) {
                                final item = folder!.songList.removeAt(index);
                                folder!.songList.insert(0, item);
                                folder!.update();
                              } else {
                                if (song.isNavidrome) {
                                  final item = playlist!.navidromeSongList
                                      .removeAt(index);
                                  playlist!.navidromeSongList.insert(0, item);
                                } else {
                                  final item = playlist!.songList.removeAt(
                                    index,
                                  );
                                  playlist!.songList.insert(0, item);
                                }
                                playlist!.update();
                              }
                            },
                          ),
                        ListTile(
                          leading: Icon(Icons.play_arrow_rounded),
                          title: Text(
                            l10n.playNow,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () {
                            audioHandler.singlePlay(songList[index]);
                            Navigator.pop(context);
                            audioHandler.saveAllStates();
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.navigate_next_rounded),
                          title: Text(
                            l10n.playNext,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () {
                            if (playQueue.isEmpty) {
                              audioHandler.singlePlay(songList[index]);
                            } else {
                              audioHandler.insert2Next(songList[index]);
                            }
                            Navigator.pop(context);
                            audioHandler.saveAllStates();
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.playlist_add_rounded),
                          title: Text(
                            l10n.add2Queue,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () {
                            if (playQueue.isEmpty) {
                              audioHandler.singlePlay(songList[index]);
                            } else {
                              audioHandler.add2Last(songList[index]);
                            }
                            Navigator.pop(context);
                            audioHandler.saveAllStates();
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.add_rounded),
                          title: Text(
                            l10n.add2Playlist,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () {
                            Navigator.pop(context);

                            showAddPlaylistSheet(context, [song]);
                          },
                        ),

                        ListTile(
                          leading: Icon(Icons.people),
                          title: Text(
                            l10n.go2Artist,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            final artists = getArtists(getArtist(song));
                            if (artists.length > 1) {
                              showAnimationDialog(
                                context: context,
                                child: SizedBox(
                                  width: 300,
                                  height: 350,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ListView.builder(
                                      itemCount: artists.length,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          title: Text(artists[index]),
                                          onTap: () async {
                                            Navigator.pop(context);
                                            await Future.delayed(
                                              Duration(milliseconds: 300),
                                            );
                                            layersManager.pushLayer(
                                              'artists',
                                              content: artists[index],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              await Future.delayed(Duration(milliseconds: 250));
                              layersManager.pushLayer(
                                'artists',
                                content: artists[0],
                              );
                            }
                          },
                        ),

                        ListTile(
                          leading: Icon(Icons.album_rounded),
                          title: Text(
                            l10n.go2Album,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await Future.delayed(Duration(milliseconds: 250));
                            layersManager.pushLayer(
                              'albums',
                              content: getAlbum(song),
                            );
                          },
                        ),

                        ListTile(
                          leading: Icon(Icons.info_outline_rounded),
                          title: Text(
                            l10n.songInfo,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            showSongInfoDialog(context, song);
                          },
                        ),

                        if (!song.isNavidrome)
                          ListTile(
                            leading: Icon(Icons.edit_rounded),
                            title: Text(
                              l10n.editMetadata,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -4,
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              showEditMetadataDialog(context, song);
                            },
                          ),
                        if (playlist != null)
                          ListTile(
                            leading: Icon(Icons.delete_rounded),
                            title: Text(
                              l10n.delete,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -4,
                            ),
                            onTap: () async {
                              if (await showConfirmDialog(
                                context,
                                l10n.delete,
                              )) {
                                playlist!.remove([song]);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
