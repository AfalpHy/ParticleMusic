import 'package:flutter/material.dart';
import 'package:particle_music/desktop/artist_album_plane.dart';
import 'package:particle_music/desktop/song_list_plane.dart';
import 'package:particle_music/playlists.dart';

class PlaneManager {
  final List<Widget> planeStack = [SongListPlane()];

  final ValueNotifier<int> updatePlane = ValueNotifier(0);

  void pushPlane(int index, {String? title}) {
    switch (index) {
      case 0:
        planeStack.add(SongListPlane(key: UniqueKey()));
        break;
      case 1:
        planeStack.add(
          ArtistAlbumPlane(
            key: UniqueKey(),
            isArtist: true,
            switchPlane: (title) {
              pushPlane(3, title: title);
            },
          ),
        );
        break;
      case 2:
        planeStack.add(
          ArtistAlbumPlane(
            key: UniqueKey(),
            isArtist: false,
            switchPlane: (title) {
              pushPlane(4, title: title);
            },
          ),
        );
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
        break;
    }
    updatePlane.value++;
  }

  void popPlane() {
    if (planeStack.length == 1) {
      return;
    }
    planeStack.removeLast();
    updatePlane.value++;
  }

  void removePlaylistPlane(Playlist playlist) {
    for (int i = planeStack.length - 1; i > 0; i--) {
      Widget tmp = planeStack[i];
      if (tmp is SongListPlane && tmp.playlist == playlist) {
        planeStack.removeAt(i);
      }
    }
    updatePlane.value++;
  }
}

PlaneManager planeManager = PlaneManager();
