import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/dynamic_detail_route.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/about_layer.dart';
import 'package:sylvakru/layer/albums_layer.dart';
import 'package:sylvakru/layer/artists_layer.dart';
import 'package:sylvakru/layer/folders_layer.dart';
import 'package:sylvakru/layer/font_picker_layer.dart';
import 'package:sylvakru/layer/license_layer.dart';
import 'package:sylvakru/layer/playlists_layer.dart';
import 'package:sylvakru/layer/premium_layer.dart';
import 'package:sylvakru/layer/ranking_layer.dart';
import 'package:sylvakru/layer/recently_layer.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/layer/single_album_layer.dart';
import 'package:sylvakru/layer/single_artist_layer.dart';
import 'package:sylvakru/layer/single_folder_layer.dart';
import 'package:sylvakru/layer/single_playlist_layer.dart';
import 'package:sylvakru/layer/songs_layer.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

final layersManager = LayersManager();

class LayerInfo {
  MyPicture? backgroundPicture;
  Color backgroundCoverArtColor;
  final changeNotifier = ValueNotifier(0);
  LayerInfo(this.backgroundPicture, this.backgroundCoverArtColor);
}

class LayersManager {
  final Map<Widget, LayerInfo> layerInfoMap = {};

  // lable -> rootLayer
  final Map<String, Widget> rootLayerMap = {};
  // rootLayer -> rootPage
  final Map<Widget, Widget> rootPageMap = {};

  // root -> detail
  final Map<Widget, Widget?> detailWidgetMap = {};
  final Map<Widget, Widget> parentWidgetMap = {};

  Widget? topRootLayer;

  Widget? topRootPage;
  Widget? bottomRootPage;

  final backgroundChangeNotifier = ValueNotifier(0);
  final switchNotifier = ValueNotifier(0);

  Widget createPage(Widget layer) {
    final layerInfo = layerInfoMap.putIfAbsent(
      layer,
      () => LayerInfo(null, Colors.grey),
    );
    return Stack(
      key: GlobalKey(),
      fit: .expand,
      children: [
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != .vivid) {
              return SizedBox.shrink();
            }
            return ValueListenableBuilder(
              valueListenable: layerInfo.changeNotifier,
              builder: (context, value, child) {
                return CoverArtWidget(
                  picture: layerInfo.backgroundPicture,
                  color: layerInfo.backgroundCoverArtColor,
                );
              },
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            if (value != .vivid) {
              return SizedBox.shrink();
            }

            // ClipRect is important
            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: ValueListenableBuilder(
                  valueListenable: layerInfo.changeNotifier,
                  builder: (context, value, child) {
                    return Container(
                      color: layerInfo.backgroundCoverArtColor.withAlpha(180),
                    );
                  },
                ),
              ),
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
  }

  Widget getRootLayer(String label) {
    return rootLayerMap.putIfAbsent(label, () {
      if (label == 'artists') {
        return ArtistsLayer(key: GlobalKey());
      } else if (label == 'albums') {
        return AlbumsLayer(key: GlobalKey());
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
      } else {
        return SinglePlaylistLayer(
          key: GlobalKey(),
          playlist: playlistManager.getPlaylistByName(label.substring(1))!,
          isRoot: true,
        );
      }
    });
  }

  void switchRootLayer(String label) {
    Widget layer = getRootLayer(label);
    if (layer == topRootLayer) {
      return;
    }

    topRootLayer = layer;
    if (isMobile) {
      bottomRootPage = topRootPage;
      topRootPage = rootPageMap.putIfAbsent(
        topRootLayer!,
        () => createPage(topRootLayer!),
      );
    }

    sidebarHighlighLabel.value = label;
    switchNotifier.value++;
    updateBackground();
  }

  void removeLayerIfNeed(dynamic target) async {
    if (target is Playlist) {
      String key = '_${target.name}';
      final rootLayer = getRootLayer('playlists');
      if ((detailWidgetMap[rootLayer] as SinglePlaylistLayer?)?.playlist ==
          target) {
        popDetail('playlists');
      }
      final removedLayer = rootLayerMap.remove(key);
      if (removedLayer == topRootLayer) {
        switchRootLayer('songs');
      }
      // prevent black screen appear
      await Future.delayed(Duration(milliseconds: 500));
      rootPageMap.remove(removedLayer);
    } else if (target is Artist) {
      final rootLayer = getRootLayer('artists');
      if ((detailWidgetMap[rootLayer] as SingleArtistLayer?)?.artist ==
          target) {
        popDetail('artists');
      }
    } else if (target is Album) {
      final rootLayer = getRootLayer('albums');
      if ((detailWidgetMap[rootLayer] as SingleAlbumLayer?)?.album == target) {
        popDetail('albums');
      }
    } else if (target is Folder) {
      final rootLayer = getRootLayer('folders');
      if ((detailWidgetMap[rootLayer] as SingleFolderLayer?)?.folder ==
          target) {
        popDetail('folders');
      }
    } else {
      assert(false);
    }
  }

  void pushDetail(String label, dynamic detail) async {
    if (viewModeNotifier.value == .bigPicture) {
      return;
    }
    final rootLayer = getRootLayer(label);

    late GlobalKey<NavigatorState> rootKey;
    late ValueNotifier<bool> visibleNotifier;
    late Widget detailLayer;
    if (label == 'artists') {
      rootKey = artistsKey;
      visibleNotifier = artistsVisibleNotifier;
      detailLayer = SingleArtistLayer(artist: detail);
    } else if (label == 'albums') {
      rootKey = albumsKey;
      visibleNotifier = albumsVisibleNotifier;
      detailLayer = SingleAlbumLayer(album: detail);
    } else if (label == 'folders') {
      rootKey = foldersKey;
      visibleNotifier = foldersVisibleNotifier;
      detailLayer = SingleFolderLayer(folder: detail);
    } else if (label == 'ranking') {
      rootKey = rankingKey;
      visibleNotifier = rankingVisibleNotifier;
      detailLayer = SingleAlbumLayer(album: detail, rootLabel: 'ranking');
    } else if (label == 'recently') {
      rootKey = recentlyKey;
      visibleNotifier = recentlyVisibleNotifier;
      detailLayer = SingleAlbumLayer(album: detail, rootLabel: 'recently');
    } else if (label == 'playlists') {
      rootKey = playlistsKey;
      visibleNotifier = playlistsVisibleNotifier;
      detailLayer = SinglePlaylistLayer(playlist: detail, isRoot: false);
    } else {
      rootKey = settingsKey;
      visibleNotifier = settingsVisibleNotifier;
      if (detail == 'about') {
        detailLayer = AboutLayer();
      } else if (detail == 'license') {
        visibleNotifier = aboutVisibleNotifier;
        detailLayer = LicenseLayer();
      } else if (detail == 'premium') {
        detailLayer = PremiumLayer();
      } else {
        detailLayer = FontPickerLayer();
      }
    }
    if (detailWidgetMap[rootLayer] == null) {
      parentWidgetMap[detailLayer] = rootLayer;
    } else {
      parentWidgetMap[detailLayer] = detailWidgetMap[rootLayer]!;
    }
    detailWidgetMap[rootLayer] = detailLayer;

    await layersManager.updateBackground();

    final detailPage = createPage(detailLayer);
    rootKey.currentState?.push(
      DynamicDetailRoute(
        builder: (context) {
          if (isTooNarrow(context)) {
            return detailPage;
          }
          return detailLayer;
        },
        label: label,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      visibleNotifier.value = false;
    });
  }

  Future<bool> popDetail(String label, {bool executePop = true}) async {
    final rootLayer = getRootLayer(label);
    if (detailWidgetMap[rootLayer] == null) {
      return false;
    }

    final detailLayer = detailWidgetMap.remove(rootLayer);
    final parentLayer = parentWidgetMap.remove(detailLayer);

    late GlobalKey<NavigatorState> rootKey;
    late ValueNotifier<bool> visibleNotifier;
    if (label == 'artists') {
      rootKey = artistsKey;
      visibleNotifier = artistsVisibleNotifier;
    } else if (label == 'albums') {
      rootKey = albumsKey;
      visibleNotifier = albumsVisibleNotifier;
    } else if (label == 'ranking') {
      rootKey = rankingKey;
      visibleNotifier = rankingVisibleNotifier;
    } else if (label == 'recently') {
      rootKey = recentlyKey;
      visibleNotifier = recentlyVisibleNotifier;
    } else if (label == 'folders') {
      rootKey = foldersKey;
      visibleNotifier = foldersVisibleNotifier;
    } else if (label == 'playlists') {
      rootKey = playlistsKey;
      visibleNotifier = playlistsVisibleNotifier;
    } else {
      rootKey = settingsKey;
      visibleNotifier = settingsVisibleNotifier;
      if (detailLayer is LicenseLayer) {
        detailWidgetMap[rootLayer] = parentLayer;
        visibleNotifier = aboutVisibleNotifier;
      }
    }

    await layersManager.updateBackground();

    if ((rootKey.currentState?.canPop() ?? false) && executePop) {
      rootKey.currentState?.pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      visibleNotifier.value = true;
    });

    return true;
  }

  Future<void> pushDetailIfNeed(dynamic detail) async {
    if (detail is Artist) {
      if ((detailWidgetMap[getRootLayer('artists')] as SingleArtistLayer?)
              ?.artist !=
          detail) {
        await Future.delayed(Duration(milliseconds: 500));
        if (await popDetail('artists')) {
          await Future.delayed(Duration(milliseconds: 500));
        }
        pushDetail('artists', detail);
      }
    } else {
      if ((detailWidgetMap[getRootLayer('albums')] as SingleAlbumLayer?)
              ?.album !=
          detail) {
        await Future.delayed(Duration(milliseconds: 500));
        if (await popDetail('albums')) {
          await Future.delayed(Duration(milliseconds: 500));
        }

        pushDetail('albums', detail);
      }
    }
  }

  MyPicture? _getBackgroundPicture(Widget layer) {
    if (layer is SingleArtistLayer) {
      return layer.artist.picture;
    } else if (layer is SingleAlbumLayer) {
      return layer.album.picture;
    } else if (layer is SingleFolderLayer) {
      final songList = layer.folder.songList;
      return getFirstSong(songList)?.picture;
    } else if (layer is SongsLayer) {
      return getFirstSong(library.songList)?.picture;
    } else if (layer is RankingLayer && sourceType != .navidrome) {
      return getFirstSong(history.rankingSongList)?.picture;
    } else if (layer is RecentlyLayer && sourceType != .navidrome) {
      return getFirstSong(history.recentlySongList)?.picture;
    } else if (layer is SinglePlaylistLayer) {
      return layer.playlist.getCoverSong()?.picture;
    } else {
      return currentSongNotifier.value?.picture;
    }
  }

  void _updateLayerInfo(
    Widget layer,
    MyPicture? bgPicture,
    Color bgCoverArtColor,
  ) {
    final layerInfo = layerInfoMap.putIfAbsent(
      layer,
      () => LayerInfo(bgPicture, bgCoverArtColor),
    );
    if (layerInfo.backgroundPicture != bgPicture ||
        layerInfo.backgroundCoverArtColor != bgCoverArtColor) {
      layerInfo.backgroundPicture = bgPicture;
      layerInfo.backgroundCoverArtColor = bgCoverArtColor;
      layerInfo.changeNotifier.value++;
    }
  }

  Future<void> updateBackground() async {
    if (topRootLayer == null || viewModeNotifier.value == .bigPicture) {
      return;
    }

    Widget displayLayer = topRootLayer!;
    Widget? tmpLayer = detailWidgetMap[topRootLayer];
    if (tmpLayer != null) {
      displayLayer = tmpLayer;
      while ((tmpLayer = parentWidgetMap[tmpLayer]) != null) {
        final tmpBgPicture = _getBackgroundPicture(tmpLayer!);
        final tmpBgCoverArtColor = await computeColor(tmpBgPicture);
        _updateLayerInfo(tmpLayer, tmpBgPicture, tmpBgCoverArtColor);
      }
    }

    backgroundPicture = _getBackgroundPicture(displayLayer);
    backgroundCoverArtColor = await computeColor(backgroundPicture);
    _updateLayerInfo(displayLayer, backgroundPicture, backgroundCoverArtColor);

    if (mainPageThemeNotifier.value == .vivid) {
      searchFieldColor.updateColor();
      buttonColor.updateColor();
      dividerColor.updateColor();
      selectedItemColor.updateColor();
      backgroundChangeNotifier.value++;
    }
  }

  void perpareForSync() {
    popDetail('artists', executePop: false);
    popDetail('albums', executePop: false);
    popDetail('folders', executePop: false);
    popDetail('ranking', executePop: false);
    popDetail('recently', executePop: false);
    popDetail('playlists', executePop: false);

    layerInfoMap.removeWhere((k, v) => k != topRootLayer);
    rootLayerMap.removeWhere((k, v) => k != 'settings');
    rootPageMap.removeWhere((k, v) => k != topRootLayer);

    switchNotifier.value++;

    bottomRootPage = null;
  }
}
