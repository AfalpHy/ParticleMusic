import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/utils.dart';

class ArtistAlbumPanel extends StatefulWidget {
  final bool isArtist;

  const ArtistAlbumPanel({super.key, required this.isArtist});

  @override
  State<StatefulWidget> createState() => ArtistAlbumPanelState();
}

class ArtistAlbumPanelState extends State<ArtistAlbumPanel> {
  late bool isArtist;

  late final ValueNotifier<List<MapEntry<String, List<AudioMetadata>>>>
  currentMapEntryListNotifier;

  final textController = TextEditingController();

  late ValueNotifier<bool> isAscendingNotifier;
  late ValueNotifier<bool> useLargePictureNotifier;

  void updateCurrentMapEntryList() {
    final value = textController.text;
    currentMapEntryListNotifier.value =
        (isArtist ? artistMapEntryList : albumMapEntryList)
            .where((e) => (e.key.toLowerCase().contains(value.toLowerCase())))
            .toList();
  }

  @override
  void initState() {
    super.initState();
    isArtist = widget.isArtist;
    currentMapEntryListNotifier = ValueNotifier(
      isArtist ? artistMapEntryList : albumMapEntryList,
    );
    isAscendingNotifier = isArtist
        ? artistsIsAscendingNotifier
        : albumsIsAscendingNotifier;

    useLargePictureNotifier = isArtist
        ? artistsUseLargePictureNotifier
        : albumsUseLargePictureNotifier;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: titleSearchField(
            isArtist ? l10n.searchArtists : l10n.searchAlbums,
            textController: textController,
            onChanged: (value) {
              updateCurrentMapEntryList();
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

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: ListTile(
                    leading: isArtist
                        ? ImageIcon(artistImage, size: 50, color: iconColor)
                        : ImageIcon(albumImage, size: 50, color: iconColor),
                    title: Text(
                      isArtist ? l10n.artists : l10n.albums,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: ValueListenableBuilder(
                      valueListenable: currentMapEntryListNotifier,
                      builder: (context, mapEntryList, child) {
                        return Text(
                          isArtist
                              ? l10n.artistsCount(mapEntryList.length)
                              : l10n.albumsCount(mapEntryList.length),
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
                                        sortArtists();
                                      } else {
                                        sortAlbums();
                                      }
                                      updateCurrentMapEntryList();
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),

                  child: ValueListenableBuilder(
                    valueListenable: colorChangeNotifier,
                    builder: (context, value, child) {
                      return ValueListenableBuilder(
                        valueListenable: updateBackgroundNotifier,
                        builder: (context, value, child) {
                          return Divider(
                            thickness: 1,
                            height: 1,
                            color: enableCustomColorNotifier.value
                                ? dividerColor
                                : backgroundColor,
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
                  valueListenable: useLargePictureNotifier,
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
                    return ValueListenableBuilder(
                      valueListenable: currentMapEntryListNotifier,
                      builder: (context, mapEntryList, child) {
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 1.05,
                              ),
                          itemCount: mapEntryList.length,
                          itemBuilder: (context, index) {
                            final key = mapEntryList[index].key;
                            final songList = mapEntryList[index].value;
                            return Column(
                              children: [
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    child: ValueListenableBuilder(
                                      valueListenable:
                                          songIsUpdated[songList.first]!,
                                      builder: (_, _, _) {
                                        return CoverArtWidget(
                                          size: coverArtWidth,
                                          borderRadius: 10,
                                          song: songList.first,
                                        );
                                      },
                                    ),
                                    onTap: () {
                                      panelManager.pushPanel(
                                        isArtist ? 'artists' : 'albums',
                                        content: key,
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: coverArtWidth - 20,
                                  child: Center(
                                    child: Text(
                                      key,
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
  }
}
