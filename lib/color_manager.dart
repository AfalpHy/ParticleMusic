import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/adaptive_contrast_color_generator.dart';
import 'package:particle_music/my_audio_metadata.dart';

late ColorManager colorManager;

AdaptiveContrastColorTextTheme adaptiveContrastColorTheme =
    AdaptiveContrastColorGenerator.generate(currentCoverArtColor);

final MyColor pageBackgroundColor = MyColor(
  name: 'pageBackgroundColor',
  vividModeValue: Color.fromARGB(100, 245, 245, 245),
  lightModeValue: Colors.grey.shade200,
  darkModeValue: Color.fromARGB(255, 50, 50, 50),
  type: 1,
);

final MyColor iconColor = MyColor(
  name: 'iconColor',
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade400,
);

final MyColor textColor = MyColor(
  name: 'textColor',
  vividModeValue: Colors.grey.shade900,
  lightModeValue: Colors.grey.shade900,
  darkModeValue: Colors.grey.shade400,
);

final MyColor highlightTextColor = MyColor(
  name: 'highlightTextColor',
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Color.fromARGB(255, 230, 230, 230),
);

final MyColor switchColor = MyColor(
  name: 'switchColor',
  vividModeValue: Colors.black87,
  lightModeValue: Colors.black87,
  darkModeValue: Color.fromARGB(221, 0, 0, 0),
);

final MyColor playBarColor = MyColor(
  name: 'playBarColor',
  vividModeValue: Color.fromARGB(100, 245, 245, 245),
  lightModeValue: Colors.white70,
  darkModeValue: Color.fromARGB(128, 30, 30, 30),
  type: 1,
);

final MyColor panelColor = MyColor(
  name: 'panelColor',
  vividModeValue: Color.fromARGB(100, 245, 245, 245),
  lightModeValue: Colors.grey.shade100,
  darkModeValue: Color.fromARGB(255, 50, 50, 50),
);

final MyColor sidebarColor = MyColor(
  name: 'sidebarColor',
  vividModeValue: Color.fromARGB(100, 238, 238, 238),
  lightModeValue: Colors.grey.shade200,
  darkModeValue: Color.fromARGB(255, 55, 55, 55),
);

final MyColor bottomColor = MyColor(
  name: 'bottomColor',
  vividModeValue: Color.fromARGB(100, 250, 250, 250),
  lightModeValue: Colors.grey.shade50,
  darkModeValue: Color.fromARGB(255, 60, 60, 60),
);

final MyColor searchFieldColor = MyColor(
  name: 'searchFieldColor',
  getVividValue: () {
    final tmpColor = backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
    return tmpColor.withAlpha(75);
  },
  lightModeValue: Colors.white,
  darkModeValue: Colors.grey.shade700,
);

final MyColor buttonColor = MyColor(
  name: 'buttonColor',
  getVividValue: () {
    final tmpColor = backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
    return tmpColor.withAlpha(75);
  },
  lightModeValue: Colors.white70,
  darkModeValue: Colors.grey.shade700,
);

final MyColor dividerColor = MyColor(
  name: 'dividerColor',
  getVividValue: () {
    return backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
  },
  lightModeValue: Colors.grey,
  darkModeValue: Colors.grey.shade700,
);

final MyColor selectedItemColor = MyColor(
  name: 'selectedItemColor',
  getVividValue: () {
    final tmpColor = backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
    return tmpColor.withAlpha(75);
  },
  lightModeValue: Colors.white,
  darkModeValue: Colors.grey.shade700,
);

final MyColor menuColor = MyColor(
  name: 'menuColor',
  vividModeValue: Colors.white54,
  lightModeValue: Colors.grey.shade50,
  darkModeValue: Colors.grey.shade800,
  type: 2,
);

final MyColor seekBarColor = MyColor(
  name: 'seekBarColor',
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade400,
);

final MyColor volumeBarColor = MyColor(
  name: 'volumeBarColor',
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade400,
  type: 2,
);

final MyColor lyricsPageBackgroundColor = MyColor(
  name: 'lyricsPageBackgroundColor',
  vividModeValue: Colors.transparent,
  lightModeValue: Colors.grey.shade200,
  darkModeValue: Color.fromARGB(255, 50, 50, 50),
  pageType: 1,
);

final MyColor lyricsPageForegroundColor = MyColor(
  name: 'lyricsPageForegroundColor',
  getVividValue: () {
    return adaptiveContrastColorTheme.regular;
  },
  lightModeValue: Colors.grey.shade900,
  darkModeValue: Colors.grey.shade300,
  pageType: 1,
);

final MyColor lyricsPageHighlightTextColor = MyColor(
  name: 'lyricsPageHighlightTextColor',
  getVividValue: () {
    return adaptiveContrastColorTheme.accent;
  },
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade200,
  pageType: 1,
);

final MyColor lyricsPageButtonColor = MyColor(
  name: 'lyricsPageButtonColor',
  getVividValue: () {
    return adaptiveContrastColorTheme.regular.withAlpha(50);
  },
  lightModeValue: Colors.white70,
  darkModeValue: Colors.grey.shade700,
  pageType: 1,
);

final MyColor lyricsPageDividerColor = MyColor(
  name: 'lyricsPageDividerColor',
  getVividValue: () {
    return adaptiveContrastColorTheme.regular;
  },
  lightModeValue: Colors.grey,
  darkModeValue: Colors.grey.shade700,
  pageType: 1,
);

final MyColor lyricsPageSelectedItemColor = MyColor(
  name: 'lyricsPageSelectedItemColor',
  getVividValue: () {
    return adaptiveContrastColorTheme.regular.withAlpha(50);
  },
  lightModeValue: Colors.white,
  darkModeValue: Colors.grey.shade700,
  type: 2,
  pageType: 1,
);

final MyColor lyricsPageMenuColor = MyColor(
  name: 'lyricsPageMenuColor',
  vividModeValue: Colors.white10,
  lightModeValue: Colors.grey.shade50,
  darkModeValue: Colors.grey.shade800,
  type: 2,
  pageType: 1,
);

class ColorManager {
  late final List<MyColor> myColors;
  late final List<MyColor> myMainPageColors;
  late final List<MyColor> myLyricsPageColors;
  late File file;

  ColorManager() {
    myColors = [
      pageBackgroundColor,
      iconColor,
      textColor,
      highlightTextColor,
      switchColor,
      playBarColor,
      panelColor,
      sidebarColor,
      bottomColor,
      searchFieldColor,
      buttonColor,
      dividerColor,
      selectedItemColor,
      menuColor,
      seekBarColor,
      volumeBarColor,
      lyricsPageBackgroundColor,
      lyricsPageForegroundColor,
      lyricsPageHighlightTextColor,
      lyricsPageDividerColor,
      lyricsPageButtonColor,
      lyricsPageSelectedItemColor,
      lyricsPageMenuColor,
    ];

    myMainPageColors = [
      pageBackgroundColor,
      iconColor,
      textColor,
      highlightTextColor,
      switchColor,
      playBarColor,
      panelColor,
      sidebarColor,
      bottomColor,
      searchFieldColor,
      buttonColor,
      dividerColor,
      selectedItemColor,
      menuColor,
      seekBarColor,
      volumeBarColor,
    ];

    myLyricsPageColors = [
      lyricsPageBackgroundColor,
      lyricsPageForegroundColor,
      lyricsPageHighlightTextColor,
      lyricsPageDividerColor,
      lyricsPageButtonColor,
      lyricsPageSelectedItemColor,
      lyricsPageMenuColor,
    ];

    file = File("${appSupportDir.path}/custom_colors.json");
    if (!(file.existsSync())) {
      saveCustomColors();
    }
  }

  Map<String, int> customColorsToMap() {
    return {for (var c in myColors) c.name: c.customValue.toARGB32()};
  }

  void loadCustomColors() {
    final content = file.readAsStringSync();
    final map = jsonDecode(content) as Map<String, dynamic>;
    for (var c in myColors) {
      if (map.containsKey(c.name)) {
        c.customValue = Color(map[c.name]);
      }
    }
    setColors();
  }

  void saveCustomColors() {
    file.writeAsStringSync(jsonEncode(customColorsToMap()));
  }

  Color getCustomColorByName(String name) {
    late Color value;
    for (final cc in myColors) {
      if (cc.name == name) {
        value = cc.customValue;
        break;
      }
    }
    return value;
  }

  void setMainPageColors() {
    for (final color in myMainPageColors) {
      color.setColor();
    }
  }

  void setLyricsPageColors() {
    for (final color in myLyricsPageColors) {
      color.setColor();
    }
  }

  void setColors() {
    setMainPageColors();
    setLyricsPageColors();
  }

  Map<String, String> getNameMap(AppLocalizations l10n) {
    return {
      'pageBackgroundColor': l10n.backgroundColor,
      'iconColor': l10n.iconColor,
      'textColor': l10n.textColor,
      'highlightTextColor': l10n.highlightTextColor,
      'switchColor': l10n.switchColor,
      'playBarColor': l10n.playBarColor,
      'panelColor': l10n.panelColor,
      'sidebarColor': l10n.sidebarColor,
      'bottomColor': l10n.bottomColor,
      'searchFieldColor': l10n.searchFieldColor,
      'buttonColor': l10n.buttonColor,
      'dividerColor': l10n.dividerColor,
      'selectedItemColor': l10n.selectedItemColor,
      'menuColor': l10n.menuColor,
      'seekBarColor': l10n.seekBarColor,
      'volumeBarColor': l10n.volumeBarColor,
      'lyricsPageBackgroundColor': l10n.lyricsPageBackgroundColor,
      'lyricsPageForegroundColor': l10n.lyricsPageForegroundColor,
      'lyricsPageHighlightTextColor': l10n.lyricsPageHighlightTextColor,
      'lyricsPageButtonColor': l10n.lyricsPageButtonColor,
      'lyricsPageDividerColor': l10n.lyricsPageDividerColor,
      'lyricsPageSelectedItemColor': l10n.lyricsPageSelectedItemColor,
      'lyricsPageMenuColor': l10n.lyricsPageMenuColor,
    };
  }

  Color? getSpecificMainPageCoverArtBaseColorForm(MyAudioMetadata? song) {
    return mainPageThemeNotifier.value == 0
        ? song == null
              ? Colors.grey
              : song.coverArtColor
        : isMobile
        ? pageBackgroundColor.value
        : panelColor.value;
  }

  Color? getSpecificMainPageSearchFieldColorForm(MyAudioMetadata? song) {
    return mainPageThemeNotifier.value == 0
        ? song == null
              ? Colors.grey.withAlpha(75)
              : song.coverArtColor?.withAlpha(75)
        : searchFieldColor.value;
  }

  Color getSpecificMainPageCoverArtBaseColor() {
    return mainPageThemeNotifier.value == 0
        ? backgroundCoverArtColor
        : isMobile
        ? pageBackgroundColor.value
        : panelColor.value;
  }

  Color getSpecificLyricsPageCoverArtBaseColor() {
    return lyricsPageThemeNotifier.value == 0
        ? currentCoverArtColor
        : lyricsPageBackgroundColor.value;
  }

  Color getSpecificBgBaseColor() {
    return miniModeNotifier.value || displayLyricsPageNotifier.value
        ? currentCoverArtColor
        : backgroundCoverArtColor;
  }

  Color getSpecificBgColor() {
    return miniModeNotifier.value
        ? Color.fromARGB(100, 245, 245, 245)
        : displayLyricsPageNotifier.value
        ? lyricsPageBackgroundColor.value
        : isMobile
        ? pageBackgroundColor.value
        : panelColor.value;
  }

  Color getSpecificTextColor() {
    return miniModeNotifier.value
        ? Colors.grey.shade50
        : displayLyricsPageNotifier.value
        ? lyricsPageForegroundColor.value
        : textColor.value;
  }

  Color getSpecificHighlightTextColor() {
    return miniModeNotifier.value
        ? Colors.grey.shade50
        : displayLyricsPageNotifier.value
        ? lyricsPageHighlightTextColor.value
        : highlightTextColor.value;
  }

  Color getSpecificIconColor() {
    return miniModeNotifier.value
        ? Colors.grey.shade50
        : displayLyricsPageNotifier.value
        ? lyricsPageForegroundColor.value
        : iconColor.value;
  }

  Color getSpecificButtonColor() {
    return miniModeNotifier.value
        ? currentCoverArtColor.withAlpha(75)
        : displayLyricsPageNotifier.value
        ? lyricsPageButtonColor.value
        : buttonColor.value;
  }

  Color getSpecificDividerColor() {
    return miniModeNotifier.value
        ? currentCoverArtColor
        : displayLyricsPageNotifier.value
        ? lyricsPageDividerColor.value
        : dividerColor.value;
  }

  Color getSpecificSelectedItemColor() {
    return miniModeNotifier.value
        ? Colors.grey.shade50.withAlpha(50)
        : displayLyricsPageNotifier.value
        ? lyricsPageSelectedItemColor.value
        : selectedItemColor.value;
  }

  Color getSpecificMenuColor() {
    if (miniModeNotifier.value) {
      return Colors.white30;
    }
    return displayLyricsPageNotifier.value
        ? lyricsPageMenuColor.value
        : menuColor.value;
  }
}

class MyColor {
  final String name;
  // fixed
  final Color? vividModeValue;
  // dynamic
  final Color Function()? getVividValue;
  final Color lightModeValue;
  final Color darkModeValue;
  late Color customValue;

  // common: 0, mobile only: 1, desktop only: 2
  final int type;

  // main: 0, lyrics: 1, mini mode: 2
  final int pageType;

  ValueNotifier<Color> valueNotifier = ValueNotifier(Colors.white);

  MyColor({
    required this.name,
    this.vividModeValue,
    this.getVividValue,
    required this.lightModeValue,
    required this.darkModeValue,
    this.type = 0,
    this.pageType = 0,
  }) {
    customValue = lightModeValue;
  }

  void setColor() {
    final mode = pageType == 0
        ? mainPageThemeNotifier.value
        : lyricsPageThemeNotifier.value;
    switch (mode) {
      case 0:
        valueNotifier.value = vividModeValue ?? getVividValue!.call();
        break;
      case 1:
        valueNotifier.value = lightModeValue;
        break;
      case 2:
        valueNotifier.value = darkModeValue;
        break;
      default:
        valueNotifier.value = customValue;
    }
  }

  Color get value => valueNotifier.value;

  void resetCustomValue() {
    customValue = lightModeValue;
  }
}
