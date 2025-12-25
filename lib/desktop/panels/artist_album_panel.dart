import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/setting.dart';

class ArtistAlbumPanel extends StatefulWidget {
  final bool isArtist;

  const ArtistAlbumPanel({super.key, required this.isArtist});

  @override
  State<StatefulWidget> createState() => ArtistAlbumPanelState();
}

class ArtistAlbumPanelState extends State<ArtistAlbumPanel> {
  late bool isArtist;
  late Widget searchField;

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

    searchField = titleSearchField(
      'Search ${isArtist ? 'Artists' : 'Albums'}',
      textController: textController,
      onChanged: (value) {
        updateCurrentMapEntryList();
      },
    );
    titleSearchFieldStack.add(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
  }

  @override
  void dispose() {
    titleSearchFieldStack.remove(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = (MediaQuery.widthOf(context) - 300);

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
                      leading: isArtist
                          ? const ImageIcon(
                              artistImage,
                              size: 50,
                              color: mainColor,
                            )
                          : const ImageIcon(
                              albumImage,
                              size: 50,
                              color: mainColor,
                            ),
                      title: Text(
                        isArtist ? 'Artists' : 'Albums',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: ValueListenableBuilder(
                        valueListenable: currentMapEntryListNotifier,
                        builder: (context, mapEntryList, child) {
                          return Text(
                            '${mapEntryList.length} in total',
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
                                    return Text(value ? 'Ascend' : 'Descend');
                                  },
                                ),
                                SizedBox(width: 10),
                                ValueListenableBuilder(
                                  valueListenable: isAscendingNotifier,
                                  builder: (context, value, child) {
                                    return FlutterSwitch(
                                      width: 45,
                                      height: 20,
                                      toggleSize: 15,
                                      activeColor: mainColor,
                                      inactiveColor: Colors.grey.shade300,
                                      value: value,
                                      onToggle: (value) async {
                                        isAscendingNotifier.value = value;
                                        setting.saveSetting();
                                        if (isArtist) {
                                          setting.sortArtists();
                                        } else {
                                          setting.sortAlbums();
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
                                    return Text(value ? 'Large' : 'Small');
                                  },
                                ),
                                SizedBox(width: 10),
                                ValueListenableBuilder(
                                  valueListenable: useLargePictureNotifier,
                                  builder: (context, value, child) {
                                    return FlutterSwitch(
                                      width: 45,
                                      height: 20,
                                      toggleSize: 15,
                                      activeColor: mainColor,
                                      inactiveColor: Colors.grey.shade300,
                                      value: value,
                                      onToggle: (value) async {
                                        useLargePictureNotifier.value = value;
                                        setting.saveSetting();
                                      },
                                    );
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
                                            source: getCoverArt(songList.first),
                                          );
                                        },
                                      ),
                                      onTap: () {
                                        panelManager.pushPanel(
                                          isArtist ? 3 : 4,
                                          title: key,
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
      ),
    );
  }
}
