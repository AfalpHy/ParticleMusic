import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';

class HistoryManager {
  late File rankingFile;
  late File recentlyFile;

  List<MyAudioMetadata> rankingSongList = [];
  List<MyAudioMetadata> navidromeRankingSongList = [];

  List<String> recentlyPathList = [];
  List<MyAudioMetadata> recentlySongList = [];
  List<MyAudioMetadata> navidromeRecentlySongList = [];

  final displayNavidromeRankingNotifier = ValueNotifier(false);
  final displayNavidromeRecentlyNotifier = ValueNotifier(false);

  List<MyAudioMetadata> getRankingSongList(bool isNavidrome) {
    return isNavidrome ? navidromeRankingSongList : rankingSongList;
  }

  List<MyAudioMetadata> getRecentlySongList(bool isNavidrome) {
    return isNavidrome ? navidromeRecentlySongList : recentlySongList;
  }

  Future<void> load() async {
    rankingFile = File("${appSupportDir.path}/ranking.txt");
    if (rankingFile.existsSync()) {
      String content = rankingFile.readAsStringSync();
      List<dynamic> jsonList = jsonDecode(content);

      for (final raw in jsonList) {
        final map = Map<String, dynamic>.from(raw);
        String path = map['path'] as String;
        MyAudioMetadata? song = library.filePath2Song[path];
        if (song != null) {
          song.playCount = map['times'] as int;
          rankingSongList.add(song);
        }
      }
    } else {
      rankingFile.writeAsStringSync(jsonEncode([]));
    }

    recentlyFile = File("${appSupportDir.path}/recently.txt");
    if (recentlyFile.existsSync()) {
      String content = recentlyFile.readAsStringSync();
      List<dynamic> jsonList = jsonDecode(content);

      for (String filePath in jsonList) {
        MyAudioMetadata? song = library.filePath2Song[filePath];
        if (song != null) {
          recentlyPathList.add(filePath);
          recentlySongList.add(song);
        }
      }
    } else {
      recentlyFile.writeAsStringSync(jsonEncode([]));
    }

    for (final song in library.navidromeSongList) {
      if (song.playCount > 0) {
        navidromeRankingSongList.add(song);
        navidromeRecentlySongList.add(song);
      }
      navidromeRankingSongList.sort((a, b) {
        int tmp = b.playCount.compareTo(a.playCount);
        return tmp != 0 ? tmp : a.lastPlayed!.compareTo(b.lastPlayed!);
      });

      navidromeRecentlySongList.sort(
        (a, b) => b.lastPlayed!.compareTo(a.lastPlayed!),
      );
    }

    displayNavidromeRankingNotifier.value =
        rankingSongList.isEmpty & navidromeRankingSongList.isNotEmpty;

    displayNavidromeRecentlyNotifier.value =
        recentlySongList.isEmpty & navidromeRecentlySongList.isNotEmpty;
  }

  void _addSongTimes(MyAudioMetadata song, int times) {
    final currentRankingSongList = song.isNavidrome
        ? navidromeRankingSongList
        : rankingSongList;
    int index = -1;
    for (int i = 0; i < currentRankingSongList.length; i++) {
      if (song == currentRankingSongList[i]) {
        currentRankingSongList[i].playCount += times;
        index = i;
        break;
      }
    }

    if (index == -1) {
      song.playCount = 1;
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

    if (song.isNavidrome) {
      while (times-- > 0) {
        await navidromeClient.scrobble(song.id!);
      }
    } else {
      rankingFile.writeAsStringSync(
        jsonEncode(
          rankingSongList
              .map(
                (e) => {
                  'times': e.playCount,
                  'path': clipFilePathIfNeed(e.filePath!),
                },
              )
              .toList(),
        ),
      );
    }

    _add2Recently(song);

    if (!isMobile) {
      panelManager.updateBackground();
    }
    rankingChangeNotifier.value++;
  }

  void _add2Recently(MyAudioMetadata song) {
    if (song.isNavidrome) {
      navidromeRecentlySongList.remove(song);
      navidromeRecentlySongList.insert(0, song);
    } else {
      String filePath = clipFilePathIfNeed(song.filePath!);

      recentlyPathList.remove(filePath);
      recentlyPathList.insert(0, filePath);
      recentlySongList.remove(song);
      recentlySongList.insert(0, song);
      if (recentlyPathList.length > 500) {
        recentlyPathList.removeLast();
        recentlySongList.removeLast();
      }
      recentlyFile.writeAsStringSync(jsonEncode(recentlyPathList));
    }

    recentlyChangeNotifier.value++;
  }

  void clear() {
    rankingSongList = [];
    navidromeRankingSongList = [];

    recentlyPathList = [];
    recentlySongList = [];
    navidromeRecentlySongList = [];
  }
}
