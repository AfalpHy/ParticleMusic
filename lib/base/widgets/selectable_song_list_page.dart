import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/widgets/selectable_song_list_tile.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/portrait_view/my_search_field.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

class SelectableSongListPage extends StatefulWidget {
  final List<MyAudioMetadata> songList;

  final Playlist? playlist;
  final Folder? folder;
  final bool isRanking;
  final bool isRecently;
  final bool isLibrary;

  final bool reorderable;

  const SelectableSongListPage({
    super.key,
    required this.songList,
    this.playlist,
    this.folder,
    this.isRanking = false,
    this.isRecently = false,
    this.isLibrary = false,
    required this.reorderable,
  });

  @override
  State<StatefulWidget> createState() => SelectableSongListPageState();
}

class SelectableSongListPageState extends State<SelectableSongListPage> {
  late List<MyAudioMetadata> songList;
  Playlist? playlist;
  Folder? folder;
  late bool isRanking;
  late bool isRecently;
  late bool isLibrary;

  final textController = TextEditingController();
  ValueNotifier<int> sortTypeNotifier = ValueNotifier(0);

  final ValueNotifier<bool> allSelected = ValueNotifier(false);
  final ValueNotifier<int> selectedNumNotifier = ValueNotifier(0);

  List<ValueNotifier<bool>> isSelectedList = [];

  final ValueNotifier<List<MyAudioMetadata>> currentSongListNotifier =
      ValueNotifier([]);

  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

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
    folder = widget.folder;
    isRanking = widget.isRanking;
    isRecently = widget.isRecently;
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
      height: 250,
      Column(
        children: [
          ListTile(title: Text(l10n.select, style: TextStyle(fontSize: 15))),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),

          if (!isRanking && !isRecently)
            ListTile(
              leading: ImageIcon(sequenceImage, color: iconColor.value),
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

                    if ((isLibrary && sourceType == .local) || folder != null) {
                      orderText.add(l10n.modifiedTimeAscending);
                      orderText.add(l10n.modifiedTimedescending);
                      orderText.add(l10n.randomizeTemp);
                    }
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
                          MyDivider(
                            thickness: 0.5,
                            height: 1,
                            color: dividerColor,
                          ),

                          Expanded(
                            child: ListView(
                              children: [...orderWidget, SizedBox(height: 50)],
                            ),
                          ),
                        ],
                      ),
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
    if (immersiveWideLayoutNotifier.value) {
      return content(context);
    }
    return SafeArea(child: content(context));
  }

  Widget content(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      color: backgroundCoverArtColor,
      child: Scaffold(
        backgroundColor: pageBackgroundColor.value,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: immersiveWideLayoutNotifier.value
              ? mainPageThemeNotifier.value == .dark
                    ? .light
                    : .dark
              : null,
          actions: [
            // TODO: search libary songs by search3 when
            // sourceType == navidrome && isLibrary == true
            MySearchField(
              hintText: l10n.searchSongs,
              textController: textController,
              onSearchTextChanged: updateSongList,
              useCurrentSong: false,
            ),
            moreButton(context),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: currentSongListNotifier,
                  builder: (context, currentSongList, child) {
                    bool reorderable =
                        widget.reorderable &&
                        textController.text.isEmpty &&
                        sortTypeNotifier.value == 0;
                    return Column(
                      children: [
                        Row(
                          children: [
                            ValueListenableBuilder(
                              valueListenable: allSelected,
                              builder: (context, value, child) {
                                return Checkbox(
                                  value: value,
                                  activeColor: iconColor.value,
                                  onChanged: (value) {
                                    for (var isSelected in isSelectedList) {
                                      isSelected.value = value!;
                                    }
                                    selectedNumNotifier.value = value!
                                        ? currentSongList.length
                                        : 0;
                                  },
                                  shape: const CircleBorder(),
                                  side: BorderSide(
                                    color: iconColor.value.withAlpha(128),
                                  ),
                                );
                              },
                            ),
                            Text(
                              l10n.selectAll,
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            onReorderItem: (oldIndex, newIndex) {
                              final checkBoxitem = isSelectedList.removeAt(
                                oldIndex,
                              );
                              isSelectedList.insert(newIndex, checkBoxitem);

                              final item = songList.removeAt(oldIndex);
                              songList.insert(newIndex, item);
                              // This code is only reached when currentSongList == songList,
                              // reassign it to avoid calling updateSongList to keep the isSelectedList state
                              currentSongListNotifier.value = songList;

                              if (isLibrary) {
                                library.update();
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
                                (
                                  Widget child,
                                  int index,
                                  Animation<double> animation,
                                ) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: child,
                                  );
                                },
                            itemCount: currentSongList.length,
                            itemBuilder: (_, index) {
                              return MediaQuery.removePadding(
                                key: ValueKey(currentSongList[index]),
                                context: context,
                                removeLeft: true, // for mobile
                                removeRight: true,
                                child: SelectableSongListTile(
                                  index: index,
                                  source: currentSongList,
                                  isSelected: isSelectedList[index],
                                  selectedNumNotifier: selectedNumNotifier,
                                  reorderable: reorderable,
                                  isRanking: isRanking,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ValueListenableBuilder(
          valueListenable: selectedNumNotifier,
          builder: (context, value, child) {
            final valid = value > 0;
            final color = valid
                ? iconColor.value
                : iconColor.value.withAlpha(128);
            return SizedBox(
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () async {
                            if (valid) {
                              tryVibrate();
                              for (
                                int i = isSelectedList.length - 1;
                                i >= 0;
                                i--
                              ) {
                                if (isSelectedList[i].value) {
                                  audioHandler.insert2Next(
                                    currentSongListNotifier.value[i],
                                  );
                                }
                              }
                              showCenterMessage('Added to Play Queue');
                              if (audioHandler.currentIndex == -1) {
                                await audioHandler.skipToNext();
                                audioHandler.play();
                              }

                              audioHandler.saveAllStates();
                            }
                          },
                          icon: Icon(Icons.navigate_next_rounded),
                          color: color,
                        ),

                        Transform.translate(
                          offset: Offset(0, -10),
                          child: Text(
                            l10n.playNext,
                            style: TextStyle(color: color, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () async {
                            if (valid) {
                              tryVibrate();
                              for (int i = 0; i < isSelectedList.length; i++) {
                                if (isSelectedList[i].value) {
                                  audioHandler.add2Last(
                                    currentSongListNotifier.value[i],
                                  );
                                }
                              }
                              showCenterMessage('Added to Play Queue');
                              if (audioHandler.currentIndex == -1) {
                                await audioHandler.skipToNext();
                                audioHandler.play();
                              }

                              audioHandler.saveAllStates();
                            }
                          },
                          icon: Icon(Icons.playlist_add_rounded),
                          color: color,
                        ),

                        Transform.translate(
                          offset: Offset(0, -10),
                          child: Text(
                            l10n.add2Queue,
                            style: TextStyle(color: color, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: GestureDetector(
                      onTap: () {},
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (valid) {
                                tryVibrate();
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
                                showAddPlaylistDialog(context, tmpSongList);
                              }
                            },
                            icon: Icon(Icons.add_rounded),
                            color: color,
                          ),

                          Transform.translate(
                            offset: Offset(0, -10),
                            child: Text(
                              l10n.add2Playlist,
                              style: TextStyle(color: color, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (playlist != null)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () async {
                              if (valid) {
                                tryVibrate();
                                if (await showConfirmDialog(
                                  context,
                                  l10n.delete,
                                )) {
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
                                }
                              }
                            },
                            icon: Icon(Icons.delete_rounded),
                            color: color,
                          ),

                          Transform.translate(
                            offset: Offset(0, -10),
                            child: Text(
                              l10n.delete,
                              style: TextStyle(color: color, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
