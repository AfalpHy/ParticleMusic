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

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<StatefulWidget> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  final ValueNotifier<List<Artist>> currentArtistListNotifier = ValueNotifier(
    artistsAlbumsManager.artistList,
  );

  final textController = TextEditingController();
  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    updateCurrentArtistList();
    artistsAlbumsManager.updateNotifier.addListener(updateCurrentArtistList);
  }

  @override
  void dispose() {
    artistsAlbumsManager.updateNotifier.removeListener(updateCurrentArtistList);
    super.dispose();
  }

  void updateCurrentArtistList() {
    final value = textController.text;
    currentArtistListNotifier.value = artistsAlbumsManager.artistList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (artistsAlbumsManager.artistsRandomizeNotifier.value) {
      currentArtistListNotifier.value.shuffle();
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
            leading: ValueListenableBuilder(
              valueListenable: artistsAlbumsManager.artistsIsListViewNotifier,
              builder: (context, value, child) {
                return ImageIcon(value ? listImage : gridImage);
              },
            ),
            title: Text(
              l10n.view,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: SizedBox(
              width: 100,
              child: Row(
                children: [
                  Spacer(),

                  MySwitch(
                    trueText: l10n.list,
                    falseText: l10n.grid,
                    valueNotifier:
                        artistsAlbumsManager.artistsIsListViewNotifier,
                    onToggleCallBack: () {
                      settingManager.saveSetting();
                    },
                  ),
                ],
              ),
            ),
          ),

          ValueListenableBuilder(
            valueListenable: artistsAlbumsManager.artistsIsListViewNotifier,
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
                trailing: SizedBox(
                  width: 100,

                  child: Row(
                    children: [
                      Spacer(),
                      MySwitch(
                        trueText: l10n.large,
                        falseText: l10n.small,
                        valueNotifier:
                            artistsAlbumsManager.artistsUseLargePictureNotifier,
                        onToggleCallBack: () {
                          settingManager.saveSetting();
                        },
                      ),
                    ],
                  ),
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
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            trailing: SizedBox(
              width: 120,

              child: Row(
                children: [
                  Spacer(),
                  MySwitch(
                    trueText: l10n.randomize,
                    falseText: l10n.normal,
                    valueNotifier:
                        artistsAlbumsManager.artistsRandomizeNotifier,
                    onToggleCallBack: () {
                      updateCurrentArtistList();
                    },
                  ),
                ],
              ),
            ),
          ),

          ValueListenableBuilder(
            valueListenable: artistsAlbumsManager.artistsRandomizeNotifier,
            builder: (_, randomize, _) {
              if (randomize) {
                return SizedBox();
              }
              return ListTile(
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                trailing: SizedBox(
                  width: 120,

                  child: Row(
                    children: [
                      Spacer(),
                      MySwitch(
                        trueText: l10n.ascending,
                        falseText: l10n.descending,
                        valueNotifier:
                            artistsAlbumsManager.artistsIsAscendingNotifier,
                        onToggleCallBack: () {
                          settingManager.saveSetting();
                          artistsAlbumsManager.sortArtists();
                          updateCurrentArtistList();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
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
          itemCount: artistList.length,
          itemBuilder: (context, index) {
            final artist = artistList[index];
            return Column(
              children: [
                GestureDetector(
                  child: ValueListenableBuilder(
                    valueListenable: artist.displayNavidromeNotifier,
                    builder: (context, value, child) {
                      return CoverArtWidget(
                        size: coverArtWidth,
                        borderRadius: radius,
                        song: artist.getDisplaySong(),
                      );
                    },
                  ),
                  onTap: () {
                    layersManager.pushLayer('artists', content: artist.name);
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
