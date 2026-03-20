import 'package:flutter/material.dart';
import 'package:particle_music/artist_album_manager.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/mobile/pages/local_navidrome_pageview.dart';
import 'package:particle_music/mobile/my_search_field.dart';
import 'package:particle_music/mobile/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class AlbumsPage extends StatelessWidget {
  final ValueNotifier<List<Album>> currentAlbumListNotifier = ValueNotifier(
    artistAlbumManager.albumList,
  );

  final textController = TextEditingController();

  AlbumsPage({super.key});

  void updateCurrentAlbumList() {
    final value = textController.text;
    currentAlbumListNotifier.value = artistAlbumManager.albumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        iconTheme: IconThemeData(color: iconColor),
        backgroundColor: pageBackgroundColor,
        elevation: 0,
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
          Divider(thickness: 0.5, height: 1, color: dividerColor),

          ListTile(
            leading: ImageIcon(pictureImage, color: iconColor),
            title: Text(
              l10n.pictureSize,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: ValueListenableBuilder(
              valueListenable: artistAlbumManager.albumsUseLargePictureNotifier,
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
                          artistAlbumManager
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
            leading: ImageIcon(sequenceImage, color: iconColor),
            title: Text(
              l10n.order,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: ValueListenableBuilder(
              valueListenable: artistAlbumManager.albumsIsAscendingNotifier,
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
                          artistAlbumManager.albumsIsAscendingNotifier.value =
                              value;
                          settingManager.saveSetting();
                          artistAlbumManager.sortAlbums();
                          updateCurrentAlbumList();
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

  Widget gridView(List<Album> albumList) {
    return ValueListenableBuilder(
      valueListenable: artistAlbumManager.albumsUseLargePictureNotifier,
      builder: (context, useLargePicture, child) {
        double size = useLargePicture ? mobileWidth * 0.40 : mobileWidth * 0.25;
        double radius = useLargePicture
            ? mobileWidth * 0.025
            : mobileWidth * 0.015;
        double childAspectRatio = useLargePicture ? 0.85 : 0.8;
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: useLargePicture ? 2 : 3,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: albumList.length,
          itemBuilder: (context, index) {
            final album = albumList[index];

            return Column(
              children: [
                Material(
                  elevation: 1,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                  child: GestureDetector(
                    child: ValueListenableBuilder(
                      valueListenable: album.displayNavidromeNotifier,
                      builder: (context, value, child) {
                        return CoverArtWidget(
                          size: size,
                          borderRadius: radius,
                          song: album.getDisplaySong(),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LocalNavidromePageview(
                            displayNavidromeNotifier:
                                album.displayNavidromeNotifier,
                            localSongList: album.songList,
                            navidromeSongList: album.navidromeSongList,
                            album: album,
                          ),
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
                        album.name,
                        style: TextStyle(overflow: TextOverflow.ellipsis),
                      ),

                      Text(
                        AppLocalizations.of(
                          context,
                        ).songsCount(album.getTotalCount()),
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
