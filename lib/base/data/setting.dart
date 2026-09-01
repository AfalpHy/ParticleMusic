import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/lyric_list_view.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/widgets/manage_music_folders.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

final artistsIsListViewNotifier = ValueNotifier(true);
final artistsIsAscendingNotifier = ValueNotifier(true);
final artistsUseLargePictureNotifier = ValueNotifier(false);
final artistsRandomizeNotifier = ValueNotifier(false);

final albumsIsAscendingNotifier = ValueNotifier(true);
final albumsUseLargePictureNotifier = ValueNotifier(false);
final albumsRandomizeNotifier = ValueNotifier(false);

final playlistsUseLargePictureNotifier = ValueNotifier(true);

final exitOnCloseNotifier = ValueNotifier(false);

final setting = Setting();

class Setting {
  late final File file;

  Future<void> load() async {
    file = File("${appSupportDir.path}/setting.json");
    initFile(file, false);

    final json = await readJsonMapFile(file);

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

    endDrawerNotifier.value = json['endDrawer'] as bool? ?? Platform.isIOS;

    vibrationOnNoitifier.value =
        json['vibrationOn'] as bool? ?? vibrationOnNoitifier.value;

    final languageCode = json['language'] as String? ?? '';

    if (languageCode.isNotEmpty) {
      localeNotifier.value = Locale(languageCode);
    }

    immersiveWideLayoutNotifier.value =
        json['immersiveWideLayout'] as bool? ?? true;

    autoPlayOnStartupNotifier.value =
        json['autoPlayOnStartup'] as bool? ?? false;

    if (isPremiumNotifier.value) {
      fontFamilyNotifier.value = json['fontFamily'] as String?;
    }

    mainPageThemeNotifier.value = ThemeType.values.firstWhere(
      (e) => e.name == json['mainPageTheme'],
      orElse: () => ThemeType.vivid,
    );

    if (!isPremiumNotifier.value && mainPageThemeNotifier.value == .vivid) {
      mainPageThemeNotifier.value = .light;
    }

    updateHoverFocusColor();

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
  }

  void save() {
    file.writeAsStringSync(
      jsonEncode({
        'artistsIsList': artistsIsListViewNotifier.value,
        'artistsIsAscend': artistsIsAscendingNotifier.value,
        'artistsUseLargePicture': artistsUseLargePictureNotifier.value,

        'albumsIsAscend': albumsIsAscendingNotifier.value,
        'albumsUseLargePicture': albumsUseLargePictureNotifier.value,

        'playlistsUseLargePicture': playlistsUseLargePictureNotifier.value,

        'endDrawer': endDrawerNotifier.value,

        'vibrationOn': vibrationOnNoitifier.value,
        'language': localeNotifier.value?.languageCode,

        'immersiveWideLayout': immersiveWideLayoutNotifier.value,
        'autoPlayOnStartup': autoPlayOnStartupNotifier.value,

        'fontFamily': fontFamilyNotifier.value,

        'mainPageTheme': mainPageThemeNotifier.value.name,
        'lyricsPageTheme': lyricsPageThemeNotifier.value.name,

        'lyricsFontSizeOffset': lyricsFontSizeOffsetNotifier.value,
        'exitOnClose': exitOnCloseNotifier.value,

        'recursiveScan': recursiveScanNotifier.value,
      }),
    );
  }
}
