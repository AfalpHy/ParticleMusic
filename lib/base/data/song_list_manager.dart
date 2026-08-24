import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

class SongListManager {
  final Map<SourceType, List<MyAudioMetadata>> songListMap = {
    .local: [],
    .webdav: [],
    .subsonic: [],
    .navidrome: [],
    .emby: [],
  };

  final Map<SourceType, ValueNotifier<int>> sortTypeNotifierMap = {
    .local: ValueNotifier(0),
    .webdav: ValueNotifier(0),
    .subsonic: ValueNotifier(0),
    .navidrome: ValueNotifier(0),
    .emby: ValueNotifier(0),
  };

  final Map<SourceType, ValueNotifier<int>> changeNotifierMap = {
    .local: ValueNotifier(0),
    .webdav: ValueNotifier(0),
    .subsonic: ValueNotifier(0),
    .navidrome: ValueNotifier(0),
    .emby: ValueNotifier(0),
  };

  final sourceTypeNotifier = ValueNotifier(SourceType.local);

  ValueNotifier<int> changeNotifier = ValueNotifier(0);

  SongListManager() {
    for (final changeNotifier in changeNotifierMap.values) {
      changeNotifier.addListener(_notify);
    }

    sourceTypeNotifier.addListener(_notify);
  }

  List<MyAudioMetadata> get localSongList => songListMap[SourceType.local]!;
  List<MyAudioMetadata> get webdavSongList => songListMap[SourceType.webdav]!;
  List<MyAudioMetadata> get subsonicSongList =>
      songListMap[SourceType.subsonic]!;
  List<MyAudioMetadata> get navidromeSongList =>
      songListMap[SourceType.navidrome]!;
  List<MyAudioMetadata> get embySongList => songListMap[SourceType.emby]!;

  ValueNotifier get localChangeNotifier => changeNotifierMap[SourceType.local]!;
  ValueNotifier get webdavChangeNotifier =>
      changeNotifierMap[SourceType.webdav]!;
  ValueNotifier get subsonicChangeNotifier =>
      changeNotifierMap[SourceType.subsonic]!;
  ValueNotifier get navidromeChangeNotifier =>
      changeNotifierMap[SourceType.navidrome]!;
  ValueNotifier get embyChangeNotifier => changeNotifierMap[SourceType.emby]!;

  String get sourceTypeName => sourceTypeNotifier.value.name;

  void _notify() {
    changeNotifier.value++;
  }

  void resetSourceType() {
    if (currentSongList.isNotEmpty) {
      return;
    }

    for (final entry in songListMap.entries) {
      if (entry.value.isNotEmpty) {
        sourceTypeNotifier.value = entry.key;
        return;
      }
    }

    sourceTypeNotifier.value = .local;
  }

  List<MyAudioMetadata> get currentSongList =>
      songListMap[sourceTypeNotifier.value]!;

  List<MyAudioMetadata> getSongList(SourceType sourceType) =>
      songListMap[sourceType]!;

  ValueNotifier<int> getSortTypeNotifier(SourceType sourceType) =>
      sortTypeNotifierMap[sourceType]!;

  ValueNotifier<int> get currentChangeNotifier =>
      changeNotifierMap[sourceTypeNotifier.value]!;

  ValueNotifier<int> getChangeNotifier(SourceType sourceType) =>
      changeNotifierMap[sourceType]!;

  bool get isEmpty {
    for (final songList in songListMap.values) {
      if (songList.isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  int get totalCount {
    int cnt = 0;
    for (final songList in songListMap.values) {
      cnt += songList.length;
    }
    return cnt;
  }

  int get notEmptyCount {
    int cnt = 0;
    for (final songList in songListMap.values) {
      if (songList.isNotEmpty) {
        cnt++;
      }
    }
    return cnt;
  }

  void prepareForSync(SourceType sourceType) {
    getSongList(sourceType).clear();
    getChangeNotifier(sourceType).value++;
  }

  void clear() {
    for (final songList in songListMap.values) {
      songList.clear();
    }
  }
}
