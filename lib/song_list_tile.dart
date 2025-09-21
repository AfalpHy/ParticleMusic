import 'dart:convert';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/playlists.dart';
import 'audio_handler.dart';
import 'art_widget.dart';
import 'package:path/path.dart' as p;

class SongListTile extends StatelessWidget {
  final int index;
  final List<AudioMetadata> source;

  const SongListTile({super.key, required this.index, required this.source});

  @override
  Widget build(BuildContext context) {
    final song = source[index];
    final songBasename = p.basename(song.file.path);
    final isFavorite = songIsFavorite[songBasename]!;
    final isCurrentSong = song.file.path == audioHandler.currentSong?.file.path;
    return ListTile(
      contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
      leading: ArtWidget(
        size: 40,
        borderRadius: 2,
        source: song.pictures.isEmpty ? null : song.pictures.first,
      ),
      title: Text(
        song.title ?? "Unknown Title",
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrentSong ? Color.fromARGB(255, 75, 200, 200) : null,
          fontWeight: isCurrentSong ? FontWeight.bold : null,
        ),
      ),
      subtitle: Row(
        children: [
          FavoriteLabel(isFavorite: isFavorite),
          Expanded(
            child: Text(
              "${song.artist ?? "Unknown Artist"} - ${song.album ?? "Unknown Album"}",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrentSong ? Color.fromARGB(255, 75, 200, 200) : null,
              ),
            ),
          ),
        ],
      ),
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      onTap: () async {
        audioHandler.setIndex(index);
        playQueue = List.from(source);
        if (audioHandler.playMode == 2) {
          audioHandler.shuffle();
        }
        await audioHandler.load();
        audioHandler.play();
      },
      trailing: IconButton(
        icon: Icon(Icons.more_vert, size: 15),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // allows full-height
            useRootNavigator: true,
            builder: (context) {
              return ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                child: Container(
                  height: 500,
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      ListTile(
                        leading: ArtWidget(
                          size: 50,
                          source: song.pictures.isEmpty
                              ? null
                              : song.pictures.first,
                        ),
                        title: Text(
                          song.title ?? "Unknown Title",
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${song.artist ?? "Unknown Artist"} - ${song.album ?? "Unknown Album"}",
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
                              leading: Icon(
                                isFavorite.value
                                    ? Icons.playlist_remove_outlined
                                    : Icons.playlist_add_outlined,
                                size: 25,
                              ),
                              title: Text(
                                isFavorite.value
                                    ? 'Remove from Favorite'
                                    : 'Add to Favorite',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -4,
                              ),
                              onTap: () {
                                if (isFavorite.value) {
                                  favoriteBasenames.remove(songBasename);
                                  favorite.remove(song);
                                } else {
                                  favoriteBasenames.insert(0, songBasename);
                                  favorite.insert(0, song);
                                }
                                favoriteFile.writeAsStringSync(
                                  jsonEncode(favoriteBasenames),
                                );
                                isFavorite.value = !isFavorite.value;
                                notifier.value++;
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.playlist_add_outlined,
                                size: 25,
                              ),
                              title: Text(
                                'Add to Playlists',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              visualDensity: const VisualDensity(
                                horizontal: 0,
                                vertical: -4,
                              ),
                              onTap: () {
                                Navigator.pop(context);

                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled:
                                      true, // allows full-height
                                  builder: (_) {
                                    return PlaylistsSheet();
                                  },
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.play_circle_outline,
                                size: 25,
                              ),
                              title: Text(
                                'Play',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
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
                              leading: Icon(
                                Icons.playlist_add_circle_outlined,
                                size: 25,
                              ),
                              title: Text(
                                'Play Next',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FavoriteLabel extends StatefulWidget {
  final ValueNotifier<bool> isFavorite;
  const FavoriteLabel({super.key, required this.isFavorite});

  @override
  State<StatefulWidget> createState() => FavoriteLabelState();
}

class FavoriteLabelState extends State<FavoriteLabel> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.isFavorite,
      builder: (_, value, _) {
        return value
            ? SizedBox(
                width: 20,
                child: Icon(Icons.favorite, color: Colors.red, size: 15),
              )
            : SizedBox();
      },
    );
  }
}
