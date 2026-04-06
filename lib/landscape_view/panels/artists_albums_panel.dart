import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/layer/layers_manager.dart';

class ArtistsAlbumsPanel extends StatefulWidget {
  final bool isArtist;

  const ArtistsAlbumsPanel({super.key, required this.isArtist});

  @override
  State<StatefulWidget> createState() => _ArtistsAlbumsPanelState();
}

class _ArtistsAlbumsPanelState extends State<ArtistsAlbumsPanel> {
  late bool isArtist;

  late final ValueNotifier<List<ArtistAlbumBase>>
  currentArtistAlbumListNotifier;

  final textController = TextEditingController();

  late ValueNotifier<bool> isAscendingNotifier;
  late ValueNotifier<bool> useLargePictureNotifier;

  void updateCurrentList() {
    final value = textController.text;
    currentArtistAlbumListNotifier.value = artistsAlbumsManager
        .getArtistAlbumList(isArtist)
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    isArtist = widget.isArtist;
    currentArtistAlbumListNotifier = ValueNotifier(
      artistsAlbumsManager.getArtistAlbumList(isArtist),
    );
    isAscendingNotifier = artistsAlbumsManager.getIsAscendingNotifier(isArtist);

    useLargePictureNotifier = artistsAlbumsManager.getUseLargePictureNotifier(
      isArtist,
    );

    textController.addListener(updateCurrentList);
    artistsAlbumsManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    textController.dispose();
    artistsAlbumsManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: TitleSearchField(
            key: ValueKey(isArtist ? l10n.searchArtists : l10n.searchAlbums),
            hintText: isArtist ? l10n.searchArtists : l10n.searchAlbums,
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

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: ListTile(
              leading: ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (_, _, _) {
                  return isArtist
                      ? ImageIcon(artistImage, size: 50, color: iconColor)
                      : ImageIcon(albumImage, size: 50, color: iconColor);
                },
              ),
              title: Text(
                isArtist ? l10n.artists : l10n.albums,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: ValueListenableBuilder(
                valueListenable: currentArtistAlbumListNotifier,
                builder: (context, list, child) {
                  return Text(
                    isArtist
                        ? l10n.artistCount(list.length)
                        : l10n.albumCount(list.length),
                    style: TextStyle(fontSize: 12),
                  );
                },
              ),
              trailing: SizedBox(
                width: 240,
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Spacer(),
                        ValueListenableBuilder(
                          valueListenable: isAscendingNotifier,
                          builder: (context, value, child) {
                            return Text(
                              value ? l10n.ascending : l10n.descending,
                            );
                          },
                        ),
                        SizedBox(width: 10),
                        ValueListenableBuilder(
                          valueListenable: isAscendingNotifier,
                          builder: (context, value, child) {
                            return MySwitch(
                              value: value,
                              onToggle: (value) async {
                                isAscendingNotifier.value = value;
                                settingManager.saveSetting();
                                if (isArtist) {
                                  artistsAlbumsManager.sortArtists();
                                } else {
                                  artistsAlbumsManager.sortAlbums();
                                }
                                updateCurrentList();
                              },
                            );
                          },
                        ),
                        SizedBox(width: 10),

                        ValueListenableBuilder(
                          valueListenable: useLargePictureNotifier,
                          builder: (context, value, child) {
                            return Text(value ? l10n.large : l10n.small);
                          },
                        ),
                        SizedBox(width: 10),
                        ValueListenableBuilder(
                          valueListenable: useLargePictureNotifier,
                          builder: (context, value, child) {
                            return MySwitch(
                              value: value,
                              onToggle: (value) async {
                                useLargePictureNotifier.value = value;
                                settingManager.saveSetting();
                              },
                            );
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
            valueListenable: useLargePictureNotifier,
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
              return ValueListenableBuilder(
                valueListenable: currentArtistAlbumListNotifier,
                builder: (context, list, child) {
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              child: ValueListenableBuilder(
                                valueListenable:
                                    list[index].displayNavidromeNotifier,
                                builder: (context, value, child) {
                                  final displaySong = list[index]
                                      .getDisplaySong();
                                  return ValueListenableBuilder(
                                    valueListenable: displaySong.updateNotifier,
                                    builder: (_, _, _) {
                                      return CoverArtWidget(
                                        size: coverArtWidth,
                                        borderRadius: 10,
                                        song: displaySong,
                                      );
                                    },
                                  );
                                },
                              ),
                              onTap: () {
                                layersManager.pushLayer(
                                  isArtist ? 'artists' : 'albums',
                                  content: list[index].name,
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: coverArtWidth - 5,
                            child: Center(
                              child: Text(
                                list[index].name,
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
    );
  }
}
