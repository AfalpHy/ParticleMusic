import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/layer/layers_manager.dart';

class PlaylistsPanel extends StatefulWidget {
  const PlaylistsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _PlaylistsPanelState();
}

class _PlaylistsPanelState extends State<PlaylistsPanel> {
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
    playlistsManager.updateNotifier.addListener(filterPlaylists);
    textController.addListener(filterPlaylists);
  }

  @override
  void dispose() {
    playlistsManager.updateNotifier.removeListener(filterPlaylists);
    textController.removeListener(filterPlaylists);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: TitleSearchField(
            key: ValueKey(l10n.searchPlaylists),
            hintText: l10n.searchPlaylists,
            textController: textController,
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
          coverArtWidth = panelWidth / crossAxisCount - 45;
        } else {
          crossAxisCount = (panelWidth / 120).toInt();
          coverArtWidth = panelWidth / crossAxisCount - 35;
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
                        leading: ValueListenableBuilder(
                          valueListenable: updateColorNotifier,
                          builder: (_, _, _) {
                            return ImageIcon(
                              playlistsImage,
                              size: 50,
                              color: iconColor,
                            );
                          },
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
                    child: ValueListenableBuilder(
                      valueListenable: updateColorNotifier,
                      builder: (context, value, child) {
                        return Divider(
                          thickness: 0.5,
                          height: 0.5,
                          indent: 30,
                          endIndent: 30,
                          color: dividerColor,
                        );
                      },
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
                              valueListenable: playlist.updateNotifier,
                              builder: (context, value, child) {
                                final displaySong = playlist.getDisplaySong();
                                return Column(
                                  children: [
                                    InkWell(
                                      mouseCursor: SystemMouseCursors.click,
                                      child: displaySong == null
                                          ? CoverArtWidget(
                                              size: coverArtWidth,
                                              borderRadius: 10,
                                              song: null,
                                            )
                                          : ValueListenableBuilder(
                                              valueListenable:
                                                  displaySong.updateNotifier,
                                              builder: (_, _, _) {
                                                return CoverArtWidget(
                                                  size: coverArtWidth,
                                                  borderRadius: 10,
                                                  song: displaySong,
                                                );
                                              },
                                            ),
                                      onTap: () {
                                        layersManager.pushLayer(
                                          '_${playlist.name}',
                                        );
                                      },
                                    ),
                                    SizedBox(
                                      width: coverArtWidth - 5,
                                      child: Center(
                                        child: Text(
                                          playlist ==
                                                  playlistsManager.playlists[0]
                                              ? l10n.favorites
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
