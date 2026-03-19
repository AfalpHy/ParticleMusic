import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/navidrome_client.dart';

class SettingManager {
  late final File file;
  SettingManager() {
    file = File("${appSupportDir.path}/setting.txt");
    if (!(file.existsSync())) {
      saveSetting();
    }
  }

  Future<void> loadSetting() async {
    final content = await file.readAsString();

    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

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

    playlistsUseLargePictureNotifier.value =
        json['playlistsUseLargePicture'] as bool? ??
        playlistsUseLargePictureNotifier.value;

    vibrationOnNoitifier.value =
        json['vibrationOn'] as bool? ?? vibrationOnNoitifier.value;

    final languageCode = json['language'] as String? ?? '';

    if (languageCode.isNotEmpty) {
      localeNotifier.value = Locale(languageCode);
    }

    darkModeNotifier.value =
        json['darkMode'] as bool? ?? darkModeNotifier.value;

    enableCustomColorNotifier.value =
        json['enableCustomColor'] as bool? ?? enableCustomColorNotifier.value;

    enableCustomLyricsPageNotifier.value =
        json['enableCustomLyricsPage'] as bool? ??
        enableCustomLyricsPageNotifier.value;

    colorManager.loadCustomColors(json);

    colorManager.setColor();

    lyricsFontSizeOffset =
        json['lyricsFontSizeOffset'] as double? ?? lyricsFontSizeOffset;

    exitOnCloseNotifier.value =
        json['exitOnClose'] as bool? ?? exitOnCloseNotifier.value;

    username = json['username'] as String? ?? '';
    password = json['password'] as String? ?? '';
    baseUrl = json['baseUrl'] as String? ?? '';
  }

  void saveSetting() {
    file.writeAsStringSync(
      jsonEncode({
        'artistsIsList': artistsIsListViewNotifier.value,
        'artistsIsAscend': artistsIsAscendingNotifier.value,
        'artistsUseLargePicture': artistsUseLargePictureNotifier.value,

        'albumsIsAscend': albumsIsAscendingNotifier.value,
        'albumsUseLargePicture': albumsUseLargePictureNotifier.value,

        'playlistsUseLargePicture': playlistsUseLargePictureNotifier.value,

        'vibrationOn': vibrationOnNoitifier.value,
        'language': localeNotifier.value == null
            ? ''
            : localeNotifier.value!.languageCode,
        'darkMode': darkModeNotifier.value,
        'enableCustomColor': enableCustomColorNotifier.value,
        'enableCustomLyricsPage': enableCustomLyricsPageNotifier.value,

        ...colorManager.customColorsToMap(),

        'lyricsFontSizeOffset': lyricsFontSizeOffset,
        'exitOnClose': exitOnCloseNotifier.value,

        'username': username,
        'password': password,
        'baseUrl': baseUrl,
      }),
    );
  }
}
