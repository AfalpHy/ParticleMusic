import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panel_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlaylistsPanel extends StatefulWidget {
  const PlaylistsPanel({super.key});

  @override
  State<StatefulWidget> createState() => PlaylistsPanelState();
}

class PlaylistsPanelState extends State<PlaylistsPanel> {
  final playlistsNotifier = ValueNotifier(playlistsManager.playlists);
  final textController = TextEditingController();
  late Widget searchField;

  final useBigPictureNotifier = ValueNotifier(true);

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
    searchField = titleSearchField(
      'Search Playlists',
      textController: textController,
      onChanged: (_) {
        filterPlaylists();
      },
    );
    titleSearchFieldStack.add(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
  }

  @override
  void dispose() {
    playlistsManager.changeNotifier.removeListener(filterPlaylists);
    titleSearchFieldStack.remove(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = (MediaQuery.widthOf(context) - 300);

    return ValueListenableBuilder(
      valueListenable: useBigPictureNotifier,
      builder: (context, value, child) {
        int crossAxisCount;
        double coverArtWidth;
        if (value) {
          crossAxisCount = (panelWidth / 240).toInt();
          coverArtWidth = panelWidth / crossAxisCount - 40;
        } else {
          crossAxisCount = (panelWidth / 120).toInt();
          coverArtWidth = panelWidth / crossAxisCount - 30;
        }

        return Material(
          color: Color.fromARGB(255, 235, 240, 245),

          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: ListTile(
                          leading: const ImageIcon(
                            playlistsImage,
                            size: 50,
                            color: mainColor,
                          ),
                          title: Text(
                            'Playlists',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: ValueListenableBuilder(
                            valueListenable: playlistsNotifier,
                            builder: (context, playlists, child) {
                              return Text(
                                '${playlists.length} in total',
                                style: TextStyle(fontSize: 12),
                              );
                            },
                          ),
                          trailing: SizedBox(
                            width: 120,
                            child: Column(
                              children: [
                                SizedBox(height: 20),
                                Row(
                                  children: [
                                    Spacer(),
                                    Text(value ? 'Large' : 'Small'),
                                    SizedBox(width: 10),
                                    FlutterSwitch(
                                      width: 45,
                                      height: 20,
                                      toggleSize: 15,
                                      activeColor: mainColor,
                                      inactiveColor: Colors.grey.shade300,
                                      value: value,
                                      onToggle: (value) async {
                                        useBigPictureNotifier.value = value;
                                      },
                                    ),
                                    Spacer(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),

                        child: Divider(
                          thickness: 1,
                          height: 1,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 15)),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),

                      sliver: ValueListenableBuilder(
                        valueListenable: playlistsNotifier,
                        builder: (context, playlists, child) {
                          return SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 1.05,
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                            panelManager.pushPanel(
                                              playlistsManager.playlists
                                                      .indexOf(playlist) +
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
              ),
            ],
          ),
        );
      },
    );
  }
}
