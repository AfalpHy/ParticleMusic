import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
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

class LayersManager {
  final List<Widget> layerStack = [];
  final List<String> sidebarHighlighLabelStack = [];

  final updateNotifier = ValueNotifier(0);

  bool get isEmpty => layerStack.isEmpty;

  List<Page> buildPages() {
    return [
      // ensure Navigator can pop
      if (Platform.isAndroid) const MaterialPage(child: SizedBox.shrink()),
      ...layerStack.map((layer) {
        final currentBgSong = _getBackgroundSong(layer);
        return MaterialPage(
          key: ValueKey(layer),
          child: Stack(
            fit: StackFit.expand,

            children: [
              if (mainPageThemeNotifier.value == 0) ...[
                CoverArtWidget(
                  song: currentBgSong,
                  color: currentBgSong == null
                      ? Colors.grey
                      : currentBgSong.coverArtColor,
                ),

                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: currentBgSong == null
                          ? Colors.grey.withAlpha(180)
                          : currentBgSong.coverArtColor?.withAlpha(180),
                    ),
                  ),
                ),
              ],

              Material(color: pageBackgroundColor, child: layer),
            ],
          ),
        );
      }),
    ];
  }

  Future<void> pushLayer(String label, {String? content}) async {
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
          folder: library.getFolderById(content),
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

    await updateBackground();
    updateNotifier.value++;
  }

  void popLayer() {
    if (layerStack.length == 1) {
      return;
    }

    layerStack.removeLast();

    sidebarHighlighLabelStack.removeLast();

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
    updateNotifier.value++;
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
    updateNotifier.value++;
  }

  void removeArtistLayer(Artist artist) {
    for (int i = layerStack.length - 1; i > 0; i--) {
      Widget tmp = layerStack[i];
      if (tmp is SingleArtistLayer && tmp.artist == artist) {
        layerStack.removeAt(i);
        sidebarHighlighLabelStack.removeAt(i);
      }
    }

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
    updateNotifier.value++;
  }

  void removeAlbumLayer(Album album) {
    for (int i = layerStack.length - 1; i > 0; i--) {
      Widget tmp = layerStack[i];
      if (tmp is SingleAlbumLayer && tmp.album == album) {
        layerStack.removeAt(i);
        sidebarHighlighLabelStack.removeAt(i);
      }
    }

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
    updateNotifier.value++;
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
    final tmpBackgroundSong = backgroundSong;
    backgroundSong = _getBackgroundSong(layerStack.last);
    final tmpBgCoverArtColor = backgroundCoverArtColor;
    backgroundCoverArtColor = await computeCoverArtColor(backgroundSong);
    if (tmpBackgroundSong == backgroundSong &&
        tmpBgCoverArtColor == backgroundCoverArtColor) {
      return;
    }
    if (mainPageThemeNotifier.value == 0) {
      backgroundBaseColor = backgroundCoverArtColor;
      final tmpColor =
          backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
      searchFieldColor = tmpColor.withAlpha(75);
      buttonColor = tmpColor.withAlpha(75);
      dividerColor = tmpColor;
      selectedItemColor = tmpColor.withAlpha(75);
      updateColorNotifier.value++;
    }
  }
}
