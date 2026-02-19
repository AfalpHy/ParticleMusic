import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';

class SettingManager {
  late final File file;
  SettingManager() {
    file = File("${appSupportDir.path}/setting.txt");
    if (!(file.existsSync())) {
      saveSetting();
    }
  }

  void setColor() {
    if (enableCustomColorNotifier.value) {
      pageBackgroundColor = customPageBackgroundColor;
      iconColor = customIconColor;
      textColor = customTextColor;
      highlightTextColor = customHighlightTextColor;
      switchColor = customSwitchColor;
      playBarColor = customPlayBarColor;
      panelColor = customPanelColor;
      sidebarColor = customSidebarColor;
      bottomColor = customBottomColor;
      searchFieldColor = customSearchFieldColor;
      buttonColor = customButtonColor;
      dividerColor = customDividerColor;
      selectedItemColor = customSelectedItemColor;
      seekBarColor = customSeekBarColor;
      volumeBarColor = customVolumeBarColor;
    } else if (darkModeNotifier.value) {
      pageBackgroundColor = darkModePageBackgroundColor;
      iconColor = darkModeIconColor;
      textColor = darkModeTextColor;
      highlightTextColor = darkModeHighlightTextColor;
      switchColor = darkModeSwitchColor;
      playBarColor = darkModePlayerColor;
      panelColor = darkModePanelColor;
      sidebarColor = darkModeSidebarColor;
      bottomColor = darkModeBottomColor;
      searchFieldColor = darkModeSearchFieldColor;
      buttonColor = darkModeButtonColor;
      dividerColor = darkModeDividerColor;
      selectedItemColor = darkModeSelectedItemColor;
      seekBarColor = darkModeSeekBarColor;
      volumeBarColor = darkModeVolumeBarColor;
    } else {
      pageBackgroundColor = lightModePageBackgroundColor;
      iconColor = lightModeIconColor;
      textColor = lightModeTextColor;
      highlightTextColor = lightModeHighlightTextColor;
      switchColor = lightModeSwitchColor;
      playBarColor = lightModePlayBarColor;
      panelColor = lightModePanelColor;
      sidebarColor = lightModeSidebarColor;
      bottomColor = lightModeBottomColor;
      searchFieldColor = isMobile
          ? Colors.white
          : backgroundFilterColor.withAlpha(75);
      buttonColor = isMobile
          ? Colors.white70
          : backgroundFilterColor.withAlpha(75);
      dividerColor = isMobile ? Colors.grey : backgroundFilterColor;
      selectedItemColor = isMobile
          ? Colors.white
          : backgroundFilterColor.withAlpha(75);
      seekBarColor = lightModeSeekBarColor;
      volumeBarColor = lightModeVolumeBarColor;
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

    final pageBackgroundValue = json['customPageBackgroundColor'];
    if (pageBackgroundValue is int) {
      customPageBackgroundColor = Color(pageBackgroundValue);
    }

    final iconValue = json['customIconColor'];
    if (iconValue is int) {
      customIconColor = Color(iconValue);
    }

    final textValue = json['customTextColor'];
    if (textValue is int) {
      customTextColor = Color(textValue);
    }

    final highlightTextValue = json['customHighlightTextColor'];
    if (highlightTextValue is int) {
      customHighlightTextColor = Color(highlightTextValue);
    }

    final switchValue = json['customSwitchColor'];
    if (switchValue is int) {
      customSwitchColor = Color(switchValue);
    }

    final customPlayerBarValue = json['customPlayBarColor'];
    if (customPlayerBarValue is int) {
      customPlayBarColor = Color(customPlayerBarValue);
    }

    final panelValue = json['customPanelColor'];
    if (panelValue is int) {
      customPanelColor = Color(panelValue);
    }

    final sidebarValue = json['customSidebarColor'];
    if (sidebarValue is int) {
      customSidebarColor = Color(sidebarValue);
    }

    final bottomValue = json['customBottomColor'];
    if (bottomValue is int) {
      customBottomColor = Color(bottomValue);
    }

    final searchFieldValue = json['customSearchFieldColor'];
    if (searchFieldValue is int) {
      customSearchFieldColor = Color(searchFieldValue);
    }

    final buttonValue = json['customButtonColor'];
    if (buttonValue is int) {
      customButtonColor = Color(buttonValue);
    }

    final dividerValue = json['customDividerColor'];
    if (dividerValue is int) {
      customDividerColor = Color(dividerValue);
    }

    final selectedItemValue = json['customSelectedItemColor'];
    if (selectedItemValue is int) {
      customSelectedItemColor = Color(selectedItemValue);
    }

    final seekBarValue = json['customSeekBarColor'];
    if (seekBarValue is int) {
      customSeekBarColor = Color(seekBarValue);
    }

    final customVolumeBarValue = json['customVolumeBarColor'];
    if (customVolumeBarValue is int) {
      customVolumeBarColor = Color(customVolumeBarValue);
    }

    final lyricsBackgroundValue = json['lyricsBackgroundColor'];
    if (lyricsBackgroundValue is int) {
      lyricsBackgroundColor = Color(lyricsBackgroundValue);
    }

    setColor();

    lyricsFontSizeOffset =
        json['lyricsFontSizeOffset'] as double? ?? lyricsFontSizeOffset;

    exitOnCloseNotifier.value =
        json['exitOnClose'] as bool? ?? exitOnCloseNotifier.value;
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
        'customPageBackgroundColor': customPageBackgroundColor.toARGB32(),
        'customIconColor': customIconColor.toARGB32(),
        'customTextColor': customTextColor.toARGB32(),
        'customHighlightTextColor': customHighlightTextColor.toARGB32(),
        'customSwitchColor': customSwitchColor.toARGB32(),
        'customPlayBarColor': customPlayBarColor.toARGB32(),
        'customPanelColor': customPanelColor.toARGB32(),
        'customSidebarColor': customSidebarColor.toARGB32(),
        'customBottomColor': customBottomColor.toARGB32(),
        'customSearchFieldColor': customSearchFieldColor.toARGB32(),
        'customButtonColor': customButtonColor.toARGB32(),
        'customDividerColor': customDividerColor.toARGB32(),
        'customSelectedItemColor': customSelectedItemColor.toARGB32(),
        'customSeekBarColor': customSeekBarColor.toARGB32(),
        'customVolumeBarColor': customVolumeBarColor.toARGB32(),
        'lyricsBackgroundColor': lyricsBackgroundColor.toARGB32(),

        'lyricsFontSizeOffset': lyricsFontSizeOffset,
        'exitOnClose': exitOnCloseNotifier.value,
      }),
    );
  }
}
