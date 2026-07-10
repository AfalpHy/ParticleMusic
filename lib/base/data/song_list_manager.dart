import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

class SongListManager {
  List<MyAudioMetadata> localSongList = [];
  List<MyAudioMetadata> webdavSongList = [];
  List<MyAudioMetadata> subsonicSongList = [];
  List<MyAudioMetadata> navidromeSongList = [];
  List<MyAudioMetadata> embySongList = [];

  ValueNotifier<int> localSortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> webdavSortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> subsonicSortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> navidromeSortTypeNotifier = ValueNotifier(0);
  ValueNotifier<int> embySortTypeNotifier = ValueNotifier(0);

  ValueNotifier<int> localChangeNotifier = ValueNotifier(0);
  ValueNotifier<int> navidromeChangeNotifier = ValueNotifier(0);
  ValueNotifier<int> subsonicChangeNotifier = ValueNotifier(0);
  ValueNotifier<int> webdavChangeNotifier = ValueNotifier(0);
  ValueNotifier<int> embyChangeNotifier = ValueNotifier(0);

  final sourceTypeNotifier = ValueNotifier(SourceType.local);

  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  SongListManager() {
    localChangeNotifier.addListener(_notify);
    webdavChangeNotifier.addListener(_notify);
    subsonicChangeNotifier.addListener(_notify);
    navidromeChangeNotifier.addListener(_notify);
    embyChangeNotifier.addListener(_notify);

    sourceTypeNotifier.addListener(_notify);
  }

  String get sourceTypeName => sourceTypeNotifier.value.name;

  void _notify() {
    changeNotifier.value++;
  }

  void resetSourceType() {
    if (getSongList().isNotEmpty) {
      return;
    }
    if (localSongList.isNotEmpty) {
      sourceTypeNotifier.value = .local;
    } else if (webdavSongList.isNotEmpty) {
      sourceTypeNotifier.value = .webdav;
    } else if (subsonicSongList.isNotEmpty) {
      sourceTypeNotifier.value = .subsonic;
    } else if (navidromeSongList.isNotEmpty) {
      sourceTypeNotifier.value = .navidrome;
    } else if (embySongList.isNotEmpty) {
      sourceTypeNotifier.value = .emby;
    } else {
      sourceTypeNotifier.value = .local;
    }
  }

  List<MyAudioMetadata> getSongList() {
    switch (sourceTypeNotifier.value) {
      case .local:
        return localSongList;
      case .webdav:
        return webdavSongList;
      case .subsonic:
        return subsonicSongList;
      case .navidrome:
        return navidromeSongList;
      default:
        return embySongList;
    }
  }

  List<MyAudioMetadata> getSongList2(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return localSongList;
      case .webdav:
        return webdavSongList;
      case .subsonic:
        return subsonicSongList;
      case .navidrome:
        return navidromeSongList;
      default:
        return embySongList;
    }
  }

  ValueNotifier<int> getSortTypeNotifier() {
    switch (sourceTypeNotifier.value) {
      case .local:
        return localSortTypeNotifier;
      case .webdav:
        return webdavSortTypeNotifier;
      case .subsonic:
        return subsonicSortTypeNotifier;
      case .navidrome:
        return navidromeSortTypeNotifier;
      default:
        return embySortTypeNotifier;
    }
  }

  ValueNotifier<int> getSortTypeNotifier2(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return localSortTypeNotifier;
      case .webdav:
        return webdavSortTypeNotifier;
      case .subsonic:
        return subsonicSortTypeNotifier;

      case .navidrome:
        return navidromeSortTypeNotifier;
      default:
        return embySortTypeNotifier;
    }
  }

  ValueNotifier<int> getChangeNotifier() {
    switch (sourceTypeNotifier.value) {
      case .local:
        return localChangeNotifier;
      case .webdav:
        return webdavChangeNotifier;
      case .subsonic:
        return subsonicChangeNotifier;
      case .navidrome:
        return navidromeChangeNotifier;
      default:
        return embyChangeNotifier;
    }
  }

  ValueNotifier<int> getChangeNotifier2(SourceType sourceType) {
    switch (sourceType) {
      case .local:
        return localChangeNotifier;
      case .webdav:
        return webdavChangeNotifier;
      case .subsonic:
        return subsonicChangeNotifier;
      case .navidrome:
        return navidromeChangeNotifier;
      default:
        return embyChangeNotifier;
    }
  }

  bool get isEmpty {
    return localSongList.isEmpty &&
        webdavSongList.isEmpty &&
        subsonicSongList.isEmpty &&
        navidromeSongList.isEmpty &&
        embySongList.isEmpty;
  }

  int get totalCount {
    return localSongList.length +
        webdavSongList.length +
        subsonicSongList.length +
        navidromeSongList.length +
        embySongList.length;
  }

  int get notEmptyCount {
    int cnt = 0;
    if (localSongList.isNotEmpty) {
      cnt++;
    }
    if (webdavSongList.isNotEmpty) {
      cnt++;
    }
    if (subsonicSongList.isNotEmpty) {
      cnt++;
    }
    if (navidromeSongList.isNotEmpty) {
      cnt++;
    }
    if (embySongList.isNotEmpty) {
      cnt++;
    }
    return cnt;
  }

  void prepareForSync(SourceType sourceType) {
    getSongList2(sourceType).clear();
    getChangeNotifier2(sourceType).value++;
  }

  void clear() {
    localSongList.clear();
    webdavSongList.clear();
    subsonicSongList.clear();
    navidromeSongList.clear();
    embySongList.clear();
  }
}
