import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/pages/main_page.dart';
import 'package:particle_music/desktop/panels/artist_album_panel.dart';
import 'package:particle_music/desktop/panels/folders_panel.dart';
import 'package:particle_music/desktop/panels/ranking_panel.dart';
import 'package:particle_music/desktop/panels/playlists_panel.dart';
import 'package:particle_music/desktop/panels/recently_panel.dart';
import 'package:particle_music/desktop/panels/setting_panel.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/history.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/playlists.dart';

class PanelManager {
  final List<Widget> panelStack = [];
  final List<String> sidebarHighlighLabelStack = [];
  final List<AudioMetadata?> backgroundSongStack = [];
  final List<bool> bgColorUseCurrentSongStack = [];

  final ValueNotifier<int> updatePanel = ValueNotifier(0);

  bool get isEmpty {
    return panelStack.isEmpty;
  }

  void pushPanel(String label, {String? content}) {
    sidebarHighlighLabel.value = label;
    sidebarHighlighLabelStack.add(label);

    bool bgColorUseCurrentSong = false;
    if (label == 'artists' && content != null) {
      backgroundSong = artist2SongList[content]!.first;
      panelStack.add(SongListPanel(key: UniqueKey(), artist: content));
    } else if (label == 'albums' && content != null) {
      backgroundSong = album2SongList[content]!.first;
      panelStack.add(SongListPanel(key: UniqueKey(), album: content));
    } else if (label == 'folders') {
      if (folderPathList.isNotEmpty) {
        backgroundSong = getFirstSong(folder2SongList[folderPathList.first]!);
      } else {
        backgroundSong = null;
      }
      panelStack.add(FoldersPanel(key: UniqueKey()));
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
      bgColorUseCurrentSong = true;
    }

    backgroundColor = computeCoverArtColor(backgroundSong);

    backgroundSongStack.add(backgroundSong);
    bgColorUseCurrentSongStack.add(bgColorUseCurrentSong);

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

    updatePanel.value++;
    updateBackgroundNotifier.value++;
  }

  void popPanel() {
    if (panelStack.length == 1) {
      return;
    }
    panelStack.removeLast();
    sidebarHighlighLabelStack.removeLast();
    backgroundSongStack.removeLast();
    bgColorUseCurrentSongStack.removeLast();

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updatePanel.value++;

    updateBackground();
  }

  void removePlaylistPanel(Playlist playlist) {
    for (int i = panelStack.length - 1; i > 0; i--) {
      Widget tmp = panelStack[i];
      if (tmp is SongListPanel && tmp.playlist == playlist) {
        panelStack.removeAt(i);
        sidebarHighlighLabelStack.removeAt(i);
        backgroundSongStack.removeAt(i);
        bgColorUseCurrentSongStack.removeAt(i);
      }
    }

    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;

    updatePanel.value++;

    updateBackground();
  }

  void reload() {
    panelStack.clear();
    sidebarHighlighLabelStack.clear();
    backgroundSongStack.clear();
  }

  void updateBackground() {
    backgroundSong = backgroundSongStack.last;
    backgroundColor = computeCoverArtColor(backgroundSong);
    updateBackgroundNotifier.value++;
  }
}

PanelManager panelManager = PanelManager();
