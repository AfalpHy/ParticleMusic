import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/playlists.dart';
import 'audio_handler.dart';
import 'art_widget.dart';

class SongListTile extends StatelessWidget {
  final int index;
  final List<AudioMetadata> source;
  final Playlist? playlist;

  const SongListTile({
    super.key,
    required this.index,
    required this.source,
    this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    final song = source[index];
    final isFavorite = songIsFavorite[song]!;
    return ListTile(
      contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
      leading: ArtWidget(
        size: 40,
        borderRadius: 4,
        source: song.pictures.isEmpty ? null : song.pictures.first,
      ),
      title: ValueListenableBuilder(
        valueListenable: currentSongNotifier,
        builder: (_, currentSong, _) {
          return Text(
            getTitle(song),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: song == currentSong
                  ? Color.fromARGB(255, 75, 200, 200)
                  : null,
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
            ),
          ),
        ],
      ),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      onTap: () async {
        audioHandler.setIndex(index);
        playQueue = List.from(source);
        if (playModeNotifier.value == 1 ||
            (playModeNotifier.value == 2 && audioHandler.tmpPlayMode == 1)) {
          audioHandler.shuffle();
        }
        await audioHandler.load();
        await audioHandler.play();
      },
      trailing: IconButton(
        icon: Icon(Icons.more_vert, size: 15),
        onPressed: () {
          HapticFeedback.heavyImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            builder: (context) {
              return mySheet(
                Column(
                  children: [
                    ListTile(
                      leading: ArtWidget(
                        size: 50,
                        borderRadius: 5,
                        source: song.pictures.isEmpty
                            ? null
                            : song.pictures.first,
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
                              AssetImage("assets/images/playlist_add.png"),
                              color: Colors.black,
                            ),
                            title: Text(
                              'Add to Playlists',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -4,
                            ),
                            onTap: () {
                              Navigator.pop(context);

                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) {
                                  return PlaylistsSheet(songs: [song]);
                                },
                              );
                            },
                          ),
                          ListTile(
                            leading: const ImageIcon(
                              AssetImage("assets/images/play_circle.png"),
                              color: Colors.black,
                            ),
                            title: Text(
                              'Play Now',
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
                              AssetImage("assets/images/playnext_circle.png"),
                              color: Colors.black,
                            ),
                            title: Text(
                              'Play Next',
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
                                    AssetImage("assets/images/delete.png"),
                                    color: Colors.black,
                                  ),
                                  title: Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  visualDensity: const VisualDensity(
                                    horizontal: 0,
                                    vertical: -4,
                                  ),
                                  onTap: () async {
                                    if (await showConfirmDialog(
                                      context,
                                      'Delete Action',
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
      ),
    );
  }
}

class SelectableSongListTile extends StatelessWidget {
  final int index;
  final List<AudioMetadata> source;
  final ValueNotifier<bool> isSelected;
  final ValueNotifier<int> selectedNum;
  final bool reorderable;
  const SelectableSongListTile({
    super.key,
    required this.index,
    required this.source,
    required this.isSelected,
    required this.selectedNum,
    this.reorderable = false,
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
              activeColor: Color.fromARGB(255, 75, 200, 200),
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
              leading: ArtWidget(
                size: 40,
                borderRadius: 4,
                source: song.pictures.isEmpty ? null : song.pictures.first,
              ),
              title: ValueListenableBuilder(
                valueListenable: currentSongNotifier,
                builder: (_, currentSong, _) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong
                          ? Color.fromARGB(255, 75, 200, 200)
                          : null,
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
                        const ImageIcon(
                          AssetImage("assets/images/reorder.png"),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SizedBox(),
      ],
    );
  }
}
