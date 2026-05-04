import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/layer/artists_albums_layer.dart';
import 'package:particle_music/layer/folders_layer.dart';
import 'package:particle_music/layer/license_layer.dart';
import 'package:particle_music/layer/playlists_layer.dart';
import 'package:particle_music/layer/ranking_layer.dart';
import 'package:particle_music/layer/recently_layer.dart';
import 'package:particle_music/layer/settings_layer.dart';
import 'package:particle_music/layer/single_album_layer.dart';
import 'package:particle_music/layer/single_artist_layer.dart';
import 'package:particle_music/layer/single_folder_layer.dart';
import 'package:particle_music/layer/single_playlist_layer.dart';
import 'package:particle_music/layer/songs_layer.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';

final layersManager = LayersManager();

class LayerInfo {
  MyAudioMetadata? backgroundSong;
  Color backgroundCoverArtColor;
  final changeNotifier = ValueNotifier(0);
  LayerInfo(this.backgroundSong, this.backgroundCoverArtColor);
}

enum SwitchType { push, pop, afterPop }

class LayersManager {
  final Map<String, Widget> layerMap = {};
  final Map<Widget, LayerInfo> layerInfoMap = {};
  final Map<Widget, Widget> pageMap = {};

  final List<Widget> layerHistory = [];
  final List<String> labelHistory = [];

  Widget? currentLayer;
  Widget? helperLayer;

  Widget? currentPage;
  Widget? helperPage;

  final backgroundChangeNotifier = ValueNotifier(0);
  final switchNotifier = ValueNotifier(0);
  late SwitchType switchType;

  Widget getPage(Widget layer) {
    return pageMap.putIfAbsent(layer, () {
      final layerInfo = layerInfoMap[layer]!;
      return Stack(
        key: GlobalKey(),

        children: [
          ValueListenableBuilder(
            valueListenable: layerInfo.changeNotifier,
            builder: (context, value, child) {
              return ValueListenableBuilder(
                valueListenable: mainPageThemeNotifier,
                builder: (context, value, child) {
                  if (value != 0) {
                    return SizedBox();
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverArtWidget(
                        song: layerInfo.backgroundSong,
                        color: layerInfo.backgroundCoverArtColor,
                      ),

                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            color: layerInfo.backgroundCoverArtColor.withAlpha(
                              180,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          ValueListenableBuilder(
            valueListenable: pageBackgroundColor.valueNotifier,
            builder: (context, value, child) {
              return Material(color: value, child: layer);
            },
          ),
        ],
      );
    });
  }

  Widget getLayer(String label, {String? content}) {
    final keyValue = label + (content ?? '');
    return layerMap.putIfAbsent(keyValue, () {
      if (content == null) {
        if (label == 'artists') {
          return ArtistsAlbumsLayer(key: GlobalKey(), isArtist: true);
        } else if (label == 'albums') {
          return ArtistsAlbumsLayer(key: GlobalKey(), isArtist: false);
        } else if (label == 'folders') {
          return FoldersLayer(key: GlobalKey());
        } else if (label == 'songs') {
          return SongsLayer(key: GlobalKey());
        } else if (label == 'ranking') {
          return RankingLayer(key: GlobalKey());
        } else if (label == 'recently') {
          return RecentlyLayer(key: GlobalKey());
        } else if (label == 'playlists') {
          return PlaylistsLayer(key: GlobalKey());
        } else if (label == 'settings') {
          return SettingsLayer(key: GlobalKey());
        } else if (label == 'license') {
          return LicenseLayer(key: GlobalKey());
        }
        return SinglePlaylistLayer(
          key: GlobalKey(),
          playlist: playlistsManager.getPlaylistByName(label.substring(1))!,
        );
      }
      if (label == 'artists') {
        return SingleArtistLayer(
          key: GlobalKey(),
          artist: artistsAlbumsManager.name2Artist[content]!,
        );
      } else if (label == 'albums') {
        return SingleAlbumLayer(
          key: GlobalKey(),
          album: artistsAlbumsManager.name2Album[content]!,
        );
      }
      return SingleFolderLayer(
        key: GlobalKey(),
        folder: library.getFolderById(content),
      );
    });
  }

  Future<void> pushLayer(String label, {String? content}) async {
    Widget layer = getLayer(label, content: content);
    if (layer == currentLayer) {
      return;
    }

    switchType = .push;

    helperLayer = currentLayer;
    currentLayer = layer;
    await updateBackground();
    if (isMobile) {
      helperPage = currentPage;
      currentPage = getPage(currentLayer!);
    }

    layerHistory.add(currentLayer!);
    labelHistory.add(label);

    sidebarHighlighLabel.value = label;
    switchNotifier.value++;
  }

  Future<void> popLayer() async {
    if (layerHistory.length == 1) {
      return;
    }
    switchType = .pop;

    layerHistory.removeLast();
    labelHistory.removeLast();
    helperLayer = currentLayer;
    currentLayer = layerHistory.last;
    await updateBackground();
    if (isMobile) {
      helperPage = currentPage;
      currentPage = pageMap[currentLayer];
    }
    sidebarHighlighLabel.value = labelHistory.last;
    switchNotifier.value++;
  }

  void afterPopLayer() {
    switchType = .afterPop;

    if (layerHistory.length >= 2) {
      helperLayer = layerHistory[layerHistory.length - 2];
      helperPage = pageMap[helperLayer];
    } else {
      helperLayer = null;
      helperPage = null;
    }
    switchNotifier.value++;
  }

  void removePlaylistLayer(Playlist playlist) async {
    final layer = layerMap.remove('_${playlist.name}');
    if (layer == currentLayer) {
      await popLayer();
    }

    // ensure pop complete
    await Future.delayed(Duration(milliseconds: 500));

    if (isMobile) {
      pageMap.remove(layer);
    }
    layerHistory.removeWhere((item) => item == layer);
    labelHistory.removeWhere((item) => item == '_${playlist.name}');
  }

  void removeArtistLayer(Artist artist) async {
    final layer = layerMap.remove('artists${artist.name}');
    if (layer == currentLayer) {
      await popLayer();
    }

    await Future.delayed(Duration(milliseconds: 500));

    if (isMobile) {
      pageMap.remove(layer);
    }
    layerHistory.removeWhere((item) => item == layer);
    labelHistory.removeWhere((item) => item == 'albums${artist.name}');
  }

  void removeAlbumLayer(Album album) async {
    final layer = layerMap.remove('albums${album.name}');
    if (layer == currentLayer) {
      await popLayer();
    }

    await Future.delayed(Duration(milliseconds: 500));

    if (isMobile) {
      pageMap.remove(layer);
    }
    layerHistory.removeWhere((item) => item == layer);
    labelHistory.removeWhere((item) => item == 'albums${album.name}');
  }

  void clear() {
    layerHistory.clear();
    labelHistory.clear();
    layerMap.clear();
    pageMap.clear();
    currentLayer = null;
    helperLayer = null;
    currentPage = null;
    helperPage = null;
  }

  MyAudioMetadata? _getBackgroundSong(Widget layer) {
    if (layer is SingleArtistLayer) {
      return layer.artist.getDisplaySong();
    } else if (layer is SingleAlbumLayer) {
      return layer.album.getDisplaySong();
    } else if (layer is SingleFolderLayer) {
      final songList = layer.folder.songList;
      return getFirstSong(songList);
    } else if (layer is SongsLayer) {
      bool isNavidrome = library.displayNavidromeNotifier.value;
      return getFirstSong(
        isNavidrome ? library.navidromeSongList : library.songList,
      );
    } else if (layer is RankingLayer) {
      bool isNavidrome = history.displayNavidromeRankingNotifier.value;
      return getFirstSong(history.getRankingSongList(isNavidrome));
    } else if (layer is RecentlyLayer) {
      bool isNavidrome = history.displayNavidromeRecentlyNotifier.value;
      return getFirstSong(history.getRecentlySongList(isNavidrome));
    } else if (layer is SinglePlaylistLayer) {
      return layer.playlist.getDisplaySong();
    } else {
      return currentSongNotifier.value;
    }
  }

  Future<void> updateBackground() async {
    if (currentLayer == null) {
      return;
    }

    backgroundSong = _getBackgroundSong(currentLayer!);
    backgroundCoverArtColor = await computeCoverArtColor(backgroundSong);

    final layerInfo = layerInfoMap.putIfAbsent(
      currentLayer!,
      () => LayerInfo(backgroundSong, backgroundCoverArtColor),
    );
    if (layerInfo.backgroundSong != backgroundSong ||
        layerInfo.backgroundCoverArtColor != backgroundCoverArtColor) {
      layerInfo.backgroundSong = backgroundSong;
      layerInfo.backgroundCoverArtColor = backgroundCoverArtColor;
      layerInfo.changeNotifier.value++;
    }

    if (mainPageThemeNotifier.value == 0) {
      searchFieldColor.updateColor();
      buttonColor.updateColor();
      dividerColor.updateColor();
      selectedItemColor.updateColor();
      backgroundChangeNotifier.value++;
    }
  }
}
