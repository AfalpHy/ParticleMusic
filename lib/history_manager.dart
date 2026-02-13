import 'dart:convert';
import 'dart:io';

import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';

class RankingItem {
  int times;
  String path;
  MyAudioMetadata song;
  RankingItem(this.times, this.path, this.song);

  Map<String, dynamic> toMap() {
    return {'times': times, 'path': path};
  }

  factory RankingItem.fromSong(MyAudioMetadata song, int times) {
    return RankingItem(times, clipFilePathIfNeed(song.filePath), song);
  }
}

class HistoryManager {
  late File rankingFile;
  late File recentlyFile;

  List<RankingItem> rankingItemList = [];
  List<MyAudioMetadata> rankingSongList = [];

  List<String> recentlyPathList = [];
  List<MyAudioMetadata> recentlySongList = [];

  Future<void> load() async {
    rankingFile = File("${appSupportDir.path}/ranking.txt");
    if (rankingFile.existsSync()) {
      String content = rankingFile.readAsStringSync();
      List<dynamic> jsonList = jsonDecode(content);

      rankingItemList = jsonList
          .map((e) => createRankingItem(e as Map<String, dynamic>))
          .whereType<RankingItem>()
          .toList();

      rankingSongList = rankingItemList.map((e) => e.song).toList();
    } else {
      rankingFile.writeAsStringSync(jsonEncode([]));
    }

    recentlyFile = File("${appSupportDir.path}/recently.txt");
    if (recentlyFile.existsSync()) {
      String content = recentlyFile.readAsStringSync();
      List<dynamic> jsonList = jsonDecode(content);

      for (String filePath in jsonList) {
        MyAudioMetadata? song = filePath2LibrarySong[filePath];
        if (song != null) {
          recentlyPathList.add(filePath);
          recentlySongList.add(song);
        }
      }
    } else {
      recentlyFile.writeAsStringSync(jsonEncode([]));
    }
  }

  RankingItem? createRankingItem(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    String path = map['path'] as String;
    MyAudioMetadata? song = filePath2LibrarySong[path];
    if (song != null) {
      return RankingItem(map['times'] as int, path, song);
    }
    return null;
  }

  void addSongTimes(MyAudioMetadata song, int times) {
    bool exist = false;
    for (int i = 0; i < rankingItemList.length; i++) {
      if (song == rankingItemList[i].song) {
        rankingItemList[i].times += times;
        exist = true;
        break;
      }
    }

    if (!exist) {
      rankingItemList.add(RankingItem.fromSong(song, times));
    }

    rankingItemList.sort((a, b) => b.times.compareTo(a.times));

    rankingFile.writeAsStringSync(
      jsonEncode(rankingItemList.map((e) => e.toMap()).toList()),
    );

    rankingSongList
      ..clear()
      ..addAll(rankingItemList.map((e) => e.song));

    if (!isMobile) {
      panelManager.updateBackground();
    }
    rankingChangeNotifier.value++;
  }

  void add2Recently(MyAudioMetadata song) {
    String filePath = clipFilePathIfNeed(song.filePath);

    recentlyPathList.remove(filePath);
    recentlyPathList.insert(0, filePath);
    recentlySongList.remove(song);
    recentlySongList.insert(0, song);
    if (recentlyPathList.length > 500) {
      recentlyPathList.removeLast();
      recentlySongList.removeLast();
    }
    if (!isMobile) {
      panelManager.updateBackground();
    }

    updateRecently();
  }

  void updateRecently() {
    recentlyFile.writeAsStringSync(jsonEncode(recentlyPathList));
    recentlyChangeNotifier.value++;
  }

  void clear() {
    rankingItemList = [];
    rankingSongList = [];

    recentlyPathList = [];
    recentlySongList = [];
  }
}
