import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/artists_albums_manager.dart';
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

    artistsAlbumsManager.loadSetting(json);

    playlistsUseLargePictureNotifier.value =
        json['playlistsUseLargePicture'] as bool? ??
        playlistsUseLargePictureNotifier.value;

    vibrationOnNoitifier.value =
        json['vibrationOn'] as bool? ?? vibrationOnNoitifier.value;

    final languageCode = json['language'] as String? ?? '';

    if (languageCode.isNotEmpty) {
      localeNotifier.value = Locale(languageCode);
    }

    autoPlayOnStartupNotifier.value =
        json['autoPlayOnStartup'] as bool? ?? false;

    mainPageThemeNotifier.value =
        json['mainPageTheme'] as int? ?? mainPageThemeNotifier.value;

    lyricsPageThemeNotifier.value =
        json['lyricsPageTheme'] as int? ?? lyricsPageThemeNotifier.value;

    colorManager.loadCustomColors(json);

    colorManager.setColors();

    lyricsFontSizeOffset =
        json['lyricsFontSizeOffset'] as double? ?? lyricsFontSizeOffset;

    exitOnCloseNotifier.value =
        json['exitOnClose'] as bool? ?? exitOnCloseNotifier.value;

    username = json['username'] as String? ?? '';
    password = json['password'] as String? ?? '';
    baseUrl = json['baseUrl'] as String? ?? '';

    webdavUsername = json['webdavUsername'] as String? ?? '';
    webdavPassword = json['webdavPassword'] as String? ?? '';
    webdavBaseUrl = json['webdavBaseUrl'] as String? ?? '';
  }

  void saveSetting() {
    file.writeAsStringSync(
      jsonEncode({
        ...artistsAlbumsManager.settingToMap(),

        'playlistsUseLargePicture': playlistsUseLargePictureNotifier.value,

        'vibrationOn': vibrationOnNoitifier.value,
        'language': localeNotifier.value == null
            ? ''
            : localeNotifier.value!.languageCode,

        'autoPlayOnStartup': autoPlayOnStartupNotifier.value,

        'mainPageTheme': mainPageThemeNotifier.value,
        'lyricsPageTheme': lyricsPageThemeNotifier.value,

        ...colorManager.customColorsToMap(),

        'lyricsFontSizeOffset': lyricsFontSizeOffset,
        'exitOnClose': exitOnCloseNotifier.value,

        'username': username,
        'password': password,
        'baseUrl': baseUrl,

        'webdavUsername': webdavUsername,
        'webdavPassword': webdavPassword,
        'webdavBaseUrl': webdavBaseUrl,
      }),
    );
  }
}
