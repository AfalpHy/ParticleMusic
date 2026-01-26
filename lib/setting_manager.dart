import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:particle_music/common.dart';

class SettingManager {
  final File file;
  SettingManager(this.file) {
    if (!(file.existsSync())) {
      saveSetting();
    }
  }

  void setColor() {
    // mobile hasn't vivid color mode
    if (isMobile || enableCustomColorNotifier.value) {
      iconColor = customIconColor;
      textColor = customTextColor;
      switchColor = customSwitchColor;
      panelColor = customPanelColor;
      sidebarColor = customSidebarColor;
      bottomColor = customBottomColor;
    } else {
      iconColor = vividIconColor;
      textColor = vividTextColor;
      switchColor = vividSwitchColor;
      panelColor = vividPanelColor;
      sidebarColor = vividSidebarColor;
      bottomColor = vividBottomColor;
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

    enableCustomColorNotifier.value =
        json['enableCustomColor'] as bool? ?? enableCustomColorNotifier.value;

    final iconValue = json['customIconColor'];
    if (iconValue is int) {
      customIconColor = Color(iconValue);
    }

    final textValue = json['customTextColor'];
    if (textValue is int) {
      customTextColor = Color(textValue);
    }

    final switchValue = json['customSwitchColor'];
    if (switchValue is int) {
      customSwitchColor = Color(switchValue);
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

    final searchFieldValue = json['searchFieldColor'];
    if (searchFieldValue is int) {
      searchFieldColor = Color(searchFieldValue);
    }

    final buttonValue = json['buttonColor'];
    if (buttonValue is int) {
      buttonColor = Color(buttonValue);
    }

    final dividerValue = json['dividerColor'];
    if (dividerValue is int) {
      dividerColor = Color(dividerValue);
    }

    final selectedItemValue = json['selectedItemColor'];
    if (selectedItemValue is int) {
      selectedItemColor = Color(selectedItemValue);
    }
    setColor();
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
        'enableCustomColor': enableCustomColorNotifier.value,
        'customIconColor': customIconColor.toARGB32(),
        'customTextColor': customTextColor.toARGB32(),
        'customSwitchColor': customSwitchColor.toARGB32(),
        'customPanelColor': customPanelColor.toARGB32(),
        'customSidebarColor': customSidebarColor.toARGB32(),
        'customBottomColor': customBottomColor.toARGB32(),
        'searchFieldColor': searchFieldColor.toARGB32(),
        'buttonColor': buttonColor.toARGB32(),
        'dividerColor': dividerColor.toARGB32(),
        'selectedItemColor': selectedItemColor.toARGB32(),
      }),
    );
  }
}
