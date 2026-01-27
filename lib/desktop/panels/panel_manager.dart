import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/artist_album_panel.dart';
import 'package:particle_music/desktop/panels/folders_panel.dart';
import 'package:particle_music/desktop/panels/ranking_panel.dart';
import 'package:particle_music/desktop/panels/playlists_panel.dart';
import 'package:particle_music/desktop/panels/recently_panel.dart';
import 'package:particle_music/desktop/panels/setting_panel.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/utils.dart';

class PanelManager {
  final List<Widget> panelStack = [];
  final List<String> sidebarHighlighLabelStack = [];

  final List<ValueNotifier<String>> currentFolderNotifierStack = [];

  final ValueNotifier<int> updatePanelNotifier = ValueNotifier(0);

  bool get isEmpty {
    return panelStack.isEmpty;
  }

  void pushPanel(String label, {String? content}) async {
    sidebarHighlighLabel.value = label;
    sidebarHighlighLabelStack.add(label);

    if (label == 'artists' && content != null) {
      backgroundSong = artist2SongList[content]!.first;
      panelStack.add(SongListPanel(key: UniqueKey(), artist: content));
    } else if (label == 'albums' && content != null) {
      backgroundSong = album2SongList[content]!.first;
      panelStack.add(SongListPanel(key: UniqueKey(), album: content));
    } else if (label == 'folders') {
      ValueNotifier<String> currentFolderNotifier = ValueNotifier('');
      currentFolderNotifierStack.add(currentFolderNotifier);
      if (folderPathList.isNotEmpty) {
        backgroundSong = getFirstSong(folder2SongList[folderPathList.first]!);
        currentFolderNotifier.value = folderPathList.first;
      } else {
        backgroundSong = null;
      }
      panelStack.add(
        FoldersPanel(
          key: UniqueKey(),
          currentFolderNotifier: currentFolderNotifier,
        ),
      );
    } else if (label == 'songs') {
      backgroundSong = getFirstSong(librarySongList);
      panelStack.add(SongListPanel(key: UniqueKey()));
    } else if (label == 'ranking') {
      backgroundSong = getFirstSong(historyManager.rankingSongList);
      panelStack.add(RankingRanel(key: UniqueKey()));
    } else if (label == 'recently') {
      backgroundSong = getFirstSong(historyManager.recentlySongList);
      panelStack.add(RecentlyPanel(key: UniqueKey()));
    } else if (label[0] == '_') {
      final playlist = playlistsManager.getPlaylistByName(label.substring(1));
      backgroundSong = getFirstSong(playlist!.songList);
      panelStack.add(SongListPanel(key: UniqueKey(), playlist: playlist));
    } else {
      backgroundSong = currentSongNotifier.value;
    }

    backgroundColor = await computeCoverArtColor(backgroundSong);

    if (label == 'artists' && content == null) {
      panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: true));
    } else if (label == 'albums' && content == null) {
      panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: false));
    } else if (label == 'playlists') {
      panelStack.add(PlaylistsPanel(key: UniqueKey()));
    } else if (label == 'settings') {
      panelStack.add(SettingPanel(key: UniqueKey()));
    } else if (label == 'licenses') {
      panelStack.add(LicensePagePanel(key: UniqueKey()));
    }

    updatePanelNotifier.value++;
    updateBackgroundNotifier.value++;
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

    updatePanelNotifier.value++;
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

    updatePanelNotifier.value++;
  }

  void reload() {
    panelStack.clear();
    sidebarHighlighLabelStack.clear();
  }

  void updateBackground() async {
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
      backgroundSong = getFirstSong(
        folder2SongList[currentFolderNotifierStack.last.value]!,
      );
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

    backgroundColor = await computeCoverArtColor(backgroundSong);
    updateBackgroundNotifier.value++;
  }
}
