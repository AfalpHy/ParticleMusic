import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/my_switch.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting.dart';
import 'package:smooth_corner/smooth_corner.dart';

class PlaylistsPanel extends StatefulWidget {
  const PlaylistsPanel({super.key});

  @override
  State<StatefulWidget> createState() => PlaylistsPanelState();
}

class PlaylistsPanelState extends State<PlaylistsPanel> {
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
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: titleSearchField(
            l10n.searchPlaylists,
            textController: textController,
            onChanged: (_) {
              filterPlaylists();
            },
          ),
        ),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    final panelWidth = (MediaQuery.widthOf(context) - 300);
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: playlistsUseLargePictureNotifier,
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

        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: ListTile(
                        leading: ImageIcon(
                          playlistsImage,
                          size: 50,
                          color: iconColor,
                        ),
                        title: Text(
                          l10n.playlists,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: ValueListenableBuilder(
                          valueListenable: playlistsNotifier,
                          builder: (context, playlists, child) {
                            return Text(
                              l10n.playlistsCount(playlists.length),
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
                                  Text(value ? l10n.large : l10n.small),
                                  SizedBox(width: 10),
                                  MySwitch(
                                    value: value,
                                    onToggle: (value) async {
                                      playlistsUseLargePictureNotifier.value =
                                          value;
                                    },
                                  ),
                                  SizedBox(width: 10),
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

                      child: ValueListenableBuilder(
                        valueListenable: colorChangeNotifier,
                        builder: (context, value, child) {
                          return ValueListenableBuilder(
                            valueListenable: currentSongNotifier,
                            builder: (context, value, child) {
                              return Divider(
                                thickness: 1,
                                height: 1,
                                color: enableCustomColorNotifier.value
                                    ? dividerColor
                                    : coverArtAverageColor,
                              );
                            },
                          );
                        },
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
                                          panelManager.pushPanel(
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
                                          playlist ==
                                                  playlistsManager.playlists[0]
                                              ? l10n.favorite
                                              : playlist.name,
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
        );
      },
    );
  }
}
