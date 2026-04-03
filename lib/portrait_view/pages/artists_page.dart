import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/my_search_field.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ArtistsPage extends StatelessWidget {
  final ValueNotifier<List<Artist>> currentArtistListNotifier = ValueNotifier(
    artistsAlbumsManager.artistList,
  );

  final textController = TextEditingController();

  ArtistsPage({super.key});

  void updateCurrentArtistList() {
    final value = textController.text;
    currentArtistListNotifier.value = artistsAlbumsManager.artistList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,

        scrolledUnderElevation: 0,
        title: Text(l10n.artists),
        centerTitle: true,
        actions: [searchField(l10n.searchArtists), moreButton(context)],
      ),
      body: ValueListenableBuilder(
        valueListenable: artistsAlbumsManager.artistsIsListViewNotifier,
        builder: (context, isListView, child) {
          return ValueListenableBuilder(
            valueListenable: currentArtistListNotifier,
            builder: (context, list, child) {
              return isListView ? listView(list) : gridView(list);
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
      onSearchTextChanged: updateCurrentArtistList,
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
            leading: ValueListenableBuilder(
              valueListenable: artistsAlbumsManager.artistsIsListViewNotifier,
              builder: (context, value, child) {
                return ImageIcon(
                  value ? listImage : gridImage,
                  color: iconColor,
                );
              },
            ),
            title: Text(
              l10n.view,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              artistsAlbumsManager.artistsIsListViewNotifier.value = true;
            },
            trailing: ValueListenableBuilder(
              valueListenable: artistsAlbumsManager.artistsIsListViewNotifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Spacer(),
                      Text(value ? l10n.list : l10n.grid),
                      SizedBox(width: 10),
                      MySwitch(
                        value: value,
                        onToggle: (value) async {
                          tryVibrate();
                          artistsAlbumsManager.artistsIsListViewNotifier.value =
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

          ValueListenableBuilder(
            valueListenable: artistsAlbumsManager.artistsIsListViewNotifier,
            builder: (context, value, child) {
              if (value) {
                return SizedBox.shrink();
              }
              return ListTile(
                leading: ImageIcon(pictureImage, color: iconColor),
                title: Text(
                  l10n.pictureSize,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: ValueListenableBuilder(
                  valueListenable:
                      artistsAlbumsManager.artistsUseLargePictureNotifier,
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
                                      .artistsUseLargePictureNotifier
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
              );
            },
          ),

          ListTile(
            leading: ImageIcon(sequenceImage, color: iconColor),
            title: Text(
              l10n.order,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: ValueListenableBuilder(
              valueListenable: artistsAlbumsManager.artistsIsAscendingNotifier,
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
                                  .artistsIsAscendingNotifier
                                  .value =
                              value;
                          settingManager.saveSetting();
                          artistsAlbumsManager.sortArtists();
                          updateCurrentArtistList();
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
              valueListenable: artist.displayNavidromeNotifier,
              builder: (context, value, child) {
                return CoverArtWidget(
                  size: 50,
                  borderRadius: 25,
                  song: artist.getDisplaySong(),
                );
              },
            ),
            title: Text(artist.name),
            trailing: Text(
              AppLocalizations.of(context).songCount(artist.getTotalCount()),
            ),
            onTap: () {
              layersManager.pushLayer('artists', content: artist.name);
            },
          ),
        );
      },
    );
  }

  Widget gridView(List<Artist> artistList) {
    return ValueListenableBuilder(
      valueListenable: artistsAlbumsManager.artistsUseLargePictureNotifier,
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
          itemCount: artistList.length,
          itemBuilder: (context, index) {
            final artist = artistList[index];
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
                      valueListenable: artist.displayNavidromeNotifier,
                      builder: (context, value, child) {
                        return CoverArtWidget(
                          size: size,
                          borderRadius: radius,
                          song: artist.getDisplaySong(),
                        );
                      },
                    ),
                    onTap: () {
                      layersManager.pushLayer('artists', content: artist.name);
                    },
                  ),
                ),
                SizedBox(height: 5),
                SizedBox(
                  width: size - 20,
                  child: Column(
                    children: [
                      Text(
                        artist.name,
                        style: TextStyle(overflow: TextOverflow.ellipsis),
                      ),

                      Text(
                        AppLocalizations.of(
                          context,
                        ).songCount(artist.getTotalCount()),
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
