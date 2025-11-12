import 'package:flutter/material.dart';
import 'package:particle_music/desktop/planes/artist_album_plane.dart';
import 'package:particle_music/desktop/planes/folders_plane.dart';
import 'package:particle_music/desktop/planes/playlists_plane.dart';
import 'package:particle_music/desktop/planes/setting_plane.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/desktop/planes/song_list_plane.dart';
import 'package:particle_music/playlists.dart';

class PlaneManager {
  final List<Widget> planeStack = [SongListPlane()];
  final List<String> sidebarHighlighLabelStack = ['_songs'];

  final ValueNotifier<int> updatePlane = ValueNotifier(0);

  void pushPlane(int index, {String? title}) {
    switch (index) {
      case -4:
        planeStack.add(FoldersPlane(key: UniqueKey()));
        sidebarHighlighLabel.value = '_folders';
        break;
      case -3:
        planeStack.add(PlaylistsPlane(key: UniqueKey()));
        sidebarHighlighLabel.value = '_playlists';
        break;
      case -2:
        planeStack.add(LicensePagePlane(key: UniqueKey()));
        sidebarHighlighLabel.value = '';
        break;
      case -1:
        planeStack.add(SettingPlane(key: UniqueKey()));
        sidebarHighlighLabel.value = '';
        break;
      case 0:
        planeStack.add(SongListPlane(key: UniqueKey()));
        sidebarHighlighLabel.value = '_songs';
        break;
      case 1:
        planeStack.add(ArtistAlbumPlane(key: UniqueKey(), isArtist: true));
        sidebarHighlighLabel.value = '_artists';
        break;
      case 2:
        planeStack.add(ArtistAlbumPlane(key: UniqueKey(), isArtist: false));
        sidebarHighlighLabel.value = '_albums';
        break;
      case 3:
        planeStack.add(SongListPlane(key: UniqueKey(), artist: title));
        break;
      case 4:
        planeStack.add(SongListPlane(key: UniqueKey(), album: title));
        break;
      default:
        final playlist = playlistsManager.getPlaylistByIndex(index - 5);
        planeStack.add(SongListPlane(key: UniqueKey(), playlist: playlist));
        sidebarHighlighLabel.value = '__${playlist.name}';
        break;
    }
    sidebarHighlighLabelStack.add(sidebarHighlighLabel.value);
    updatePlane.value++;
  }

  void popPlane() {
    if (planeStack.length == 1) {
      return;
    }
    planeStack.removeLast();
    sidebarHighlighLabelStack.removeLast();
    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;
    updatePlane.value++;
  }

  void removePlaylistPlane(Playlist playlist) {
    for (int i = planeStack.length - 1; i > 0; i--) {
      Widget tmp = planeStack[i];
      if (tmp is SongListPlane && tmp.playlist == playlist) {
        planeStack.removeAt(i);
        sidebarHighlighLabelStack.removeAt(i);
      }
    }
    sidebarHighlighLabel.value = sidebarHighlighLabelStack.last;
    updatePlane.value++;
  }

  void reload() {
    planeStack.clear();
    sidebarHighlighLabelStack.clear();

    pushPlane(0);
    pushPlane(-1);
  }
}

PlaneManager planeManager = PlaneManager();
