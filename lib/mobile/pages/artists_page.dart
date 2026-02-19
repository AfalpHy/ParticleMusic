import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/mobile/widgets/my_search_field.dart';
import 'package:particle_music/mobile/widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ArtistsPage extends StatelessWidget {
  final ValueNotifier<List<MapEntry<String, List<MyAudioMetadata>>>>
  currentMapEntryListNotifier = ValueNotifier(artistMapEntryList);

  final textController = TextEditingController();

  ArtistsPage({super.key});

  void updateCurrentMapEntryList() {
    final value = textController.text;
    currentMapEntryListNotifier.value = artistMapEntryList
        .where((e) => (e.key.toLowerCase().contains(value.toLowerCase())))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        iconTheme: IconThemeData(color: iconColor),
        backgroundColor: pageBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.artists),
        centerTitle: true,
        actions: [searchField(), moreButton(context)],
      ),
      body: ValueListenableBuilder(
        valueListenable: artistsIsListViewNotifier,
        builder: (context, isListView, child) {
          return ValueListenableBuilder(
            valueListenable: currentMapEntryListNotifier,
            builder: (context, mapEntryList, child) {
              return isListView
                  ? listView(mapEntryList)
                  : gridView(mapEntryList);
            },
          );
        },
      ),
    );
  }

  Widget searchField() {
    return MySearchField(
      textController: textController,
      onSearchTextChanged: updateCurrentMapEntryList,
    );
  }

  Widget moreButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.more_vert),
      onPressed: () {
        tryVibrate();

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (context) {
            return moreSheet(context);
          },
        );
      },
    );
  }

  Widget moreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
      Column(
        children: [
          ListTile(title: Text(l10n.settings)),
          Divider(thickness: 0.5, height: 1, color: dividerColor),
          ListTile(
            leading: ValueListenableBuilder(
              valueListenable: artistsIsListViewNotifier,
              builder: (context, value, child) {
                return ImageIcon(
                  value ? listImage : gridImage,
                  color: iconColor,
                );
              },
            ),
            title: Text(
              l10n.view,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              artistsIsListViewNotifier.value = true;
            },
            trailing: ValueListenableBuilder(
              valueListenable: artistsIsListViewNotifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Spacer(),
                      Text(value ? l10n.list : l10n.grid),
                      SizedBox(width: 10),
                      MySwitch(
                        value: value,
                        onToggle: (value) async {
                          tryVibrate();
                          artistsIsListViewNotifier.value = value;
                          settingManager.saveSetting();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          ValueListenableBuilder(
            valueListenable: artistsIsListViewNotifier,
            builder: (context, value, child) {
              if (value) {
                return SizedBox.shrink();
              }
              return ListTile(
                leading: ImageIcon(pictureImage, color: iconColor),
                title: Text(
                  l10n.pictureSize,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: ValueListenableBuilder(
                  valueListenable: artistsUseLargePictureNotifier,
                  builder: (context, useLargePicture, child) {
                    return SizedBox(
                      width: 100,

                      child: Row(
                        children: [
                          Spacer(),
                          Text(useLargePicture ? l10n.large : l10n.small),
                          SizedBox(width: 10),
                          MySwitch(
                            value: useLargePicture,
                            onToggle: (value) async {
                              tryVibrate();
                              artistsUseLargePictureNotifier.value = value;
                              settingManager.saveSetting();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),

          ListTile(
            leading: ImageIcon(sequenceImage, color: iconColor),
            title: Text(
              l10n.order,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: ValueListenableBuilder(
              valueListenable: artistsIsAscendingNotifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 120,

                  child: Row(
                    children: [
                      Spacer(),
                      Text(value ? l10n.ascending : l10n.descending),
                      SizedBox(width: 10),
                      MySwitch(
                        value: value,
                        onToggle: (value) async {
                          tryVibrate();
                          artistsIsAscendingNotifier.value = value;
                          settingManager.saveSetting();
                          sortArtists();

                          updateCurrentMapEntryList();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget listView(List<MapEntry<String, List<MyAudioMetadata>>> mapEntryList) {
    return ListView.builder(
      itemExtent: 64,
      itemCount: mapEntryList.length,
      itemBuilder: (context, index) {
        final artist = mapEntryList[index].key;
        final songList = mapEntryList[index].value;
        return Center(
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20),

            leading: CoverArtWidget(
              size: 50,
              borderRadius: 25,
              song: songList.first,
            ),
            title: Text(artist),
            trailing: Text(
              AppLocalizations.of(context).songsCount(songList.length),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SongListPage(artist: artist)),
              );
            },
          ),
        );
      },
    );
  }

  Widget gridView(List<MapEntry<String, List<MyAudioMetadata>>> mapEntryList) {
    return ValueListenableBuilder(
      valueListenable: artistsUseLargePictureNotifier,
      builder: (context, useLargePicture, child) {
        double size = useLargePicture ? appWidth * 0.40 : appWidth * 0.25;
        double radius = useLargePicture ? appWidth * 0.025 : appWidth * 0.015;
        double childAspectRatio = useLargePicture ? 0.85 : 0.8;
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: useLargePicture ? 2 : 3,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: mapEntryList.length,
          itemBuilder: (context, index) {
            final artist = mapEntryList[index].key;
            final songList = mapEntryList[index].value;
            return Column(
              children: [
                Material(
                  elevation: 1,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: CoverArtWidget(
                      size: size,
                      borderRadius: radius,
                      song: songList.first,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SongListPage(artist: artist),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 5),
                SizedBox(
                  width: size - 20,
                  child: Column(
                    children: [
                      Text(
                        artist,
                        style: TextStyle(overflow: TextOverflow.ellipsis),
                      ),

                      Text(
                        AppLocalizations.of(
                          context,
                        ).songsCount(songList.length),
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
