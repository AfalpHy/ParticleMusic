import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

final artistAlbumManager = ArtistAlbumManager();

class ArtistAlbumManager {
  List<Artist> artistList = [];
  Map<String, Artist> name2Artist = {};

  List<Album> albumList = [];
  Map<String, Album> name2Album = {};
  final updateNotifier = ValueNotifier(0);

  final artistsIsListViewNotifier = ValueNotifier(true);
  final artistsIsAscendingNotifier = ValueNotifier(true);
  final artistsUseLargePictureNotifier = ValueNotifier(false);
  final artistsRandomizeNotifier = ValueNotifier(false);

  final albumsIsAscendingNotifier = ValueNotifier(true);
  final albumsUseLargePictureNotifier = ValueNotifier(false);
  final albumsRandomizeNotifier = ValueNotifier(false);

  List<ArtistAlbumBase> getArtistAlbumList(bool isArtist) {
    return isArtist ? artistList : albumList;
  }

  ValueNotifier<bool> getIsRandomizeNotifier(bool isArtist) {
    return isArtist ? artistsRandomizeNotifier : albumsRandomizeNotifier;
  }

  ValueNotifier<bool> getIsAscendingNotifier(bool isArtist) {
    return isArtist ? artistsIsAscendingNotifier : albumsIsAscendingNotifier;
  }

  ValueNotifier<bool> getUseLargePictureNotifier(bool isArtist) {
    return isArtist
        ? artistsUseLargePictureNotifier
        : albumsUseLargePictureNotifier;
  }

  void classify() {
    for (final sourceType in SourceType.values) {
      for (final song in library.songListManager.getSongList2(sourceType)) {
        _processSong(song);
      }
    }

    sortArtists();
    sortAlbums();

    for (final album in albumList) {
      album.sort();
      album.songListManager.resetSourceType();
    }

    for (final artist in artistList) {
      artist.combineAlbums();
      artist.songListManager.resetSourceType();
    }

    updateNotifier.value++;
  }

  void _processSong(MyAudioMetadata song) {
    final albumName = getAlbum(song);

    Album? album = name2Album[albumName];
    if (album == null) {
      album = Album(albumName);
      albumList.add(album);
      name2Album[albumName] = album;
    }

    if (song.year != null && album.year == null) {
      album.year = song.year;
    }

    album.songListManager.getSongList2(song.sourceType).add(song);

    for (String artistName in getArtists(getArtist(song))) {
      Artist? artist = name2Artist[artistName];
      if (artist == null) {
        artist = Artist(artistName);
        artistList.add(artist);
        name2Artist[artistName] = artist;
      }
      artist.albumSet.add(album);
    }
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

  void updateArtistAlbum(
    MyAudioMetadata song,
    String originArtist,
    String originAlbum,
  ) {
    final currentArtist = getArtist(song);
    final currentAlbum = getAlbum(song);

    final oldAlbum = name2Album[originAlbum]!;
    oldAlbum.songListManager.localSongList.remove(song);

    _processSong(song);

    oldAlbum.sort();
    oldAlbum.songListManager.localChangeNotifier.value++;

    oldAlbum.songListManager.resetSourceType();

    if (currentAlbum != originAlbum) {
      if (oldAlbum.isEmpty) {
        albumList.remove(oldAlbum);
        name2Album.remove(originAlbum);
        layersManager.removeLayerIfNeed(oldAlbum);
      }
      final newAlbum = name2Album[currentAlbum]!;
      newAlbum.sort();
      newAlbum.songListManager.localChangeNotifier.value++;
      newAlbum.songListManager.resetSourceType();
    }

    sortAlbums();

    Set<Artist> needProcess = {};

    for (String artistName in getArtists(originArtist)) {
      Artist artist = name2Artist[artistName]!;
      needProcess.add(artist);
    }

    for (String artistName in getArtists(currentArtist)) {
      Artist artist = name2Artist[artistName]!;
      needProcess.add(artist);
    }

    for (final artist in needProcess) {
      artist.combineAlbums();
      artist.songListManager.localChangeNotifier.value++;

      if (artist.songListManager.getSongList().isEmpty) {
        artist.songListManager.resetSourceType();
      }

      if (artist.isEmpty) {
        artistList.remove(artist);
        name2Artist.remove(artist.name);
        layersManager.removeLayerIfNeed(artist);
      }
    }

    sortArtists();

    updateNotifier.value++;
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
    updateNotifier.value++;
  }
}

abstract class ArtistAlbumBase {
  final String name;

  SongListManager songListManager = SongListManager();

  final bool isArtist;
  ArtistAlbumBase(this.name, this.isArtist);

  bool get isEmpty => songListManager.isEmpty;

  MyAudioMetadata getCoverSong() {
    return songListManager.getSongList().first;
  }

  int get totalCount => songListManager.totalCount;
}

class Artist extends ArtistAlbumBase {
  Artist(String name) : super(name, true);

  Set<Album> albumSet = {};

  void _fetchSongs(
    List<MyAudioMetadata> fromSongList,
    List<MyAudioMetadata> toSongList,
  ) {
    for (final song in fromSongList) {
      for (String artistName in getArtists(getArtist(song))) {
        if (artistName == name) {
          toSongList.add(song);
          break;
        }
      }
    }
  }

  void combineAlbums() {
    songListManager.clear();
    albumSet.removeWhere((album) => album.isEmpty);
    final albumList = albumSet.toList();
    albumList.sort((a, b) {
      int aYear = a.year ?? 9999;
      int bYear = b.year ?? 9999;

      return aYear.compareTo(bYear);
    });

    for (final album in albumList) {
      for (final sourceType in SourceType.values) {
        _fetchSongs(
          album.songListManager.getSongList2(sourceType),
          songListManager.getSongList2(sourceType),
        );
      }
    }
  }
}

class Album extends ArtistAlbumBase {
  Album(String name) : super(name, false);

  int? year;

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
    for (final sourceType in SourceType.values) {
      songListManager.getSongList2(sourceType).sort(_sort);
    }
  }
}

void showArtistEntries(BuildContext context, List<String> artists) {
  showAnimationDialog(
    context: context,
    child: SizedBox(
      width: 300,
      height: 350,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
        child: ListView.builder(
          itemCount: artists.length,
          itemExtent: 60,
          itemBuilder: (context, index) {
            String name = artists[index];
            return Center(
              child: ListTile(
                leading: CoverArtWidget(
                  size: 50,
                  borderRadius: 5,
                  song: artistAlbumManager.name2Artist[name]!.getCoverSong(),
                ),
                title: Text(name),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  layersManager.switchRootLayer('artists');
                  layersManager.pushDetailIfNeed(
                    artistAlbumManager.name2Artist[name],
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
  );
}
