import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:particle_music/setting.dart';
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text("Albums"),
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
                  hintText: 'Search Albums',
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
                  fillColor: Colors.grey.shade100,
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
    return mySheet(
      Column(
        children: [
          ListTile(title: Text('Settings')),
          Divider(thickness: 0.5, height: 1, color: Colors.grey.shade300),

          ListTile(
            leading: const ImageIcon(pictureImage, color: Colors.black),
            title: Text(
              'Picture Size',
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
                      Text(useLargePicture ? 'Large' : 'Small'),
                      SizedBox(width: 10),
                      FlutterSwitch(
                        width: 45,
                        height: 20,
                        toggleSize: 15,
                        activeColor: mainColor,
                        inactiveColor: Colors.grey.shade300,
                        value: useLargePicture,
                        onToggle: (value) async {
                          tryVibrate();
                          albumsUseLargePictureNotifier.value = value;
                          setting.writeSetting();
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
              'Sequence',
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
                      Text(value ? 'Ascend' : 'Descend'),
                      SizedBox(width: 10),
                      FlutterSwitch(
                        width: 45,
                        height: 20,
                        toggleSize: 15,
                        activeColor: mainColor,
                        inactiveColor: Colors.grey.shade300,
                        value: value,
                        onToggle: (value) async {
                          tryVibrate();
                          albumsIsAscendingNotifier.value = value;
                          setting.writeSetting();
                          setting.sortAlbums();
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
                      source: getCoverArt(songList.first),
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
                        '${songList.length} songs',
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
