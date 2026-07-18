import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/song_list_manager.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';

final History history = History();

class History {
  SongListManager rankingSongListManager = SongListManager();
  SongListManager recentlySongListManager = SongListManager();

  void _fetchSongs(
    List<MyAudioMetadata> fromSongList,
    List<MyAudioMetadata> toRankingSongList,
    List<MyAudioMetadata> toRecentlySongList,
  ) {
    for (final song in fromSongList) {
      if (song.playCount > 0 && song.lastPlayed != null) {
        toRankingSongList.add(song);
        toRecentlySongList.add(song);
      }
    }
    toRankingSongList.sort((a, b) {
      int tmp = b.playCount.compareTo(a.playCount);
      return tmp != 0 ? tmp : a.lastPlayed!.compareTo(b.lastPlayed!);
    });

    toRecentlySongList.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
  }

  void load() {
    for (final sourceType in SourceType.values) {
      _fetchSongs(
        library.songListManager.getSongList2(sourceType),
        rankingSongListManager.getSongList2(sourceType),
        recentlySongListManager.getSongList2(sourceType),
      );
    }

    rankingSongListManager.resetSourceType();
    recentlySongListManager.resetSourceType();
  }

  void _addSongTimes(MyAudioMetadata song, int times) {
    final currentRankingSongList = rankingSongListManager.getSongList2(
      song.sourceType,
    );
    int index = -1;
    for (int i = 0; i < currentRankingSongList.length; i++) {
      if (song == currentRankingSongList[i]) {
        currentRankingSongList[i].playCount += times;
        index = i;
        break;
      }
    }

    if (index == -1) {
      song.playCount = times;
      currentRankingSongList.add(song);
      index = currentRankingSongList.length - 1;
    }

    final tmp = currentRankingSongList[index];
    for (int i = index - 1; i >= 0; i--) {
      if (currentRankingSongList[i].playCount < tmp.playCount) {
        currentRankingSongList[i + 1] = currentRankingSongList[i];
        index = i;
      } else {
        break;
      }
    }
    currentRankingSongList[index] = tmp;
  }

  Future<void> addSongTimes(MyAudioMetadata song, int times) async {
    _addSongTimes(song, times);

    if (song.sourceType == .navidrome) {
      while (times-- > 0) {
        await navidromeClient!.scrobble(song.id);
      }
    }

    song.lastPlayed = DateTime.now();
    await library.updatePlayCount(song);

    rankingSongListManager.getChangeNotifier2(song.sourceType).value++;
    rankingSongListManager.resetSourceType();

    _add2Recently(song);

    layersManager.updateBackground();
  }

  void _add2Recently(MyAudioMetadata song) {
    final songList = recentlySongListManager.getSongList2(song.sourceType);
    songList.remove(song);
    songList.insert(0, song);
    recentlySongListManager.getChangeNotifier2(song.sourceType).value++;
    recentlySongListManager.resetSourceType();
  }

  void clear() {
    rankingSongListManager.clear();
    recentlySongListManager.clear();
  }

  void prepareForSync(SourceType sourceType) {
    rankingSongListManager.prepareForSync(sourceType);
    recentlySongListManager.prepareForSync(sourceType);
  }

  void sync(SourceType sourceType) {
    _fetchSongs(
      library.songListManager.getSongList2(sourceType),
      rankingSongListManager.getSongList2(sourceType),
      recentlySongListManager.getSongList2(sourceType),
    );

    rankingSongListManager.getChangeNotifier2(sourceType).value++;
    rankingSongListManager.resetSourceType();

    recentlySongListManager.getChangeNotifier2(sourceType).value++;
    recentlySongListManager.resetSourceType();
  }
}
