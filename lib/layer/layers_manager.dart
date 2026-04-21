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

class LayerHelper {
  MyAudioMetadata? backgroundSong;
  Color backgroundCoverArtColor;
  final changeNotifier = ValueNotifier(0);
  LayerHelper(this.backgroundSong, this.backgroundCoverArtColor);
}

class LayersManager {
  final Map<String, Widget> layerMap = {};
  final Map<Widget, LayerHelper> layerHelperMap = {};
  final Map<Widget, Widget> pageMap = {};

  Widget? currentLayer;
  Widget? preLayer;

  Widget? currentPage;
  Widget? prePage;

  final backgroundChangeNotifier = ValueNotifier(0);
  final switchNotifier = ValueNotifier(0);

  Widget getPage(Widget layer) {
    return pageMap.putIfAbsent(layer, () {
      final layerHelper = layerHelperMap[layer]!;
      return Stack(
        key: GlobalKey(),

        children: [
          ValueListenableBuilder(
            valueListenable: layerHelper.changeNotifier,
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
                        song: layerHelper.backgroundSong,
                        color: layerHelper.backgroundCoverArtColor,
                      ),

                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            color: layerHelper.backgroundCoverArtColor
                                .withAlpha(180),
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

  Future<void> switchLayer(String label, {String? content}) async {
    sidebarHighlighLabel.value = label;

    Widget layer = getLayer(label, content: content);
    if (layer == currentLayer) {
      return;
    }

    preLayer = currentLayer;
    currentLayer = layer;
    await updateBackground();
    if (isMobile) {
      prePage = currentPage;
      currentPage = getPage(currentLayer!);
    }

    switchNotifier.value++;
  }

  void removePlaylistLayer(Playlist playlist) {
    final layer = layerMap.remove('_${playlist.name}');
    if (isMobile) {
      pageMap.remove(layer);
    }
    if (layer == currentLayer) {
      switchLayer('playlists');
    }
  }

  void removeArtistLayer(Artist artist) {
    final layer = layerMap.remove('artists${artist.name}');
    if (isMobile) {
      pageMap.remove(layer);
    }
    if (layer == currentLayer) {
      switchLayer('artists');
    }
  }

  void removeAlbumLayer(Album album) {
    final layer = layerMap.remove('albums${album.name}');
    if (isMobile) {
      pageMap.remove(layer);
    }
    if (layer == currentLayer) {
      switchLayer('albums');
    }
  }

  void clear() {
    layerMap.clear();
    pageMap.clear();
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

    final layerHelper = layerHelperMap.putIfAbsent(
      currentLayer!,
      () => LayerHelper(backgroundSong, backgroundCoverArtColor),
    );
    if (layerHelper.backgroundSong != backgroundSong ||
        layerHelper.backgroundCoverArtColor != backgroundCoverArtColor) {
      layerHelper.backgroundSong = backgroundSong;
      layerHelper.backgroundCoverArtColor = backgroundCoverArtColor;
      layerHelper.changeNotifier.value++;
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
