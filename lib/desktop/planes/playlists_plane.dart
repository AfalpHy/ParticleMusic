import 'package:flutter/material.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlaylistsPlane extends StatefulWidget {
  const PlaylistsPlane({super.key});

  @override
  State<StatefulWidget> createState() => PlaylistsPlaneState();
}

class PlaylistsPlaneState extends State<PlaylistsPlane> {
  final playlistsNotifier = ValueNotifier(playlistsManager.playlists);
  final textController = TextEditingController();

  void filterPlaylists() {
    playlistsNotifier.value = playlistsManager.playlists.where((playlist) {
      return playlist.name.toLowerCase().contains(
        textController.text.toLowerCase(),
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    playlistsManager.changeNotifier.addListener(filterPlaylists);
  }

  @override
  void dispose() {
    playlistsManager.changeNotifier.removeListener(filterPlaylists);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planeWidth = (MediaQuery.widthOf(context) - 220);
    final crossAxisCount = (planeWidth / 200).toInt();
    final coverArtWidth = planeWidth / crossAxisCount - 50;

    return Material(
      color: Color.fromARGB(255, 235, 240, 245),

      child: Column(
        children: [
          TitleBar(
            hintText: 'Search Playlists',
            textController: textController,
            onChanged: (_) {
              filterPlaylists();
            },
          ),

          Expanded(
            child: ValueListenableBuilder(
              valueListenable: playlistsNotifier,
              builder: (context, playlists, child) {
                return GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.08,
                  ),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ValueListenableBuilder(
                      valueListenable: playlist.changeNotifier,
                      builder: (context, value, child) {
                        return Column(
                          children: [
                            Material(
                              elevation: 1,
                              shape: SmoothRectangleBorder(
                                smoothness: 1,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                child: playlist.songs.isNotEmpty
                                    ? ValueListenableBuilder(
                                        valueListenable:
                                            songIsUpdated[playlist
                                                .songs
                                                .first]!,
                                        builder: (_, _, _) {
                                          return CoverArtWidget(
                                            size: coverArtWidth,
                                            borderRadius: 10,
                                            source: getCoverArt(
                                              playlist.songs.first,
                                            ),
                                          );
                                        },
                                      )
                                    : CoverArtWidget(
                                        size: coverArtWidth,
                                        borderRadius: 10,
                                        source: null,
                                      ),
                                onTap: () {
                                  planeManager.pushPlane(
                                    playlistsManager.playlists.indexOf(
                                          playlist,
                                        ) +
                                        5,
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: coverArtWidth - 20,
                              child: Center(
                                child: Text(
                                  playlist.name,
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
