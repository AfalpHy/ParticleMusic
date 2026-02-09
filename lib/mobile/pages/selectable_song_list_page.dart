import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_auto_size_text.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/library_manager.dart';
import 'package:particle_music/mobile/selectable_song_list_tile.dart';
import 'package:particle_music/mobile/widgets/my_search_field.dart';
import 'package:particle_music/mobile/widgets/my_sheet.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';

class SelectableSongListPage extends StatefulWidget {
  final List<MyAudioMetadata> songList;

  final Playlist? playlist;
  final String? artist;
  final String? album;
  final Folder? folder;
  final String? ranking;
  final String? recently;

  final bool isLibrary;

  const SelectableSongListPage({
    super.key,
    required this.songList,
    this.playlist,
    this.artist,
    this.album,
    this.folder,
    this.ranking,
    this.recently,
    required this.isLibrary,
  });

  @override
  State<StatefulWidget> createState() => SelectableSongListPageState();
}

class SelectableSongListPageState extends State<SelectableSongListPage> {
  late List<MyAudioMetadata> songList;
  Playlist? playlist;
  String? artist;
  String? album;
  Folder? folder;
  String? ranking;
  String? recently;

  late bool isLibrary;

  final textController = TextEditingController();
  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  final ValueNotifier<bool> allSelected = ValueNotifier(false);
  final ValueNotifier<int> selectedNumNotifier = ValueNotifier(0);

  List<ValueNotifier<bool>> isSelectedList = [];

  final ValueNotifier<List<MyAudioMetadata>> currentSongListNotifier =
      ValueNotifier([]);

  void updateSongList() {
    final value = textController.text;
    final filteredSongList = filterSongList(songList, value);
    sortSongList(sortTypeNotifier.value, filteredSongList);
    currentSongListNotifier.value = filteredSongList;
    isSelectedList = List.generate(
      filteredSongList.length,
      (_) => ValueNotifier(false),
    );
    selectedNumNotifier.value = 0;
  }

  @override
  void initState() {
    super.initState();

    songList = widget.songList;
    playlist = widget.playlist;
    artist = widget.artist;
    album = widget.album;
    folder = widget.folder;
    ranking = widget.ranking;
    recently = widget.recently;
    isLibrary = widget.isLibrary;

    selectedNumNotifier.addListener(() {
      if (selectedNumNotifier.value > 0 &&
          selectedNumNotifier.value == currentSongListNotifier.value.length) {
        allSelected.value = true;
      } else {
        allSelected.value = false;
      }
    });
    updateSongList();
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
        ).then((value) {
          if (value == true && context.mounted) {
            Navigator.pop(context);
          }
        });
      },
    );
  }

  Widget moreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
      Column(
        children: [
          ListTile(
            title: SizedBox(
              height: 40,
              width: appWidth * 0.9,
              child: Row(
                children: [
                  Expanded(
                    child: MyAutoSizeText(
                      l10n.select,
                      maxLines: 1,
                      textStyle: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(thickness: 0.5, height: 1, color: dividerColor),

          if (ranking == null && recently == null)
            ListTile(
              leading: const ImageIcon(sequenceImage, color: Colors.black),
              title: Text(
                l10n.sortSongs,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);

                    List<String> orderText = [
                      l10n.defaultText,
                      l10n.titleAscending,
                      l10n.titleDescending,
                      l10n.artistAscending,
                      l10n.artistDescending,
                      l10n.albumAscending,
                      l10n.albumDescending,
                      l10n.durationAscending,
                      l10n.durationDescending,
                    ];
                    List<Widget> orderWidget = [];
                    for (int i = 0; i < orderText.length; i++) {
                      String text = orderText[i];
                      orderWidget.add(
                        ValueListenableBuilder(
                          valueListenable: sortTypeNotifier,
                          builder: (context, value, child) {
                            return ListTile(
                              title: Text(text),
                              onTap: () {
                                sortTypeNotifier.value = i;
                                updateSongList();
                              },
                              trailing: value == i ? Icon(Icons.check) : null,
                              dense: true,
                              visualDensity: VisualDensity(
                                horizontal: 0,
                                vertical: -4,
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return MySheet(
                      Column(
                        children: [
                          ListTile(title: Text(l10n.selectSortingType)),
                          Divider(
                            thickness: 0.5,
                            height: 1,
                            color: dividerColor,
                          ),

                          ...orderWidget,
                        ],
                      ),
                      height: 400,
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: commonColor,
      appBar: AppBar(
        backgroundColor: commonColor,
        scrolledUnderElevation: 0,
        actions: [
          MySearchField(
            textController: textController,
            onSearchTextChanged: updateSongList,
          ),
          moreButton(context),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: currentSongListNotifier,
        builder: (context, currentSongList, child) {
          return Column(
            children: [
              Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: allSelected,
                    builder: (context, value, child) {
                      return Checkbox(
                        value: value,
                        activeColor: iconColor,
                        onChanged: (value) {
                          for (var isSelected in isSelectedList) {
                            isSelected.value = value!;
                          }
                          selectedNumNotifier.value = value!
                              ? currentSongList.length
                              : 0;
                        },
                        shape: const CircleBorder(),
                        side: BorderSide(color: Colors.grey),
                      );
                    },
                  ),
                  Text(l10n.selectAll, style: TextStyle(fontSize: 16)),
                  Spacer(),

                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.complete, style: TextStyle(fontSize: 16)),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final checkBoxitem = isSelectedList.removeAt(oldIndex);
                    isSelectedList.insert(newIndex, checkBoxitem);

                    final item = songList.removeAt(oldIndex);
                    songList.insert(newIndex, item);
                    // This code is only reached when currentSongList == songList,
                    // reassign it to avoid calling updateSongList to keep the isSelectedList state
                    currentSongListNotifier.value = songList;

                    if (isLibrary) {
                      libraryManager.update();
                    } else if (folder != null) {
                      folder!.update();
                    } else {
                      playlist!.update();
                    }
                  },
                  onReorderStart: (_) {
                    tryVibrate();
                  },
                  onReorderEnd: (_) {
                    tryVibrate();
                  },
                  proxyDecorator:
                      (Widget child, int index, Animation<double> animation) {
                        return Material(
                          elevation: 0.1,
                          color: Colors
                              .grey
                              .shade100, // background color while moving
                          child: child,
                        );
                      },
                  itemCount: currentSongList.length,
                  itemBuilder: (_, index) {
                    return SelectableSongListTile(
                      key: ValueKey(currentSongList[index]),
                      index: index,
                      source: currentSongList,
                      isSelected: isSelectedList[index],
                      selectedNumNotifier: selectedNumNotifier,
                      reorderable:
                          !(artist != null ||
                              album != null ||
                              ranking != null ||
                              recently != null ||
                              textController.text.isNotEmpty ||
                              sortTypeNotifier.value > 0),
                      isRanking: ranking != null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: selectedNumNotifier,
        builder: (context, value, child) {
          final valid = value > 0;
          final color = valid ? iconColor : Colors.black54;
          return SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (valid) {
                        tryVibrate();
                        for (int i = isSelectedList.length - 1; i >= 0; i--) {
                          if (isSelectedList[i].value) {
                            audioHandler.insert2Next(
                              currentSongListNotifier.value[i],
                            );
                          }
                        }
                        showCenterMessage(
                          context,
                          'Added to Play Queue',
                          duration: 1000,
                        );
                        if (audioHandler.currentIndex == -1) {
                          await audioHandler.skipToNext();
                          audioHandler.play();
                        }

                        audioHandler.saveAllStates();
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageIcon(playnextCircleImage, color: color),

                        Text(l10n.playNext, style: TextStyle(color: color)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (valid) {
                        tryVibrate();
                        List<MyAudioMetadata> tmpSongList = [];
                        for (int i = isSelectedList.length - 1; i >= 0; i--) {
                          if (isSelectedList[i].value) {
                            tmpSongList.add(currentSongListNotifier.value[i]);
                          }
                        }
                        showAddPlaylistSheet(context, tmpSongList);
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageIcon(playlistAddImage, color: color),

                        Text(
                          l10n.add2Playlists,
                          style: TextStyle(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                if (playlist != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (valid) {
                          tryVibrate();
                          if (await showConfirmDialog(context, l10n.delete)) {
                            List<MyAudioMetadata> tmpSongList = [];
                            for (
                              int i = isSelectedList.length - 1;
                              i >= 0;
                              i--
                            ) {
                              if (isSelectedList[i].value) {
                                tmpSongList.add(
                                  currentSongListNotifier.value[i],
                                );
                              }
                            }
                            playlist!.remove(tmpSongList);
                            updateSongList();
                            if (context.mounted) {
                              showCenterMessage(
                                context,
                                'Successfully Deleted',
                                duration: 1000,
                              );
                            }
                          }
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ImageIcon(deleteImage, color: color),

                          Text(l10n.delete, style: TextStyle(color: color)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
