part of '../../base/widgets/song_list.dart';

extension _SongListPanel on _SongListState {
  Widget panelView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Opacity(
          opacity: hideOthers ? 0 : 1,
          child: TitleBar(
            hintText: l10n.searchSongs,
            textController: textController,
            backToRoot: backToRoot,
            scrollToTop: () {
              scrollController.animateTo(
                0,
                duration: Duration(milliseconds: 250),
                curve: Curves.linear,
              );
            },
            findLocation: () {
              if (currentSongNotifier.value == null) {
                return;
              }
              final index = currentSongListNotifier.value.indexOf(
                currentSongNotifier.value!,
              );
              if (index == -1) {
                showCenterMessage(context, 'Current song not found');
                return;
              }
              final position = scrollController.position;
              final maxScrollExtent = position.maxScrollExtent;
              final minScrollExtent = position.minScrollExtent;
              scrollController.animateTo(
                (60 * index + 355 - (MediaQuery.heightOf(context) / 2)).clamp(
                  minScrollExtent,
                  maxScrollExtent,
                ),
                duration: Duration(milliseconds: 250),
                curve: Curves.linear,
              );
            },
          ),
        ),
        Expanded(child: panelContent(context)),
      ],
    );
  }

  Widget panelContent(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(padding: padding, child: panelHeader()),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: padding,
            child: Opacity(opacity: hideOthers ? 0 : 1, child: label()),
          ),
        ),

        SliverPadding(
          padding: padding,
          sliver: ValueListenableBuilder(
            valueListenable: currentSongListNotifier,
            builder: (context, currentSongList, child) {
              return SliverReorderableList(
                itemExtent: 60,
                itemBuilder: (context, index) {
                  if (hideOthers) {
                    return SizedBox(key: ValueKey(index));
                  }
                  return ReorderableDragStartListener(
                    key: ValueKey(currentSongList[index]),
                    enabled: !isFixed,
                    index: index,
                    child: songListItem(index),
                  );
                },
                itemCount: currentSongList.length,
                onReorderItem: (oldIndex, newIndex) {
                  final item = songList.removeAt(oldIndex);
                  songList.insert(newIndex, item);

                  if (isLibrary) {
                    library.update(sourceType);
                  } else if (folder != null) {
                    folder!.update();
                  } else {
                    playlist!.update(getSourceTypeBitMask(sourceType));
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget panelHeader() {
    final l10n = AppLocalizations.of(context);

    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;

    return SizedBox(
      height: isPhone ? 160 : 200,
      child: Row(
        children: [
          mainCover(isPhone ? 120 : 160),
          if (!hideOthers) SizedBox(width: 10),
          if (!hideOthers)
            Expanded(
              child: Column(
                children: [
                  SizedBox(height: isPhone ? 15 : 30),
                  ListTile(
                    title: AutoSizeText(
                      getTitleText(l10n),
                      maxLines: 1,
                      minFontSize: 20,
                      maxFontSize: 20,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: ValueListenableBuilder(
                      valueListenable: currentSongListNotifier,
                      builder: (context, currentSongList, child) {
                        String prefix = getSourceTypeName(l10n, sourceType);
                        return Text(
                          "$prefix: ${l10n.songCount(currentSongList.length)}",
                        );
                      },
                    ),
                  ),
                  Spacer(),

                  ListenableBuilder(
                    listenable: Listenable.merge([
                      buttonColor.valueNotifier,
                      if (folder == null) songListManager.changeNotifier,
                    ]),
                    builder: (_, _) {
                      final buttonStyle = ElevatedButton.styleFrom(
                        backgroundColor: buttonColor.value,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.all(10),
                      );
                      return SizedBox(
                        height: isMobile ? 40 : 35,
                        child: ListView(
                          scrollDirection: .horizontal,
                          children: [
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                if (currentSongListNotifier.value.isEmpty) {
                                  return;
                                }
                                audioHandler.currentIndex = 0;
                                playModeNotifier.value = 0;
                                await audioHandler.setPlayQueue(
                                  currentSongListNotifier.value,
                                );
                                await audioHandler.load();
                                audioHandler.play();
                              },
                              style: buttonStyle,
                              child: Text(l10n.playAll),
                            ),

                            SizedBox(width: 15),
                            ElevatedButton(
                              onPressed: () async {
                                if (currentSongListNotifier.value.isEmpty) {
                                  return;
                                }
                                audioHandler.currentIndex = Random().nextInt(
                                  currentSongListNotifier.value.length,
                                );
                                playModeNotifier.value = 1;
                                await audioHandler.setPlayQueue(
                                  currentSongListNotifier.value,
                                );
                                await audioHandler.load();
                                audioHandler.play();
                              },
                              style: buttonStyle,
                              child: Text(l10n.shuffle),
                            ),

                            if (isMobile) ...[
                              SizedBox(width: 15),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (_) => SelectableSongListPage(
                                        songList: songList,
                                        playlist: playlist,
                                        folder: folder,
                                        isRanking: isRanking,
                                        isRecently: isRecently,
                                        isLibrary: isLibrary,
                                        reorderable: reorderable,
                                      ),
                                    ),
                                  );
                                },
                                style: buttonStyle,
                                child: Text(l10n.select),
                              ),
                            ],

                            if (folder == null &&
                                songListManager.notEmptyCount >= 2) ...[
                              SizedBox(width: 15),
                              ElevatedButton(
                                onPressed: () async {
                                  widget.switchCallBack!(context);
                                },
                                style: buttonStyle,
                                child: Text(l10n.switch_),
                              ),
                            ],

                            if (isLibrary &&
                                    (sourceType == .local ||
                                        sourceType == .webdav) ||
                                folder != null) ...[
                              SizedBox(width: 15),
                              ElevatedButton(
                                onPressed: () {
                                  showAnimationDialog(
                                    context: context,
                                    child: SizedBox(
                                      width: 300,
                                      height: isMobile ? 300 : 280,
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Builder(
                                          builder: (context) {
                                            return ListView(
                                              children: [
                                                ListTile(
                                                  title: Text(l10n.defaultText),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    sortTypeNotifier.value = 0;
                                                  },
                                                  trailing:
                                                      sortTypeNotifier.value ==
                                                          0
                                                      ? Icon(Icons.check)
                                                      : null,
                                                ),
                                                ListTile(
                                                  title: Text(
                                                    l10n.modifiedTimeAscending,
                                                  ),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    sortTypeNotifier.value = 9;
                                                  },
                                                  trailing:
                                                      sortTypeNotifier.value ==
                                                          9
                                                      ? Icon(Icons.check)
                                                      : null,
                                                ),
                                                ListTile(
                                                  title: Text(
                                                    l10n.modifiedTimedescending,
                                                  ),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    sortTypeNotifier.value = 10;
                                                  },
                                                  trailing:
                                                      sortTypeNotifier.value ==
                                                          10
                                                      ? Icon(Icons.check)
                                                      : null,
                                                ),
                                                ListTile(
                                                  title: Text(
                                                    l10n.randomizeTemp,
                                                  ),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    sortTypeNotifier.value = 11;
                                                  },
                                                  trailing:
                                                      sortTypeNotifier.value ==
                                                          11
                                                      ? Icon(Icons.check)
                                                      : null,
                                                ),
                                                ListTile(
                                                  title: Text(
                                                    l10n.randomizePermanent,
                                                  ),
                                                  onTap: () async {
                                                    Navigator.pop(context);
                                                    if (!await showConfirmDialog(
                                                      context,
                                                      l10n.cannotBeUndone,
                                                    )) {
                                                      return;
                                                    }
                                                    sortTypeNotifier.value = 0;
                                                    if (isLibrary) {
                                                      library.shuffle(
                                                        sourceType,
                                                      );
                                                    } else {
                                                      folder!.shuffle();
                                                    }
                                                  },
                                                  trailing:
                                                      sortTypeNotifier.value ==
                                                          12
                                                      ? Icon(Icons.check)
                                                      : null,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                style: buttonStyle,
                                child: Icon(Icons.sort),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: isPhone ? 20 : 30),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget label() {
    final l10n = AppLocalizations.of(context);
    bool canSort = !isRanking && !isRecently;
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          SizedBox(width: 60, child: Center(child: Text('#'))),

          Expanded(
            flex: 4,
            child: InkWell(
              mouseCursor: canSort
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              borderRadius: BorderRadius.circular(5),
              onTap: canSort
                  ? () {
                      if (sortTypeNotifier.value > 4) {
                        sortTypeNotifier.value = 1;
                      } else if (sortTypeNotifier.value < 4) {
                        sortTypeNotifier.value++;
                      } else {
                        sortTypeNotifier.value = 0;
                      }
                      playlist?.saveSetting();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: ValueListenableBuilder(
                  valueListenable: sortTypeNotifier,
                  builder: (context, value, child) {
                    String text = '${l10n.title} & ${l10n.artist}';
                    switch (value) {
                      case 1:
                      case 2:
                        text = l10n.title;
                        break;
                      case 3:
                      case 4:
                        text = l10n.artist;
                        break;
                    }
                    return Row(
                      children: [
                        Text(text, overflow: TextOverflow.ellipsis),
                        if (value > 0 && value <= 4)
                          ImageIcon(
                            (value == 1 || value == 3)
                                ? longArrowUpImage
                                : longArrowDownImage,
                            size: 20,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          SizedBox(width: 10),

          Expanded(
            flex: 3,
            child: InkWell(
              mouseCursor: canSort
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              borderRadius: BorderRadius.circular(5),
              onTap: canSort
                  ? () {
                      if (sortTypeNotifier.value == 5) {
                        sortTypeNotifier.value = 6;
                      } else if (sortTypeNotifier.value == 6) {
                        sortTypeNotifier.value = 0;
                      } else {
                        sortTypeNotifier.value = 5;
                      }
                      playlist?.saveSetting();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(l10n.album, overflow: TextOverflow.ellipsis),
                    ValueListenableBuilder(
                      valueListenable: sortTypeNotifier,
                      builder: (context, value, child) {
                        if (value == 5 || value == 6) {
                          return ImageIcon(
                            value == 5 ? longArrowUpImage : longArrowDownImage,
                            size: 20,
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(
            width: 80,
            child: Center(
              child: Text(l10n.favorited, overflow: TextOverflow.ellipsis),
            ),
          ),

          SizedBox(
            width: 80,
            child: InkWell(
              mouseCursor: canSort
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              borderRadius: BorderRadius.circular(5),
              onTap: canSort
                  ? () {
                      if (sortTypeNotifier.value == 7) {
                        sortTypeNotifier.value = 8;
                      } else if (sortTypeNotifier.value == 8) {
                        sortTypeNotifier.value = 0;
                      } else {
                        sortTypeNotifier.value = 7;
                      }
                      playlist?.saveSetting();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(l10n.duration, overflow: TextOverflow.ellipsis),
                    ValueListenableBuilder(
                      valueListenable: sortTypeNotifier,
                      builder: (context, value, child) {
                        if (value == 7 || value == 8) {
                          return ImageIcon(
                            value == 7 ? longArrowUpImage : longArrowDownImage,
                            size: 20,
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isRanking)
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(l10n.times, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
  }

  Widget songListItem(int index) {
    final currentSongList = currentSongListNotifier.value;
    final isSelected = isSelectedList[index];
    final song = currentSongList[index];
    final showPlayButtonNotifier = showPlayButtonNotifierMap[song]!;
    return ValueListenableBuilder(
      valueListenable: isSelected,
      builder: (context, value, child) {
        return ValueListenableBuilder(
          valueListenable: selectedItemColor.valueNotifier,
          builder: (context, color, _) {
            return Material(
              color: value ? color : Colors.transparent,
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: .circular(10),
              ),
              clipBehavior: .antiAlias,
              child: child,
            );
          },
        );
      },
      child: MouseRegion(
        onEnter: (event) {
          showPlayButtonNotifier.value = true;
        },
        onExit: (event) {
          showPlayButtonNotifier.value = false;
        },
        child: Builder(
          builder: (context) {
            return GestureDetector(
              child: InkWell(
                child: ValueListenableBuilder(
                  valueListenable: song.updateNotifier,
                  builder: (_, _, _) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Center(
                            child: indexOrPlayButton(
                              showPlayButtonNotifier,
                              index,
                            ),
                          ),
                        ),

                        Expanded(flex: 4, child: mainInfo(song)),

                        SizedBox(width: 10),

                        Expanded(
                          flex: 3,
                          child: Text(
                            getAlbum(song),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        SizedBox(
                          width: 80,
                          child: Center(
                            child: IconButton(
                              onPressed: () {
                                toggleFavoriteState(song);
                              },
                              icon: ValueListenableBuilder(
                                valueListenable: song.isFavoriteNotifier,
                                builder: (context, value, child) {
                                  return value
                                      ? Icon(
                                          Icons.favorite_rounded,
                                          color: Colors.red,
                                          size: 20,
                                        )
                                      : Icon(Icons.favorite_outline, size: 20);
                                },
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          width: 80,
                          child: Text(
                            formatDuration(getDuration(song)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        if (widget.isRanking)
                          SizedBox(
                            width: 50,
                            child: Text(
                              song.playCount.toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                onTap: () async {
                  if (ctrlIsPressed) {
                    isSelected.value = !isSelected.value;
                    continuousSelectBeginIndex = index;
                  } else if (shiftIsPressed) {
                    int left = continuousSelectBeginIndex < index
                        ? continuousSelectBeginIndex
                        : index;
                    int right = continuousSelectBeginIndex > index
                        ? continuousSelectBeginIndex
                        : index;

                    for (int i = 0; i < isSelectedList.length; i++) {
                      if (i < left || i > right) {
                        isSelectedList[i].value = false;
                      } else {
                        isSelectedList[i].value = true;
                      }
                    }
                  } else {
                    // clear select
                    for (var tmp in isSelectedList) {
                      tmp.value = false;
                    }
                    isSelected.value = true;
                    continuousSelectBeginIndex = index;
                  }

                  if (isMobile || waitForSecondClick) {
                    waitForSecondClick = false;
                    doubleClicktimer?.cancel();
                    audioHandler.currentIndex = index;
                    await audioHandler.setPlayQueue(currentSongList);
                    await audioHandler.load();
                    audioHandler.play();
                  } else {
                    doubleClicktimer = Timer(Duration(milliseconds: 250), () {
                      waitForSecondClick = false;
                    });
                    waitForSecondClick = true;
                  }
                },
                onSecondaryTapUp: (details) {
                  popContextMenu(context, index, details.globalPosition);
                },
              ),
              onTapDown: (details) {
                if (Platform.isIOS) {
                  popContextMenu(context, index, details.globalPosition);
                }
              },
              onLongPressStart: (details) {
                if (Platform.isAndroid) {
                  tryVibrate();
                  popContextMenu(context, index, details.globalPosition);
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget indexOrPlayButton(ValueNotifier<bool> showPlayButtonNotifier, index) {
    return ValueListenableBuilder(
      valueListenable: showPlayButtonNotifier,
      builder: (context, value, child) {
        return value
            ? IconButton(
                onPressed: () async {
                  audioHandler.currentIndex = index;
                  await audioHandler.setPlayQueue(
                    currentSongListNotifier.value,
                  );
                  await audioHandler.load();
                  audioHandler.play();
                },
                icon: Icon(Icons.play_arrow_rounded),
              )
            : Text((index + 1).toString(), overflow: TextOverflow.ellipsis);
      },
    );
  }

  Widget mainInfo(MyAudioMetadata song) {
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        return ListTile(
          contentPadding: .zero,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          leading: CoverArtWidget(size: 40, borderRadius: 4, song: song),
          title: ValueListenableBuilder(
            valueListenable: highlightTextColor.valueNotifier,
            builder: (context, value, child) {
              return Text(
                getTitle(song),
                overflow: TextOverflow.ellipsis,
                style: song == currentSong
                    ? TextStyle(
                        color: value,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      )
                    : TextStyle(fontSize: 15),
              );
            },
          ),
          subtitle: ValueListenableBuilder(
            valueListenable: highlightTextColor.valueNotifier,
            builder: (context, value, child) {
              return Text(
                getArtist(song),
                overflow: TextOverflow.ellipsis,
                style: song == currentSong
                    ? TextStyle(
                        color: value,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )
                    : TextStyle(fontSize: 12),
              );
            },
          ),
        );
      },
    );
  }

  void popContextMenu(BuildContext context, int index, Offset globalPosition) {
    final currentSongList = currentSongListNotifier.value;
    final isSelected = isSelectedList[index];
    // select current and clear others if it's not selected
    if (!isSelected.value) {
      for (var tmp in isSelectedList) {
        tmp.value = false;
      }
      isSelected.value = true;
      continuousSelectBeginIndex = index;
    }

    final selectedSongList = <MyAudioMetadata>[];

    for (int i = 0; i < isSelectedList.length; i++) {
      if (isSelectedList[i].value) {
        selectedSongList.add(currentSongList[i]);
      }
    }

    final l10n = AppLocalizations.of(context);
    List<MenuItem> menuItems = [];

    if (selectedSongList.length == 1 &&
        reorderable &&
        textController.text.isEmpty &&
        sortTypeNotifier.value == 0) {
      menuItems.add(
        MenuItem(
          iconData: Icons.vertical_align_top_rounded,
          text: l10n.move2Top,
          callback: () async {
            final item = songList.removeAt(index);
            songList.insert(0, item);

            if (isLibrary) {
              library.update(sourceType);
            } else if (folder != null) {
              folder!.update();
            } else {
              playlist!.update(getSourceTypeBitMask(item.sourceType));
            }
          },
        ),
      );
    }
    menuItems.add(
      MenuItem(
        iconData: Icons.play_arrow_rounded,
        text: l10n.playNow,
        callback: () async {
          MyAudioMetadata? tmp;
          for (int i = selectedSongList.length - 1; i >= 0; i--) {
            tmp = selectedSongList[i];
            audioHandler.insert2Next(tmp);
          }

          if (tmp != currentSongNotifier.value) {
            await audioHandler.skipToNext();
          }
          audioHandler.play();
          audioHandler.saveAllStates();
        },
      ),
    );

    menuItems.add(
      MenuItem(
        iconData: Icons.navigate_next_rounded,
        text: l10n.playNext,
        callback: () async {
          for (int i = selectedSongList.length - 1; i >= 0; i--) {
            audioHandler.insert2Next(selectedSongList[i]);
          }

          if (audioHandler.currentIndex == -1) {
            await audioHandler.skipToNext();
            audioHandler.play();
          }
          audioHandler.saveAllStates();
        },
      ),
    );

    menuItems.add(
      MenuItem(
        text: l10n.add2Queue,
        iconData: Icons.playlist_add_rounded,
        callback: () async {
          for (int i = 0; i < selectedSongList.length; i++) {
            audioHandler.add2Last(selectedSongList[i]);
          }

          if (audioHandler.currentIndex == -1) {
            await audioHandler.skipToNext();
            audioHandler.play();
          }
          audioHandler.saveAllStates();
        },
      ),
    );

    menuItems.add(
      MenuItem(
        text: l10n.add2Playlist,
        iconData: Icons.add_rounded,
        callback: () {
          showAddPlaylistDialog(context, selectedSongList.reversed.toList());
        },
      ),
    );

    menuItems.add(MenuItem(isDivider: true));

    if (selectedSongList.length == 1) {
      menuItems.add(
        MenuItem(
          text: l10n.go2Artist,
          iconData: Icons.people,
          callback: () async {
            final artists = getArtists(getArtist(currentSongList[index]));
            if (artists.length > 1) {
              showArtistEntries(context, artists);
            } else {
              await Future.delayed(Duration(milliseconds: 250));
              layersManager.switchRootLayer('artists');
              layersManager.pushDetailIfNeed(
                artistAlbumManager.name2Artist[artists[0]],
              );
            }
          },
        ),
      );

      menuItems.add(
        MenuItem(
          text: l10n.go2Album,
          iconData: Icons.album_rounded,
          callback: () async {
            await Future.delayed(Duration(milliseconds: 250));
            layersManager.switchRootLayer('albums');
            layersManager.pushDetailIfNeed(
              artistAlbumManager.name2Album[getAlbum(currentSongList[index])],
            );
          },
        ),
      );

      menuItems.add(
        MenuItem(
          text: l10n.songInfo,
          iconData: Icons.info_outline_rounded,
          callback: () {
            showAnimationDialog(
              context: context,
              child: SongInfo(song: currentSongList[index]),
            );
          },
        ),
      );

      if (sourceType == .local) {
        menuItems.add(
          MenuItem(
            iconData: Icons.edit_rounded,
            text: l10n.editMetadata,
            callback: () {
              showAnimationDialog(
                context: context,
                child: EditMetadata(song: currentSongList[index]),
              );
            },
          ),
        );
      }
    }

    if (playlist != null) {
      menuItems.add(
        MenuItem(
          text: l10n.delete,
          iconData: Icons.delete_rounded,
          callback: () async {
            if (await showConfirmDialog(context, l10n.delete)) {
              playlist!.remove(selectedSongList);
            }
          },
        ),
      );
    }

    if (menuItems.last.isDivider) {
      menuItems.removeLast();
    }

    showContextMenu(context, menuItems, globalPosition);
  }
}
