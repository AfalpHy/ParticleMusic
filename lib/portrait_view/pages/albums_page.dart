import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_divider.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';
import 'package:particle_music/portrait_view/my_search_field.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/utils.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<StatefulWidget> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  final ValueNotifier<List<Album>> currentAlbumListNotifier = ValueNotifier(
    artistsAlbumsManager.albumList,
  );

  final textController = TextEditingController();
  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    updateCurrentAlbumList();
    artistsAlbumsManager.updateNotifier.addListener(updateCurrentAlbumList);
  }

  @override
  void dispose() {
    artistsAlbumsManager.updateNotifier.removeListener(updateCurrentAlbumList);
    super.dispose();
  }

  void updateCurrentAlbumList() {
    final value = textController.text;
    currentAlbumListNotifier.value = artistsAlbumsManager.albumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();

    if (artistsAlbumsManager.albumsRandomizeNotifier.value) {
      currentAlbumListNotifier.value.shuffle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(l10n.albums),
        centerTitle: true,
        actions: [searchField(l10n.searchAlbums), moreButton(context)],
      ),
      body: ValueListenableBuilder(
        valueListenable: currentAlbumListNotifier,
        builder: (context, list, child) {
          return gridView(list);
        },
      ),
    );
  }

  Widget searchField(String hintText) {
    return MySearchField(
      hintText: hintText,
      textController: textController,
      onSearchTextChanged: updateCurrentAlbumList,
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
      Column(
        children: [
          ListTile(title: Text(l10n.settings)),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),

          ListTile(
            leading: ImageIcon(pictureImage),
            title: Text(
              l10n.pictureSize,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: ValueListenableBuilder(
              valueListenable:
                  artistsAlbumsManager.albumsUseLargePictureNotifier,
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
                          artistsAlbumsManager
                                  .albumsUseLargePictureNotifier
                                  .value =
                              value;
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
            leading: ImageIcon(sequenceImage),
            title: Text(
              l10n.order,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: ValueListenableBuilder(
              valueListenable: artistsAlbumsManager.albumsRandomizeNotifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 120,

                  child: Row(
                    children: [
                      Spacer(),
                      Text(value ? l10n.randomize : l10n.normal),
                      SizedBox(width: 10),
                      MySwitch(
                        value: value,
                        onToggle: (value) async {
                          tryVibrate();
                          artistsAlbumsManager.albumsRandomizeNotifier.value =
                              value;
                          updateCurrentAlbumList();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          ValueListenableBuilder(
            valueListenable: artistsAlbumsManager.albumsRandomizeNotifier,
            builder: (_, randomize, _) {
              if (randomize) {
                return SizedBox();
              }
              return ListTile(
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                trailing: ValueListenableBuilder(
                  valueListenable:
                      artistsAlbumsManager.albumsIsAscendingNotifier,
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
                              artistsAlbumsManager
                                      .albumsIsAscendingNotifier
                                      .value =
                                  value;
                              settingManager.saveSetting();
                              artistsAlbumsManager.sortAlbums();
                              updateCurrentAlbumList();
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
        ],
      ),
    );
  }

  Widget gridView(List<Album> albumList) {
    return ValueListenableBuilder(
      valueListenable: artistsAlbumsManager.albumsUseLargePictureNotifier,
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
        double radius = useLargePicture ? 10 : 6;
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
                    valueListenable: album.displayNavidromeNotifier,
                    builder: (context, value, child) {
                      return CoverArtWidget(
                        size: coverArtWidth,
                        borderRadius: radius,
                        song: album.getDisplaySong(),
                      );
                    },
                  ),
                  onTap: () {
                    layersManager.pushLayer('albums', content: album.name);
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
                        ).songCount(album.getTotalCount()),
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
