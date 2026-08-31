import 'dart:async';

import 'package:lpinyin/lpinyin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

ArtistAlbumManager artistAlbumManager = ArtistAlbumManager();

class ArtistAlbumManager {
  List<Artist> artistList = [];
  Map<String, Artist> artistMap = {};

  List<Album> albumList = [];
  // streamSoure will has duplicate name album
  Map<String, Album> albumMap = {};
  final updateNotifier = ValueNotifier(0);

  final artistsIsListViewNotifier = ValueNotifier(true);
  final artistsIsAscendingNotifier = ValueNotifier(true);
  final artistsUseLargePictureNotifier = ValueNotifier(false);
  final artistsRandomizeNotifier = ValueNotifier(false);

  final albumsIsAscendingNotifier = ValueNotifier(true);
  final albumsUseLargePictureNotifier = ValueNotifier(false);
  final albumsRandomizeNotifier = ValueNotifier(false);

  ArtistAlbumManager() {
    artistsIsAscendingNotifier.addListener(() {
      sortArtists();
      updateNotifier.value++;
    });
    albumsIsAscendingNotifier.addListener(() {
      sortAlbums();
      updateNotifier.value++;
    });
  }

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
    sortArtists();
    sortAlbums();

    for (final album in albumList) {
      album.sort();
    }

    for (final artist in artistList) {
      artist.combineAlbums();
    }

    updateNotifier.value++;
  }

  void processSong(MyAudioMetadata song) {
    final albumName = getAlbum(song);

    Album? album = albumMap[albumName];
    if (album == null) {
      album = Album(albumName);
      albumList.add(album);
      albumMap[albumName] = album;
    }

    if (song.year != null && album.year == null) {
      album.year = song.year;
    }

    album.songList.add(song);

    for (String artistName in getArtists(getArtist(song))) {
      Artist? artist = artistMap[artistName];
      if (artist == null) {
        artist = Artist(artistName);
        artistList.add(artist);
        artistMap[artistName] = artist;
      }
      artist.albumSet.add(album);
    }
  }

  void sortArtists() {
    artistList.sort((a, b) {
      if (artistsIsAscendingNotifier.value) {
        return a.compareName.compareTo(b.compareName);
      } else {
        return b.compareName.compareTo(a.compareName);
      }
    });
  }

  void sortAlbums() {
    albumList.sort((a, b) {
      if (albumsIsAscendingNotifier.value) {
        return a.compareName.compareTo(b.compareName);
      } else {
        return b.compareName.compareTo(a.compareName);
      }
    });
  }

  void updateArtistAlbum(
    MyAudioMetadata song,
    String originArtist,
    String originAlbum,
  ) {
    // TODO
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

  // use completer to avoid loading same data multiple times
  Completer<void>? artistCompleter;
  Completer<int?>? ablumCompleter;

  Future<void> loadArtists() async {
    if (artistCompleter == null) {
      artistCompleter = Completer<void>();
      final tmpArtistList = await streamClient!.getArtistList();
      if (tmpArtistList == null) {
        artistCompleter!.complete();
        return;
      }

      for (final artist in tmpArtistList) {
        artistList.add(artist);
        artistMap[artist.name] = artist;
      }
      sortArtists();
      artistAlbumManager.updateNotifier.value++;
      artistCompleter!.complete();
      return;
    }
    return artistCompleter!.future;
  }

  // null: error; 0: end
  Future<int?> loadAlbums() async {
    if (ablumCompleter == null) {
      ablumCompleter = Completer<int?>();
      final albumList = await streamClient!.getAlbumList(
        artistAlbumManager.albumList.length,
      );
      if (albumList == null) {
        ablumCompleter!.complete(null);
        ablumCompleter = null;
        return null;
      }

      artistAlbumManager.albumList.addAll(albumList);
      sortAlbums();
      artistAlbumManager.updateNotifier.value++;

      ablumCompleter!.complete(albumList.length);
      ablumCompleter = null;
      return albumList.length;
    }
    return ablumCompleter!.future;
  }
}

abstract class ArtistAlbumBase {
  String? id;
  final String name;
  late final String compareName;

  final List<MyAudioMetadata> songList = [];

  final bool isArtist;

  MyPicture? _picture;
  MyPicture get picture => isStreamSource ? _picture! : getCoverSong().picture;

  ArtistAlbumBase(this.name, this.isArtist, {this.id, String? coverArtId}) {
    id ??= name;
    compareName = PinyinHelper.getPinyinE(name);
    if (isStreamSource) {
      _picture = MyPicture(coverArtId ?? '');
    }
  }

  bool get isEmpty => songList.isEmpty;

  MyAudioMetadata getCoverSong() {
    return songList.first;
  }

  int get totalCount => songList.length;

  Completer<void>? completer;

  Future<void> load();
}

class Artist extends ArtistAlbumBase {
  Artist(String name, {super.id, super.coverArtId}) : super(name, false);

  Set<Album> albumSet = {};

  List<Album> albumList = [];

  final changeNotifier = ValueNotifier(0);

  void combineAlbums() {
    albumSet.removeWhere((album) => album.isEmpty);
    albumList = albumSet.toList();
    albumList.sort((a, b) {
      int aYear = a.year ?? 9999;
      int bYear = b.year ?? 9999;

      return aYear.compareTo(bYear);
    });

    for (final album in albumList) {
      songList.addAll(album.artist2SongList[name]!);
    }
  }

  @override
  Future<void> load() async {
    if (completer == null) {
      completer = Completer<void>();
      if (sourceType == .navidrome) {
        final albums = await streamClient!.getArtistAlbumList(id!);
        if (albums == null) {
          completer!.complete();
          return;
        } else {
          albumList.addAll(albums);
        }

        for (final album in albumList) {
          await album.load();
          songList.addAll(album.songList);
          changeNotifier.value++;
        }
        completer!.complete();
        return;
      } else {
        songList.addAll(await streamClient!.getArtistSongs(id!) ?? []);
        changeNotifier.value++;
        completer!.complete();
        return;
      }
    }
    return completer!.future;
  }
}

class Album extends ArtistAlbumBase {
  Album(String name, {super.id, super.coverArtId}) : super(name, false);

  Map<String, List<MyAudioMetadata>> artist2SongList = {};
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
    songList.sort((a, b) => _sort(a, b));
    for (final song in songList) {
      for (String artistName in getArtists(getArtist(song))) {
        final tmp = artist2SongList.putIfAbsent(artistName, () => []);
        tmp.add(song);
      }
    }
  }

  @override
  Future<void> load() async {
    if (completer == null) {
      // ensure load one time
      completer = Completer<void>();
      songList.addAll(await streamClient?.getAlbumSongs(id!) ?? []);
      completer!.complete();
      return;
    }
    return completer!.future;
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
                  picture: artistAlbumManager.artistMap[name]!.picture,
                ),
                title: Text(name),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  layersManager.switchRootLayer('artists');
                  layersManager.pushDetailIfNeed(
                    artistAlbumManager.artistMap[name],
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
