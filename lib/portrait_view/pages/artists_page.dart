part of '../../layer/artists_layer.dart';

extension _ArtistsPage on _ArtistsLayerState {
  Widget pageView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: mainPageThemeNotifier.value == .dark
            ? .light
            : .dark,
        scrolledUnderElevation: 0,
        title: Text(l10n.artists),
        centerTitle: true,
        actions: [searchField(l10n.searchArtists), moreButton(context)],
      ),
      body: ValueListenableBuilder(
        valueListenable: artistAlbumManager.artistsIsListViewNotifier,
        builder: (context, isListView, child) {
          return ValueListenableBuilder(
            valueListenable: currentArtistListNotifier,
            builder: (context, list, child) {
              return isListView ? listView(list) : pageGridView(list);
            },
          );
        },
      ),
    );
  }

  Widget searchField(String hintText) {
    return MySearchField(
      hintText: hintText,
      textController: textController,
      onSearchTextChanged: updateCurrentList,
      isSearchNotifier: isSearchNotifier,
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
      height: 300,
      Column(
        children: [
          ListTile(title: Text(l10n.settings)),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),

          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: ValueListenableBuilder(
                    valueListenable:
                        artistAlbumManager.artistsIsListViewNotifier,
                    builder: (context, value, child) {
                      return ImageIcon(value ? listImage : gridImage);
                    },
                  ),
                  title: Text(
                    l10n.view,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -4,
                  ),
                  trailing: MySwitch(
                    trueText: l10n.list,
                    falseText: l10n.grid,
                    valueNotifier: artistAlbumManager.artistsIsListViewNotifier,
                    onToggleCallBack: () {
                      setting.save();
                    },
                  ),
                ),

                ValueListenableBuilder(
                  valueListenable: artistAlbumManager.artistsIsListViewNotifier,
                  builder: (context, value, child) {
                    if (value) {
                      return SizedBox.shrink();
                    }
                    return ListTile(
                      leading: ImageIcon(pictureImage),
                      title: Text(
                        l10n.pictureSize,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: MySwitch(
                        trueText: l10n.large,
                        falseText: l10n.small,
                        valueNotifier: useLargePictureNotifier,
                        onToggleCallBack: () {
                          setting.save();
                        },
                      ),
                    );
                  },
                ),

                ListTile(
                  leading: ImageIcon(sequenceImage),
                  title: Text(
                    l10n.order,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -4,
                  ),
                  trailing: MySwitch(
                    trueText: l10n.randomize,
                    falseText: l10n.normal,
                    valueNotifier: randomizeNotifier,
                    onToggleCallBack: () {
                      updateCurrentList();
                    },
                  ),
                ),

                ValueListenableBuilder(
                  valueListenable: randomizeNotifier,
                  builder: (_, randomize, _) {
                    if (randomize) {
                      return SizedBox();
                    }
                    return ListTile(
                      visualDensity: const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      trailing: MySwitch(
                        trueText: l10n.ascending,
                        falseText: l10n.descending,
                        valueNotifier: isAscendingNotifier,
                        onToggleCallBack: () {
                          setting.save();
                          artistAlbumManager.sortArtists();
                          updateCurrentList();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget listView(List<Artist> artistList) {
    return ListView.builder(
      itemExtent: 64,
      itemCount: artistList.length,
      itemBuilder: (context, index) {
        final artist = artistList[index];

        return Center(
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 20),

            leading: ValueListenableBuilder(
              valueListenable: artist.songListManager.sourceTypeNotifier,
              builder: (context, value, child) {
                final coverSong = artist.getCoverSong();
                return Hero(
                  tag: coverSong.id + artist.name,
                  transitionOnUserGestures: true,
                  child: CoverArtWidget(
                    size: 50,
                    borderRadius: 25,
                    song: coverSong,
                  ),
                );
              },
            ),
            title: Text(artist.name),
            trailing: Text(
              AppLocalizations.of(context).songCount(artist.totalCount),
            ),
            onTap: () {
              layersManager.pushDetail('artists', artist);
            },
          ),
        );
      },
    );
  }

  Widget pageGridView(List<Artist> artistList) {
    return ValueListenableBuilder(
      valueListenable: useLargePictureNotifier,
      builder: (context, useLargePicture, child) {
        int crossAxisCount;
        double coverArtWidth;
        final mobileWidth = MediaQuery.widthOf(context);

        if (useLargePicture) {
          crossAxisCount = (mobileWidth / 180).toInt();
          coverArtWidth = mobileWidth / crossAxisCount - 45;
        } else {
          crossAxisCount = (mobileWidth / 120).toInt();
          coverArtWidth = mobileWidth / crossAxisCount - 35;
        }
        double radius = coverArtWidth / 10;
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: useLargePicture ? 0.9 : 0.85,
          ),
          itemCount: artistList.length,
          itemBuilder: (context, index) {
            final artist = artistList[index];
            return Column(
              children: [
                GestureDetector(
                  child: ValueListenableBuilder(
                    valueListenable: artist.songListManager.sourceTypeNotifier,
                    builder: (context, value, child) {
                      final coverSong = artist.getCoverSong();
                      return Hero(
                        tag: coverSong.id + artist.name,
                        transitionOnUserGestures: true,
                        child: CoverArtWidget(
                          size: coverArtWidth,
                          borderRadius: radius,
                          song: coverSong,
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    layersManager.pushDetail('artists', artist);
                  },
                ),
                SizedBox(height: 5),
                SizedBox(
                  width: coverArtWidth - 20,
                  child: Column(
                    children: [
                      Text(
                        artist.name,
                        style: TextStyle(overflow: TextOverflow.ellipsis),
                      ),

                      Text(
                        AppLocalizations.of(
                          context,
                        ).songCount(artist.totalCount),
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
