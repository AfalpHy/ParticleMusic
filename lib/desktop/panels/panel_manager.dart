import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/artist_album_panel.dart';
import 'package:particle_music/desktop/panels/folders_panel.dart';
import 'package:particle_music/desktop/panels/ranking_panel.dart';
import 'package:particle_music/desktop/panels/playlists_panel.dart';
import 'package:particle_music/desktop/panels/recently_panel.dart';
import 'package:particle_music/desktop/panels/setting_panel.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';

class PanelManager {
  final List<Widget> panelStack = [];
  final List<String> sidebarHighlighLabelStack = [];

  final List<ValueNotifier<Folder>> currentFolderNotifierStack = [];

  bool get isEmpty => panelStack.isEmpty;

  void pushPanel(String label, {String? content}) {
    sidebarHighlighLabel.value = label;
    sidebarHighlighLabelStack.add(label);

    if (label == 'artists' && content == null) {
      panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: true));
    } else if (label == 'albums' && content == null) {
      panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: false));
    } else if (label == 'artists' && content != null) {
      panelStack.add(SongListPanel(key: UniqueKey(), artist: content));
    } else if (label == 'albums' && content != null) {
      panelStack.add(SongListPanel(key: UniqueKey(), album: content));
    } else if (label == 'folders') {
      final currentFolderNotifier = ValueNotifier(
        folderManager.folderList.first,
      );
      currentFolderNotifierStack.add(currentFolderNotifier);

      panelStack.add(
        FoldersPanel(
          key: UniqueKey(),
          currentFolderNotifier: currentFolderNotifier,
        ),
      );
    } else if (label == 'songs') {
      panelStack.add(SongListPanel(key: UniqueKey()));
    } else if (label == 'ranking') {
      panelStack.add(RankingRanel(key: UniqueKey()));
    } else if (label == 'recently') {
      panelStack.add(RecentlyPanel(key: UniqueKey()));
    } else if (label == 'playlists') {
      panelStack.add(PlaylistsPanel(key: UniqueKey()));
    } else if (label[0] == '_') {
      final playlist = playlistsManager.getPlaylistByName(label.substring(1));
      panelStack.add(SongListPanel(key: UniqueKey(), playlist: playlist));
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
    if (sidebarHighlighLabelStack.last == 'folders') {
      currentFolderNotifierStack.removeLast();
    }
    sidebarHighlighLabelStack.removeLast();

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updateBackground();
  }

  void removePlaylistPanel(Playlist playlist) {
    for (int i = panelStack.length - 1; i > 0; i--) {
      Widget tmp = panelStack[i];
      if (tmp is SongListPanel && tmp.playlist == playlist) {
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
    currentFolderNotifierStack.clear();
  }

  Future<void> updateBackground() async {
    if (isEmpty) {
      return;
    }
    final label = sidebarHighlighLabelStack.last;

    Widget panel = panelStack.last;

    if (label == 'artists' && panel is SongListPanel) {
      backgroundSong = artist2SongList[panel.artist]!.first;
    } else if (label == 'albums' && panel is SongListPanel) {
      backgroundSong = album2SongList[panel.album]!.first;
    } else if (label == 'folders') {
      final songList = currentFolderNotifierStack.last.value.songList;
      backgroundSong = getFirstSong(songList);
    } else if (label == 'songs') {
      backgroundSong = getFirstSong(librarySongList);
    } else if (label == 'ranking') {
      backgroundSong = getFirstSong(historyManager.rankingSongList);
    } else if (label == 'recently') {
      backgroundSong = getFirstSong(historyManager.recentlySongList);
    } else if (label[0] == '_') {
      final playlist = playlistsManager.getPlaylistByName(label.substring(1));
      backgroundSong = getFirstSong(playlist!.songList);
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
