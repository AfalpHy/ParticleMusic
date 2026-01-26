import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/mobile/widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/utils.dart';
import 'package:searchfield/searchfield.dart';
import 'package:smooth_corner/smooth_corner.dart';

class AlbumsPage extends StatelessWidget {
  final ValueNotifier<List<MapEntry<String, List<AudioMetadata>>>>
  currentMapEntryListNotifier = ValueNotifier(albumMapEntryList);

  final textController = TextEditingController();

  AlbumsPage({super.key});

  void updateCurrentMapEntryList() {
    final value = textController.text;
    currentMapEntryListNotifier.value = albumMapEntryList
        .where((e) => (e.key.toLowerCase().contains(value.toLowerCase())))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: commonColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: commonColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.albums),
        centerTitle: true,
        actions: [searchField(), moreButton(context)],
      ),
      body: ValueListenableBuilder(
        valueListenable: currentMapEntryListNotifier,
        builder: (context, mapEntryList, child) {
          return gridView(mapEntryList);
        },
      ),
    );
  }

  Widget searchField() {
    final ValueNotifier<bool> isSearchingNotifier = ValueNotifier(false);
    return ValueListenableBuilder(
      valueListenable: isSearchingNotifier,
      builder: (context, isSearching, child) {
        if (!isSearching) {
          return IconButton(
            onPressed: () {
              isSearchingNotifier.value = true;
            },
            icon: Icon(Icons.search),
          );
        }
        return Expanded(
          child: SizedBox(
            height: 30,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(50, 0, 0, 0),
              child: SearchField(
                autofocus: true,
                controller: textController,
                suggestions: [],
                searchInputDecoration: SearchInputDecoration(
                  hintText: AppLocalizations.of(context).searchAlbums,
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      isSearchingNotifier.value = false;
                      textController.clear();
                      updateCurrentMapEntryList();
                      FocusScope.of(context).unfocus();
                    },
                    icon: Icon(Icons.clear),
                    padding: EdgeInsets.zero,
                  ),
                  filled: true,
                  fillColor: searchFieldColor,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSearchTextChanged: (_) {
                  updateCurrentMapEntryList();

                  return null;
                },
              ),
            ),
          ),
        );
      },
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
            leading: const ImageIcon(pictureImage, color: Colors.black),
            title: Text(
              l10n.pictureSize,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: ValueListenableBuilder(
              valueListenable: albumsUseLargePictureNotifier,
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
                          albumsUseLargePictureNotifier.value = value;
                          settingManager.saveSetting();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          ListTile(
            leading: const ImageIcon(sequenceImage, color: Colors.black),
            title: Text(
              l10n.order,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: ValueListenableBuilder(
              valueListenable: albumsIsAscendingNotifier,
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
                          albumsIsAscendingNotifier.value = value;
                          settingManager.saveSetting();
                          sortAlbums();
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

  Widget gridView(List<MapEntry<String, List<AudioMetadata>>> mapEntryList) {
    return ValueListenableBuilder(
      valueListenable: albumsUseLargePictureNotifier,
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
            final album = mapEntryList[index].key;
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
                          builder: (_) => SongListPage(album: album),
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
                        album,
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
