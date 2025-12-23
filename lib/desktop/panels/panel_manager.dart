import 'package:flutter/material.dart';
import 'package:particle_music/desktop/panels/artist_album_panel.dart';
import 'package:particle_music/desktop/panels/folders_panel.dart';
import 'package:particle_music/desktop/panels/playlists_panel.dart';
import 'package:particle_music/desktop/panels/setting_panel.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/desktop/panels/song_list_panel.dart';
import 'package:particle_music/playlists.dart';

class PanelManager {
  final List<Widget> panelStack = [SongListPanel()];
  final List<String> sidebarHighlighLabelStack = ['_songs'];

  final ValueNotifier<int> updatePanel = ValueNotifier(0);

  void pushPanel(int index, {String? title}) {
    switch (index) {
      case -4:
        panelStack.add(FoldersPanel(key: UniqueKey()));
        sidebarHighlighLabel.value = '_folders';
        break;
      case -3:
        panelStack.add(PlaylistsPanel(key: UniqueKey()));
        sidebarHighlighLabel.value = '_playlists';
        break;
      case -2:
        panelStack.add(LicensePagePanel(key: UniqueKey()));
        sidebarHighlighLabel.value = '';
        break;
      case -1:
        panelStack.add(SettingPanel(key: UniqueKey()));
        sidebarHighlighLabel.value = '';
        break;
      case 0:
        panelStack.add(SongListPanel(key: UniqueKey()));
        sidebarHighlighLabel.value = '_songs';
        break;
      case 1:
        panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: true));
        sidebarHighlighLabel.value = '_artists';
        break;
      case 2:
        panelStack.add(ArtistAlbumPanel(key: UniqueKey(), isArtist: false));
        sidebarHighlighLabel.value = '_albums';
        break;
      case 3:
        panelStack.add(SongListPanel(key: UniqueKey(), artist: title));
        break;
      case 4:
        panelStack.add(SongListPanel(key: UniqueKey(), album: title));
        break;
      default:
        final playlist = playlistsManager.getPlaylistByIndex(index - 5);
        panelStack.add(SongListPanel(key: UniqueKey(), playlist: playlist));
        sidebarHighlighLabel.value = '__${playlist.name}';
        break;
    }
    sidebarHighlighLabelStack.add(sidebarHighlighLabel.value);
    updatePanel.value++;
  }

  void popPanel() {
    if (panelStack.length == 1) {
      return;
    }
    panelStack.removeLast();
    sidebarHighlighLabelStack.removeLast();
    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;
    updatePanel.value++;
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
    updatePanel.value++;
  }

  void reload() {
    panelStack.clear();
    sidebarHighlighLabelStack.clear();

    pushPanel(0);
    pushPanel(-1);
  }
}

PanelManager panelManager = PanelManager();
