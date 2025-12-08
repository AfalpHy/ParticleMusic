import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';
import 'package:searchfield/searchfield.dart';
import 'package:smooth_corner/smooth_corner.dart';

final _isListViewNotifier = ValueNotifier(true);
final _isAscendingNotifier = ValueNotifier(true);
final _crossAxisCountNotifier = ValueNotifier(3);

class ArtistsPage extends StatelessWidget {
  final List<MapEntry<String, List<AudioMetadata>>> mapEntryList =
      artist2SongList.entries.toList();

  final ValueNotifier<List<MapEntry<String, List<AudioMetadata>>>>
  currentMapEntryListNotifier = ValueNotifier([]);

  final textController = TextEditingController();

  ArtistsPage({super.key}) {
    updateCurrentMapEntryList();
  }

  void updateCurrentMapEntryList() {
    final value = textController.text;
    currentMapEntryListNotifier.value =
        mapEntryList
            .where((e) => (e.key.toLowerCase().contains(value.toLowerCase())))
            .toList()
          ..sort((a, b) {
            if (_isAscendingNotifier.value) {
              return compareMixed(a.key, b.key);
            } else {
              return compareMixed(b.key, a.key);
            }
          });
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
        title: Text("Artists"),
        centerTitle: true,
        actions: [searchField(), moreButton(context)],
      ),
      body: ValueListenableBuilder(
        valueListenable: _isListViewNotifier,
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
                  hintText: 'Search Artists',
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
            leading: ValueListenableBuilder(
              valueListenable: _isListViewNotifier,
              builder: (context, value, child) {
                return value
                    ? const ImageIcon(listImage, color: Colors.black)
                    : const ImageIcon(gridImage, color: Colors.black);
              },
            ),
            title: Text('View', style: TextStyle(fontWeight: FontWeight.bold)),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              _isListViewNotifier.value = true;
            },
            trailing: ValueListenableBuilder(
              valueListenable: _isListViewNotifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Spacer(),
                      Text(value ? 'List' : 'Grid'),
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
                          _isListViewNotifier.value = value;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          ValueListenableBuilder(
            valueListenable: _isListViewNotifier,
            builder: (context, value, child) {
              if (value) {
                return SizedBox.shrink();
              }
              return ListTile(
                leading: const ImageIcon(pictureImage, color: Colors.black),
                title: Text(
                  'Picture Size',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: ValueListenableBuilder(
                  valueListenable: _crossAxisCountNotifier,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: 100,

                      child: Row(
                        children: [
                          Spacer(),
                          Text(value == 2 ? 'Big' : 'Small'),
                          SizedBox(width: 10),
                          FlutterSwitch(
                            width: 45,
                            height: 20,
                            toggleSize: 15,
                            activeColor: mainColor,
                            inactiveColor: Colors.grey.shade300,
                            value: value == 3,
                            onToggle: (value) async {
                              tryVibrate();
                              _crossAxisCountNotifier.value = value ? 3 : 2;
                              updateCurrentMapEntryList();
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
            leading: const ImageIcon(sequenceImage, color: Colors.black),
            title: Text(
              'Sequence',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: ValueListenableBuilder(
              valueListenable: _isAscendingNotifier,
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
                          _isAscendingNotifier.value = value;
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

  Widget listView(List<MapEntry<String, List<AudioMetadata>>> mapEntryList) {
    return ListView.builder(
      itemExtent: 64,
      itemCount: mapEntryList.length,
      itemBuilder: (context, index) {
        final artist = mapEntryList[index].key;
        final songList = mapEntryList[index].value;
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 20),

          leading: CoverArtWidget(
            size: 50,
            borderRadius: 25,
            source: getCoverArt(songList.first),
          ),
          title: Text(artist),
          trailing: Text('${songList.length} songs'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SongListPage(artist: artist)),
            );
          },
        );
      },
    );
  }

  Widget gridView(List<MapEntry<String, List<AudioMetadata>>> mapEntryList) {
    return ValueListenableBuilder(
      valueListenable: _crossAxisCountNotifier,
      builder: (context, crossAxisCount, child) {
        double size = crossAxisCount == 2 ? appWidth * 0.40 : appWidth * 0.25;
        double radius = crossAxisCount == 2
            ? appWidth * 0.025
            : appWidth * 0.015;
        double childAspectRatio = crossAxisCount == 2 ? 0.85 : 0.8;
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
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
                      source: getCoverArt(songList.first),
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
