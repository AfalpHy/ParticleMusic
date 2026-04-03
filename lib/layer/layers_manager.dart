import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/layer/artists_albums_layer.dart';
import 'package:particle_music/layer/folders_layer.dart';
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

class LayersManager {
  final List<Widget> layerStack = [];
  final List<String> sidebarHighlighLabelStack = [];

  bool get isEmpty => layerStack.isEmpty;

  List<Page> buildPages() {
    return layerStack.map((layer) {
      return MaterialPage(
        key: ValueKey(layer),
        child: Stack(
          fit: StackFit.expand,

          children: [
            ValueListenableBuilder(
              valueListenable: updateColorNotifier,
              builder: (context, value, child) {
                if (mainPageThemeNotifier.value != 0) {
                  return SizedBox.shrink();
                }
                return Container(
                  color: backgroundSong == null ? Colors.grey : null,
                  child: CoverArtWidget(song: _getBackgroundSong(layer)),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: updateColorNotifier,
              builder: (context, value, child) {
                if (mainPageThemeNotifier.value != 0) {
                  return SizedBox.shrink();
                }
                return ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: _getBackgroundSong(
                        layer,
                      )?.coverArtColor?.withAlpha(180),
                    ),
                  ),
                );
              },
            ),

            Material(color: pageBackgroundColor, child: layer),
          ],
        ),
      );
    }).toList();
  }

  void pushLayer(String label, {String? content}) {
    sidebarHighlighLabel.value = label;
    sidebarHighlighLabelStack.add(label);

    if (label == 'artists' && content == null) {
      layerStack.add(ArtistsAlbumsLayer(key: UniqueKey(), isArtist: true));
    } else if (label == 'albums' && content == null) {
      layerStack.add(ArtistsAlbumsLayer(key: UniqueKey(), isArtist: false));
    } else if (label == 'artists' && content != null) {
      layerStack.add(
        SingleArtistLayer(
          key: UniqueKey(),
          artist: artistsAlbumsManager.name2Artist[content]!,
        ),
      );
    } else if (label == 'albums' && content != null) {
      layerStack.add(
        SingleAlbumLayer(
          key: UniqueKey(),
          album: artistsAlbumsManager.name2Album[content]!,
        ),
      );
    } else if (label == 'folders' && content == null) {
      layerStack.add(FoldersLayer(key: UniqueKey()));
    } else if (label == 'folders' && content != null) {
      layerStack.add(
        SingleFolderLayer(
          key: UniqueKey(),
          folder: library.getFolderByPath(content),
        ),
      );
    } else if (label == 'songs') {
      layerStack.add(SongsLayer(key: UniqueKey()));
    } else if (label == 'ranking') {
      layerStack.add(RankingLayer(key: UniqueKey()));
    } else if (label == 'recently') {
      layerStack.add(RecentlyLayer(key: UniqueKey()));
    } else if (label == 'playlists') {
      layerStack.add(PlaylistsLayer(key: UniqueKey()));
    } else if (label[0] == '_') {
      layerStack.add(
        SinglePlaylistLayer(
          key: UniqueKey(),
          playlist: playlistsManager.getPlaylistByName(label.substring(1))!,
        ),
      );
    } else if (label == 'settings') {
      layerStack.add(SettingsLayer(key: UniqueKey()));
    } else if (label == 'licenses') {
      layerStack.add(LicenseLayer(key: UniqueKey()));
    }

    updateBackground();
  }

  void popLayer() {
    if (layerStack.length == 1) {
      return;
    }

    layerStack.removeLast();

    sidebarHighlighLabelStack.removeLast();

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
  }

  void removePlaylistLayer(Playlist playlist) {
    for (int i = layerStack.length - 1; i > 0; i--) {
      Widget tmp = layerStack[i];
      if (tmp is SinglePlaylistLayer && tmp.playlist == playlist) {
        layerStack.removeAt(i);
        sidebarHighlighLabelStack.removeAt(i);
      }
    }

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
  }

  void clear() {
    layerStack.clear();
    sidebarHighlighLabelStack.clear();
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
    if (isEmpty) {
      return;
    }

    if (mainPageThemeNotifier.value == 0) {
      Widget layer = layerStack.last;
      backgroundSong = _getBackgroundSong(layer);
      backgroundBaseColor = await computeCoverArtColor(backgroundSong);
      searchFieldColor = backgroundBaseColor.withAlpha(75);
      buttonColor = backgroundBaseColor.withAlpha(75);
      dividerColor = backgroundBaseColor;
      selectedItemColor = backgroundBaseColor.withAlpha(75);
    }
    updateColorNotifier.value++;
  }
}
