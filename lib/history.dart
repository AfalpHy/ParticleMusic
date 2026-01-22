import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/load_library.dart';
import 'package:path_provider/path_provider.dart';

final historyChangeNotifier = ValueNotifier(0);

class HistoryItem {
  int times;
  String path;
  AudioMetadata song;
  HistoryItem(this.times, this.path, this.song);

  Map<String, dynamic> toMap() {
    return {'times': times, 'path': path};
  }

  factory HistoryItem.fromSong(AudioMetadata song, int times) {
    String path = song.file.path;
    if (Platform.isIOS) {
      int prefixLength = appDocs.path.length;
      path = path.substring(prefixLength);
    }
    return HistoryItem(times, path, song);
  }
}

class HistoryManager {
  late File file;
  List<HistoryItem> historyItemList = [];
  List<AudioMetadata> historySongList = [];

  Future<void> init() async {
    Directory appSupportDir = await getApplicationSupportDirectory();
    file = File("${appSupportDir.path}/history.txt");
    if (file.existsSync()) {
      String content = file.readAsStringSync();
      List<dynamic> jsonList = jsonDecode(content);

      historyItemList = jsonList
          .map((e) => createHistoryItem(e as Map<String, dynamic>))
          .whereType<HistoryItem>()
          .toList();

      historySongList = historyItemList.map((e) => e.song).toList();
    }
    // write and update
    file.writeAsStringSync(
      jsonEncode(historyItemList.map((e) => e.toMap()).toList()),
    );
  }

  HistoryItem? createHistoryItem(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    String path = map['path'] as String;
    AudioMetadata? song = filePath2LibrarySong[path];
    if (song != null) {
      return HistoryItem(map['times'] as int, path, song);
    }
    return null;
  }

  void addSongTimes(AudioMetadata song, int times) {
    bool exist = false;
    for (int i = 0; i < historyItemList.length; i++) {
      if (song == historyItemList[i].song) {
        historyItemList[i].times += times;
        exist = true;
        break;
      }
    }

    if (!exist) {
      historyItemList.add(HistoryItem.fromSong(song, times));
    }

    historyItemList.sort((a, b) => b.times.compareTo(a.times));

    file.writeAsStringSync(
      jsonEncode(historyItemList.map((e) => e.toMap()).toList()),
    );

    historySongList = historyItemList.map((e) => e.song).toList();
    historyChangeNotifier.value++;
  }

  void clear() {
    historyItemList = [];
  }
}

HistoryManager historyManager = HistoryManager();
