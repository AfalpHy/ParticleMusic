part of '../../layer/albums_layer.dart';

extension _AlbumsPage on _AlbumsLayerState {
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
        title: Text(l10n.albums),
        centerTitle: true,
        actions: [searchField(l10n.searchAlbums), moreButton(context)],
      ),
      body: ValueListenableBuilder(
        valueListenable: currentAlbumListNotifier,
        builder: (context, list, child) {
          return pageGridView(list);
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
                          artistAlbumManager.sortAlbums();
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

  Widget pageGridView(List<Album> albumList) {
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
          itemCount: albumList.length,
          itemBuilder: (context, index) {
            final album = albumList[index];
            return Column(
              children: [
                GestureDetector(
                  child: ValueListenableBuilder(
                    valueListenable: album.songListManager.sourceTypeNotifier,
                    builder: (context, value, child) {
                      final coverSong = album.getCoverSong();
                      return Hero(
                        tag: coverSong.id + album.name,
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
                    layersManager.pushDetail('albums', album);
                  },
                ),
                SizedBox(height: 5),
                SizedBox(
                  width: coverArtWidth - 20,
                  child: Column(
                    children: [
                      Text(
                        album.name,
                        style: TextStyle(overflow: TextOverflow.ellipsis),
                      ),

                      Text(
                        AppLocalizations.of(
                          context,
                        ).songCount(album.totalCount),
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
