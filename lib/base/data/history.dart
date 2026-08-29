import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

final History history = History();

class History {
  final List<MyAudioMetadata> rankingSongList = [];
  final List<MyAudioMetadata> recentlySongList = [];
  final rankingChangeNotifier = ValueNotifier(0);
  final recentlyChangeNotifier = ValueNotifier(0);

  final List<Album> rankingAlbumList = [];
  final List<Album> recentlyAlbumList = [];

  void load() {
    for (final song in library.songList) {
      if (song.playCount > 0 && song.lastPlayed != null) {
        rankingSongList.add(song);
        recentlySongList.add(song);
      }
    }
    rankingSongList.sort((a, b) {
      int tmp = b.playCount.compareTo(a.playCount);
      return tmp != 0 ? tmp : a.lastPlayed!.compareTo(b.lastPlayed!);
    });

    recentlySongList.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));

    rankingChangeNotifier.value++;
    recentlyChangeNotifier.value++;
  }

  void _addSongTimes(MyAudioMetadata song, int times) {
    int index = rankingSongList.indexOf(song);

    song.playCount += times;

    if (index == -1) {
      rankingSongList.add(song);
      index = rankingSongList.length - 1;
    }

    for (int i = index - 1; i >= 0; i--) {
      if (rankingSongList[i].playCount < song.playCount) {
        rankingSongList[i + 1] = rankingSongList[i];
        index = i;
      } else {
        break;
      }
    }
    rankingSongList[index] = song;
    rankingChangeNotifier.value++;
  }

  Future<void> addSongTimes(MyAudioMetadata song, int times) async {
    _addSongTimes(song, times);

    if (song.sourceType == .navidrome) {
      while (times-- > 0) {
        await navidromeClient!.scrobble(song.id);
      }
    }

    song.lastPlayed = DateTime.now();
    if (isNotStreamSource) {
      await library.updatePlayCount(song);
    }

    _add2Recently(song);

    layersManager.updateBackground();
  }

  void _add2Recently(MyAudioMetadata song) {
    recentlySongList.remove(song);
    recentlySongList.insert(0, song);
    recentlyChangeNotifier.value++;
  }

  void clear() {
    rankingSongList.clear();
    recentlySongList.clear();
    rankingAlbumList.clear();
    recentlyAlbumList.clear();
    rankingChangeNotifier.value++;
    recentlyChangeNotifier.value++;
  }
}
