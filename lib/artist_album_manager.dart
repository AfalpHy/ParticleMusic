import 'package:flutter/widgets.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';

ArtistAlbumManager artistAlbumManager = ArtistAlbumManager();

class ArtistAlbumManager {
  List<Artist> artistList = [];
  Map<String, Artist> name2Artist = {};

  List<Album> albumList = [];
  Map<String, Album> name2Album = {};

  final artistsIsListViewNotifier = ValueNotifier(true);
  final artistsIsAscendingNotifier = ValueNotifier(true);
  final artistsUseLargePictureNotifier = ValueNotifier(false);

  final albumsIsAscendingNotifier = ValueNotifier(true);
  final albumsUseLargePictureNotifier = ValueNotifier(false);

  List<ArtistAlbumBase> getArtistAlbumList(bool isArtist) {
    return isArtist ? artistList : albumList;
  }

  ValueNotifier<bool> getIsAscendingNotifier(bool isArtist) {
    return isArtist ? artistsIsAscendingNotifier : albumsIsAscendingNotifier;
  }

  ValueNotifier<bool> getUseLargePictureNotifier(bool isArtist) {
    return isArtist
        ? artistsUseLargePictureNotifier
        : albumsUseLargePictureNotifier;
  }

  void load() {
    for (final song in librarySongList) {
      _processSong(song);
    }

    for (final song in navidromeSongList) {
      _processSong(song);
    }

    artistList = name2Artist.values.toList();
    albumList = name2Album.values.toList();
    sortArtists();
    sortAlbums();

    for (final artist in artistList) {
      artist.displayNavidromeNotifier.value =
          artist.songList.isEmpty & artist.navidromeSongList.isNotEmpty;
    }

    for (final album in albumList) {
      album.sort();
      album.displayNavidromeNotifier.value =
          album.songList.isEmpty & album.navidromeSongList.isNotEmpty;
    }
  }

  void _processSong(MyAudioMetadata song) {
    for (String artistName in getArtist(song).split(RegExp(r'[/&,]'))) {
      late Artist artist;
      if (name2Artist[artistName] == null) {
        name2Artist[artistName] = Artist(artistName);
      }
      artist = name2Artist[artistName]!;
      song.isNavidrome
          ? artist.navidromeSongList.add(song)
          : artist.songList.add(song);
    }

    final albumName = getAlbum(song);

    late Album album;
    if (name2Album[albumName] == null) {
      name2Album[albumName] = Album(albumName);
    }
    album = name2Album[albumName]!;

    song.isNavidrome
        ? album.navidromeSongList.add(song)
        : album.songList.add(song);
  }

  void sortArtists() {
    artistList.sort((a, b) {
      if (artistsIsAscendingNotifier.value) {
        return compareMixed(a.name, b.name);
      } else {
        return compareMixed(b.name, a.name);
      }
    });
  }

  void sortAlbums() {
    albumList.sort((a, b) {
      if (albumsIsAscendingNotifier.value) {
        return compareMixed(a.name, b.name);
      } else {
        return compareMixed(b.name, a.name);
      }
    });
  }

  Map<String, bool> settingToMap() {
    return {
      'artistsIsList': artistsIsListViewNotifier.value,
      'artistsIsAscend': artistsIsAscendingNotifier.value,
      'artistsUseLargePicture': artistsUseLargePictureNotifier.value,

      'albumsIsAscend': albumsIsAscendingNotifier.value,
      'albumsUseLargePicture': albumsUseLargePictureNotifier.value,
    };
  }

  void loadSetting(Map<String, dynamic> json) {
    artistsIsListViewNotifier.value =
        json['artistsIsList'] as bool? ?? artistsIsListViewNotifier.value;

    artistsIsAscendingNotifier.value =
        json['artistsIsAscend'] as bool? ?? artistsIsAscendingNotifier.value;

    artistsUseLargePictureNotifier.value =
        json['artistsUseLargePicture'] as bool? ??
        artistsUseLargePictureNotifier.value;

    albumsIsAscendingNotifier.value =
        json['albumsIsAscend'] as bool? ?? albumsIsAscendingNotifier.value;

    albumsUseLargePictureNotifier.value =
        json['albumsUseLargePicture'] as bool? ??
        albumsUseLargePictureNotifier.value;
  }

  void clear() {
    artistList = [];
    name2Artist = {};
    albumList = [];
    name2Album = {};
  }
}

abstract class ArtistAlbumBase {
  final String name;
  final displayNavidromeNotifier = ValueNotifier(false);
  final List<MyAudioMetadata> songList = [];
  final List<MyAudioMetadata> navidromeSongList = [];

  final bool isArtist;
  ArtistAlbumBase(this.name, this.isArtist);

  List<MyAudioMetadata> getSongList(bool isNavidrome) {
    return isNavidrome ? navidromeSongList : songList;
  }

  MyAudioMetadata getDisplaySong() {
    return displayNavidromeNotifier.value
        ? navidromeSongList.first
        : songList.first;
  }

  int getTotalCount() {
    return songList.length + navidromeSongList.length;
  }
}

class Artist extends ArtistAlbumBase {
  Artist(String name) : super(name, true);
}

class Album extends ArtistAlbumBase {
  Album(String name) : super(name, false);

  int _sort(MyAudioMetadata a, MyAudioMetadata b) {
    final discA = a.disc ?? 9999;
    final discB = b.disc ?? 9999;

    final discCompare = discA.compareTo(discB);
    if (discCompare != 0) return discCompare;

    final trackA = a.track ?? 9999;
    final trackB = b.track ?? 9999;

    return trackA.compareTo(trackB);
  }

  void sort() {
    songList.sort((a, b) => _sort(a, b));
    // shoud add this to avoid using global, but it's weird
    this.navidromeSongList.sort((a, b) => _sort(a, b));
  }
}
