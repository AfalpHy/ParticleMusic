import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/widgets/selectable_song_list_tile.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/data/playlist.dart';

class SelectableSongListPage extends StatelessWidget {
  final List<MyAudioMetadata> songList;
  final Playlist? playlist;
  final Folder? folder;
  final bool isRanking;
  final bool isRecently;
  final bool isLibrary;
  final bool reorderable;

  final ValueNotifier<bool> allSelected = ValueNotifier(false);
  final ValueNotifier<int> selectedNumNotifier = ValueNotifier(0);

  final Map<MyAudioMetadata, ValueNotifier<bool>> isSelectedNotifierMap;

  SelectableSongListPage({
    super.key,
    required this.songList,
    this.playlist,
    this.folder,
    this.isRanking = false,
    this.isRecently = false,
    this.isLibrary = false,
    this.reorderable = false,
    required this.isSelectedNotifierMap,
  }) {
    for (final song in songList) {
      if (isSelectedNotifierMap[song]!.value) {
        selectedNumNotifier.value++;
      }
    }
    allSelected.value =
        songList.isNotEmpty && selectedNumNotifier.value == songList.length;
    selectedNumNotifier.addListener(() {
      allSelected.value =
          songList.isNotEmpty && selectedNumNotifier.value == songList.length;
    });
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
        ),
        body: SafeArea(
          child: Column(
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
                          for (final song in songList) {
                            isSelectedNotifierMap[song]!.value = value!;
                          }
                          selectedNumNotifier.value = value!
                              ? songList.length
                              : 0;
                        },
                        shape: const CircleBorder(),
                        side: BorderSide(color: iconColor.value.withAlpha(128)),
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
                  SizedBox(width: 20),
                ],
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIndex, newIndex) {
                    if (isLibrary) {
                      final item = library.songList.removeAt(oldIndex);
                      library.songList.insert(newIndex, item);
                      library.update();
                    } else if (folder != null) {
                      final item = folder!.songList.removeAt(oldIndex);
                      folder!.songList.insert(newIndex, item);
                      folder!.update();
                    } else {
                      final item = playlist!.songList.removeAt(oldIndex);
                      playlist!.songList.insert(newIndex, item);
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
                          color: Colors.transparent,
                          child: child,
                        );
                      },
                  itemCount: songList.length,
                  itemBuilder: (_, index) {
                    return MediaQuery.removePadding(
                      key: ValueKey(songList[index]),
                      context: context,
                      removeLeft: true, // for mobile
                      removeRight: true,
                      child: SelectableSongListTile(
                        index: index,
                        source: songList,
                        isSelected: isSelectedNotifierMap[songList[index]]!,
                        selectedNumNotifier: selectedNumNotifier,
                        reorderable: reorderable,
                        isRanking: isRanking,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: bottomButtons(l10n),
      ),
    );
  }

  List<MyAudioMetadata> getSelectedSongList() {
    final res = <MyAudioMetadata>[];
    for (int i = 0; i < songList.length; i++) {
      final song = songList[i];
      if (isSelectedNotifierMap[song]!.value) {
        res.add(song);
      }
    }
    return res;
  }

  Widget bottomButtons(AppLocalizations l10n) {
    return ValueListenableBuilder(
      valueListenable: selectedNumNotifier,
      builder: (context, value, child) {
        final valid = value > 0;
        final color = valid ? iconColor.value : iconColor.value.withAlpha(128);
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
                          for (final song in getSelectedSongList().reversed) {
                            audioHandler.insert2Next(song);
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

                          final selectedSongList = getSelectedSongList();
                          for (final song in selectedSongList) {
                            audioHandler.add2Last(song);
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

                            showAddPlaylistDialog(
                              context,
                              getSelectedSongList().reversed.toList(),
                            );
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
                            if (await showConfirmDialog(context, l10n.delete)) {
                              playlist!.remove(getSelectedSongList());
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
    );
  }
}
