import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/artist_album_panel.dart';
import 'package:particle_music/desktop/panels/folder_panel.dart';
import 'package:particle_music/desktop/panels/ranking_panel.dart';
import 'package:particle_music/desktop/panels/playlists_panel.dart';
import 'package:particle_music/desktop/panels/recently_panel.dart';
import 'package:particle_music/desktop/panels/setting_panel.dart';
import 'package:particle_music/desktop/panels/single_album_panel.dart';
import 'package:particle_music/desktop/panels/single_artist_panel.dart';
import 'package:particle_music/desktop/panels/single_playlist_panel.dart';
import 'package:particle_music/desktop/panels/songs_panel.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';

class PanelManager {
  final List<Widget> panelStack = [];
  final List<String> sidebarHighlighLabelStack = [];

  bool get isEmpty => panelStack.isEmpty;

  void pushPanel(String label, {String? content}) {
    sidebarHighlighLabel.value = label;
    sidebarHighlighLabelStack.add(label);

    if (label == 'artists' && content == null) {
      panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: true));
    } else if (label == 'albums' && content == null) {
      panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: false));
    } else if (label == 'artists' && content != null) {
      panelStack.add(SingleArtistPanel(key: UniqueKey(), artist: content));
    } else if (label == 'albums' && content != null) {
      panelStack.add(SingleAlbumPanel(key: UniqueKey(), album: content));
    } else if (label == 'folder') {
      panelStack.add(
        FolderPanel(
          key: UniqueKey(),
          folder: content == null
              ? folderManager.folderList.first
              : folderManager.getFolderByPath(content),
        ),
      );
    } else if (label == 'songs') {
      panelStack.add(SongsPanel(key: UniqueKey()));
    } else if (label == 'ranking') {
      panelStack.add(RankingRanel(key: UniqueKey()));
    } else if (label == 'recently') {
      panelStack.add(RecentlyPanel(key: UniqueKey()));
    } else if (label == 'playlists') {
      panelStack.add(PlaylistsPanel(key: UniqueKey()));
    } else if (label[0] == '_') {
      panelStack.add(
        SinglePlaylistPanel(
          key: UniqueKey(),
          playlist: playlistsManager.getPlaylistByName(label.substring(1))!,
        ),
      );
    } else if (label == 'settings') {
      panelStack.add(SettingPanel(key: UniqueKey()));
    } else if (label == 'licenses') {
      panelStack.add(LicensePagePanel(key: UniqueKey()));
    }

    updateBackground();
  }

  void popPanel() {
    if (panelStack.length == 1) {
      return;
    }

    panelStack.removeLast();

    sidebarHighlighLabelStack.removeLast();

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
  }

  void removePlaylistPanel(Playlist playlist) {
    for (int i = panelStack.length - 1; i > 0; i--) {
      Widget tmp = panelStack[i];
      if (tmp is SinglePlaylistPanel && tmp.playlist == playlist) {
        panelStack.removeAt(i);
        sidebarHighlighLabelStack.removeAt(i);
      }
    }

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
  }

  void clear() {
    panelStack.clear();
    sidebarHighlighLabelStack.clear();
  }

  Future<void> updateBackground() async {
    if (isEmpty) {
      return;
    }
    final label = sidebarHighlighLabelStack.last;

    Widget panel = panelStack.last;

    if (label == 'artists' && panel is SingleArtistPanel) {
      backgroundSong = artist2SongList[panel.artist]!.first;
    } else if (label == 'albums' && panel is SingleAlbumPanel) {
      backgroundSong = album2SongList[panel.album]!.first;
    } else if (label == 'folder') {
      final songList = (panel as FolderPanel).folder.songList;
      backgroundSong = getFirstSong(songList);
    } else if (label == 'songs') {
      bool isNavidrome = displayNavidromeSongsNotifier.value;
      backgroundSong = getFirstSong(
        isNavidrome ? navidromeSongList : librarySongList,
      );
    } else if (label == 'ranking') {
      backgroundSong = getFirstSong(historyManager.rankingSongList);
    } else if (label == 'recently') {
      backgroundSong = getFirstSong(historyManager.recentlySongList);
    } else if (label[0] == '_') {
      final playlist = playlistsManager.getPlaylistByName(label.substring(1));
      bool isNavidrome = playlist!.displayNavidromeNotifier.value;
      backgroundSong = getFirstSong(
        isNavidrome ? playlist.navidromeSongList : playlist.songList,
      );
    } else {
      backgroundSong = currentSongNotifier.value;
    }

    backgroundFilterColor = await computeCoverArtColor(backgroundSong);
    if (!enableCustomColorNotifier.value && !darkModeNotifier.value) {
      searchFieldColor = backgroundFilterColor.withAlpha(75);
      buttonColor = backgroundFilterColor.withAlpha(75);
      dividerColor = backgroundFilterColor;
      selectedItemColor = backgroundFilterColor.withAlpha(75);
    }
    updateColorNotifier.value++;
  }
}
