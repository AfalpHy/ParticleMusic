import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/load_library.dart';
import 'package:path_provider/path_provider.dart';

final rankingChangeNotifier = ValueNotifier(0);
final recentlyChangeNotifier = ValueNotifier(0);

class RankingItem {
  int times;
  String path;
  AudioMetadata song;
  RankingItem(this.times, this.path, this.song);

  Map<String, dynamic> toMap() {
    return {'times': times, 'path': path};
  }

  factory RankingItem.fromSong(AudioMetadata song, int times) {
    String path = song.file.path;
    if (Platform.isIOS) {
      path = getIOSPath(path);
    }
    return RankingItem(times, path, song);
  }
}

class HistoryManager {
  late File rankingFile;
  late File recentlyFile;

  List<RankingItem> rankingItemList = [];
  List<AudioMetadata> rankingSongList = [];

  List<String> recentlyPathList = [];
  List<AudioMetadata> recentlySongList = [];

  Future<void> load() async {
    rankingItemList = [];
    rankingSongList = [];

    recentlyPathList = [];
    recentlySongList = [];

    Directory appSupportDir = await getApplicationSupportDirectory();
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
        AudioMetadata? song = filePath2LibrarySong[filePath];
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
    AudioMetadata? song = filePath2LibrarySong[path];
    if (song != null) {
      return RankingItem(map['times'] as int, path, song);
    }
    return null;
  }

  void addSongTimes(AudioMetadata song, int times) {
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

    rankingSongList = rankingItemList.map((e) => e.song).toList();
    if (!isMobile) {
      for (int i = 0; i < panelManager.panelStack.length; i++) {
        if (panelManager.sidebarHighlighLabelStack[i] == 'ranking') {
          panelManager.backgroundSongStack[i] = rankingSongList.first;
        }
      }
      panelManager.updateBackground();
    }
    rankingChangeNotifier.value++;
  }

  void add2Recently(AudioMetadata song) {
    String filePath = song.file.path;
    if (Platform.isIOS) {
      filePath = getIOSPath(filePath);
    }
    recentlyPathList.remove(filePath);
    recentlyPathList.insert(0, filePath);
    recentlySongList.remove(song);
    recentlySongList.insert(0, song);
    if (recentlyPathList.length > 500) {
      recentlyPathList.removeLast();
      recentlySongList.removeLast();
    }
    if (!isMobile) {
      for (int i = 0; i < panelManager.panelStack.length; i++) {
        if (panelManager.sidebarHighlighLabelStack[i] == 'recently') {
          panelManager.backgroundSongStack[i] = song;
        }
      }
      panelManager.updateBackground();
    }

    updateRecently();
  }

  void updateRecently() {
    recentlyFile.writeAsStringSync(jsonEncode(recentlyPathList));
    recentlyChangeNotifier.value++;
  }
}

HistoryManager historyManager = HistoryManager();
