import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/lyric_list_view.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/widgets/manage_music_folders.dart';
import 'package:sylvakru/landscape_view/desktop_lyrics.dart';

final exitOnCloseNotifier = ValueNotifier(false);

final setting = Setting();

class Setting {
  late final File file;

  Future<void> load() async {
    file = File("${appSupportDir.path}/setting.json");
    if (!(file.existsSync())) {
      save();
    }

    final content = await file.readAsString();

    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    artistAlbumManager.loadSetting(json);

    playlistManager.useLargePictureNotifier.value =
        json['playlistsUseLargePicture'] as bool? ??
        playlistManager.useLargePictureNotifier.value;

    vibrationOnNoitifier.value =
        json['vibrationOn'] as bool? ?? vibrationOnNoitifier.value;

    final languageCode = json['language'] as String? ?? '';

    if (languageCode.isNotEmpty) {
      localeNotifier.value = Locale(languageCode);
    }

    autoPlayOnStartupNotifier.value =
        json['autoPlayOnStartup'] as bool? ?? false;

    fontFamilyNotifier.value = json['fontFamily'] as String?;

    mainPageThemeNotifier.value = ThemeType.values.firstWhere(
      (e) => e.name == json['mainPageTheme'],
      orElse: () => ThemeType.vivid,
    );

    if (!isPremiumNotifier.value && mainPageThemeNotifier.value == .vivid) {
      mainPageThemeNotifier.value = .light;
    }

    lyricsPageThemeNotifier.value = ThemeType.values.firstWhere(
      (e) => e.name == json['lyricsPageTheme'],
      orElse: () => ThemeType.vivid,
    );

    lyricsFontSizeOffsetNotifier.value =
        json['lyricsFontSizeOffset'] as double? ??
        lyricsFontSizeOffsetNotifier.value;

    exitOnCloseNotifier.value =
        json['exitOnClose'] as bool? ?? exitOnCloseNotifier.value;

    recursiveScanNotifier.value = json['recursiveScan'] as bool? ?? false;

    final desktopLyricsStyle =
        json['desktopLyricsStyle'] as Map<String, dynamic>?;
    if (desktopLyricsStyle != null) {
      applyDesktopLyricsStyleFromMap(desktopLyricsStyle);
    }
  }

  void save() {
    file.writeAsStringSync(
      jsonEncode({
        ...artistAlbumManager.settingToMap(),

        'playlistsUseLargePicture':
            playlistManager.useLargePictureNotifier.value,

        'vibrationOn': vibrationOnNoitifier.value,
        'language': localeNotifier.value?.languageCode,

        'autoPlayOnStartup': autoPlayOnStartupNotifier.value,

        'fontFamily': fontFamilyNotifier.value,

        'mainPageTheme': mainPageThemeNotifier.value.name,
        'lyricsPageTheme': lyricsPageThemeNotifier.value.name,

        'lyricsFontSizeOffset': lyricsFontSizeOffsetNotifier.value,
        'exitOnClose': exitOnCloseNotifier.value,

        'recursiveScan': recursiveScanNotifier.value,

        'desktopLyricsStyle': desktopLyricsStyleToMap(),
      }),
    );
  }
}
