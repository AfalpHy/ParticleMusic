import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/history.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/playlists.dart';
import '../audio_handler.dart';
import '../cover_art_widget.dart';

class SongListTile extends StatelessWidget {
  final int index;
  final List<AudioMetadata> source;
  final Playlist? playlist;
  final bool isRanking;
  const SongListTile({
    super.key,
    required this.index,
    required this.source,
    this.playlist,
    this.isRanking = false,
  });

  @override
  Widget build(BuildContext context) {
    final song = source[index];
    final isFavorite = songIsFavorite[song]!;

    return ListTile(
      contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
      leading: CoverArtWidget(size: 40, borderRadius: 4, song: song),
      title: ValueListenableBuilder(
        valueListenable: currentSongNotifier,
        builder: (_, currentSong, _) {
          return Text(
            getTitle(song),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: song == currentSong ? textColor : null,
              fontWeight: song == currentSong ? FontWeight.bold : null,
            ),
          );
        },
      ),

      subtitle: Row(
        children: [
          ValueListenableBuilder(
            valueListenable: isFavorite,
            builder: (_, value, _) {
              return value
                  ? SizedBox(
                      width: 20,
                      child: Icon(Icons.favorite, color: Colors.red, size: 15),
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
        await audioHandler.setPlayQueue(source);
        await audioHandler.load();
        audioHandler.play();
      },
      trailing: isRanking
          ? SizedBox(
              width: 80,
              child: Row(
                children: [
                  Spacer(),
                  Icon(Icons.play_arrow_outlined, size: 15),
                  Text(historyManager.rankingItemList[index].times.toString()),
                  moreButton(context),
                ],
              ),
            )
          : moreButton(context),
    );
  }

  Widget moreButton(BuildContext context) {
    final song = source[index];
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
            return mySheet(
              Column(
                children: [
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

                  Divider(
                    color: Colors.grey.shade300,
                    thickness: 0.5,
                    height: 1,
                  ),

                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      children: [
                        ListTile(
                          leading: const ImageIcon(
                            playlistAddImage,
                            color: Colors.black,
                          ),
                          title: Text(
                            l10n.add2Playlists,
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
                          leading: const ImageIcon(
                            playCircleImage,
                            color: Colors.black,
                          ),
                          title: Text(
                            l10n.playNow,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () {
                            audioHandler.singlePlay(index, source);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: const ImageIcon(
                            playnextCircleImage,
                            color: Colors.black,
                          ),
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
                              audioHandler.singlePlay(index, source);
                            } else {
                              audioHandler.insert2Next(index, source);
                            }
                            Navigator.pop(context);
                          },
                        ),
                        playlist != null
                            ? ListTile(
                                leading: const ImageIcon(
                                  deleteImage,
                                  color: Colors.black,
                                ),
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
                              )
                            : SizedBox(),
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

class SelectableSongListTile extends StatelessWidget {
  final int index;
  final List<AudioMetadata> source;
  final ValueNotifier<bool> isSelected;
  final ValueNotifier<int> selectedNum;
  final bool reorderable;
  final bool isRanking;

  const SelectableSongListTile({
    super.key,
    required this.index,
    required this.source,
    required this.isSelected,
    required this.selectedNum,
    this.reorderable = false,
    this.isRanking = false,
  });

  @override
  Widget build(BuildContext context) {
    final song = source[index];
    final isFavorite = songIsFavorite[song]!;
    return Row(
      children: [
        ValueListenableBuilder(
          valueListenable: isSelected,
          builder: (context, value, child) {
            return Checkbox(
              value: value,
              activeColor: iconColor,
              onChanged: (value) {
                isSelected.value = value!;
                selectedNum.value += value ? 1 : -1;
              },
              shape: const CircleBorder(),
              side: BorderSide(color: Colors.grey),
            );
          },
        ),
        Expanded(
          child: GestureDetector(
            child: ListTile(
              contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              leading: CoverArtWidget(size: 40, borderRadius: 4, song: song),
              title: ValueListenableBuilder(
                valueListenable: currentSongNotifier,
                builder: (_, currentSong, _) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong ? textColor : null,
                      fontWeight: song == currentSong ? FontWeight.bold : null,
                    ),
                  );
                },
              ),

              subtitle: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: isFavorite,
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
            ),
            onTap: () {
              isSelected.value = !isSelected.value;
              selectedNum.value += isSelected.value ? 1 : -1;
            },
          ),
        ),

        if (isRanking)
          SizedBox(
            width: 60,
            child: Row(
              children: [
                Spacer(),
                Icon(Icons.play_arrow_outlined, size: 15),
                Text(historyManager.rankingItemList[index].times.toString()),
              ],
            ),
          ),

        reorderable
            ? SizedBox(
                width: 60,
                height: 50,
                child: ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    // must set color to make area valid
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        const ImageIcon(reorderImage),
                      ],
                    ),
                  ),
                ),
              )
            : SizedBox(width: 20),
      ],
    );
  }
}
