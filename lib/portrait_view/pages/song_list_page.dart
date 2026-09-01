part of '../../base/widgets/song_list.dart';

extension _SongListPage on _SongListState {
  Widget pageView(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          customAppBar(context),
          Expanded(child: contentWithStack()),
        ],
      ),
    );
  }

  PreferredSizeWidget customAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: customAppBarLeading(context, label: rootLabel),
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      systemOverlayStyle: mainPageThemeNotifier.value == .dark ? .light : .dark,
      actions: [
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, value, child) {
            return MySearchField(
              key: ValueKey(getFirstSong(songList)),
              hintText: AppLocalizations.of(context).searchSongs,
              textController: textController,
              isSearchNotifier: isSearchNotifier,
              useCurrentSong: false,
            );
          },
        ),
        moreButton(context),
      ],
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
      height: 300,
      Column(
        children: [
          ListTile(
            title: Row(
              children: [
                if (playlist != null)
                  Text("${l10n.playlists}: ", style: TextStyle(fontSize: 15)),
                if (artist != null)
                  Text("${l10n.artists}: ", style: TextStyle(fontSize: 15)),
                if (album != null)
                  Text("${l10n.albums}: ", style: TextStyle(fontSize: 15)),
                if (folder != null)
                  Text("${l10n.folders}: ", style: TextStyle(fontSize: 15)),

                Expanded(
                  child: TextScroll(
                    getTitleText(l10n),
                    style: TextStyle(fontSize: 15),
                    velocity: const .new(pixelsPerSecond: .new(40, 0)),
                    intervalSpaces: 10,
                    pauseBetween: Duration(seconds: 2),
                  ),
                ),
              ],
            ),
          ),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),
          ListTile(
            leading: ImageIcon(selectImage),
            title: Text(
              l10n.select,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
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
          ),
          if (!isRanking && !isRecently)
            ListTile(
              leading: ImageIcon(sequenceImage),
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
                    if (isLibrary && (isNotStreamSource) || folder != null) {
                      orderText.add(l10n.modifiedTimeAscending);
                      orderText.add(l10n.modifiedTimedescending);
                      orderText.add(l10n.randomizeTemp);
                      orderText.add(l10n.randomizePermanent);
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
                              onTap: () async {
                                if (i == 12) {
                                  if (!await showConfirmDialog(
                                    context,
                                    l10n.cannotBeUndone,
                                  )) {
                                    return;
                                  }
                                  sortTypeNotifier.value = 0;
                                  if (isLibrary) {
                                    library.shuffle();
                                  } else {
                                    folder!.shuffle();
                                  }
                                } else {
                                  if (i == 11 && sortTypeNotifier.value == 11) {
                                    updateSongList();
                                  }
                                  sortTypeNotifier.value = i;
                                }
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

          if (playlist != null && playlist!.isNotFavorite)
            ListTile(
              leading: ImageIcon(deleteImage),
              title: Text(
                l10n.delete,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () async {
                if (await showConfirmDialog(context, l10n.delete)) {
                  layersManager.removeLayerIfNeed(playlist!);
                  playlistManager.deletePlaylist(playlist!);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  Widget contentWithStack() {
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              listIsScrollingNotifier.value = true;
              if (timer != null) {
                timer!.cancel();
                timer = null;
              }
            } else {
              if (listIsScrollingNotifier.value) {
                timer ??= Timer(const Duration(milliseconds: 3000), () {
                  listIsScrollingNotifier.value = false;
                  timer = null;
                });
              }
            }
            return false;
          },
          child: pageContent(),
        ),
        Positioned(
          right: 30,
          bottom: 180,
          child: ValueListenableBuilder(
            valueListenable: listIsScrollingNotifier,
            builder: (context, value, child) {
              if (!value) {
                return SizedBox.shrink();
              }
              return IconButton(
                onPressed: () {
                  scrollController.animateTo(
                    0,
                    duration: Duration(milliseconds: 250),
                    curve: Curves.linear,
                  );
                },
                icon: ImageIcon(topArrowImage),
              );
            },
          ),
        ),

        Positioned(
          right: 30,
          bottom: 120,
          child: MyLocation(
            scrollController: scrollController,
            listIsScrollingNotifier: listIsScrollingNotifier,
            currentSongListNotifier: currentSongListNotifier,
            offset: 300 - MediaQuery.heightOf(context) / 2,
          ),
        ),
      ],
    );
  }

  Widget pageHeader() {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;

    return Column(
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 20),
            mainCover(isPhone ? 120 : 160),
            Expanded(
              child: ListTile(
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
                    String prefix = getSourceTypeDisplayName(l10n, sourceType);
                    return Text(
                      "$prefix: ${l10n.songCount(currentSongList.length)}",
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget pageContent() {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: pageHeader()),
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, currentSongList, child) {
            if (firstLoading) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: iconColor.value),
                ),
              );
            }
            return SliverFixedExtentList.builder(
              itemExtent: 60,
              itemCount: currentSongList.length,
              itemBuilder: (context, index) {
                return Center(
                  child: SongListTile(
                    index: index,
                    songList: currentSongList,
                    artist: artist,
                    album: album,
                    folder: folder,
                    playlist: playlist,
                    isRanking: isRanking,
                    isLibrary: isLibrary,
                    reorderable:
                        reorderable &&
                        textController.text.isEmpty &&
                        sortTypeNotifier.value == 0,
                  ),
                );
              },
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}
