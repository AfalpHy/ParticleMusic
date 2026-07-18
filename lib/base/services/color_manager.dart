import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/contrast_color_generator.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

final colorManager = ColorManager();

Color backgroundCoverArtColor = Colors.grey;
Color currentCoverArtColor = Colors.grey;

ContrastColorTextTheme contrastColorTheme = ContrastColorGenerator.generate(
  currentCoverArtColor,
);

final MyColor pageBackgroundColor = MyColor(
  vividModeValue: Color.fromARGB(100, 245, 245, 245),
  lightModeValue: Colors.grey.shade100,
  darkModeValue: Color.fromARGB(255, 50, 50, 50),
);

final MyColor iconColor = MyColor(
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade400,
);

final MyColor textColor = MyColor(
  vividModeValue: Colors.grey.shade900,
  lightModeValue: Colors.grey.shade900,
  darkModeValue: Colors.grey.shade400,
);

final MyColor highlightTextColor = MyColor(
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Color.fromARGB(255, 230, 230, 230),
);

final MyColor switchColor = MyColor(
  vividModeValue: Colors.black87,
  lightModeValue: Colors.black87,
  darkModeValue: Color.fromARGB(221, 0, 0, 0),
);

final MyColor playBarColor = MyColor(
  vividModeValue: Color.fromARGB(100, 245, 245, 245),
  lightModeValue: Colors.white70,
  darkModeValue: Color.fromARGB(128, 30, 30, 30),
);

final MyColor panelColor = MyColor(
  vividModeValue: Color.fromARGB(100, 245, 245, 245),
  lightModeValue: Colors.white,
  darkModeValue: Color.fromARGB(255, 50, 50, 50),
);

final MyColor sidebarColor = MyColor(
  vividModeValue: Color.fromARGB(100, 238, 238, 238),
  lightModeValue: Colors.grey.shade50,
  darkModeValue: Color.fromARGB(255, 55, 55, 55),
);

final MyColor bottomColor = MyColor(
  vividModeValue: Color.fromARGB(100, 250, 250, 250),
  lightModeValue: Colors.grey.shade100,
  darkModeValue: Color.fromARGB(255, 60, 60, 60),
);

final MyColor searchFieldColor = MyColor(
  getVividValue: () {
    final tmpColor = backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
    return tmpColor.withAlpha(75);
  },
  lightModeValue: Colors.grey.shade200,
  darkModeValue: Colors.grey.shade700,
);

final MyColor buttonColor = MyColor(
  getVividValue: () {
    final tmpColor = backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
    return tmpColor.withAlpha(75);
  },
  lightModeValue: Colors.grey.shade200,
  darkModeValue: Colors.grey.shade700,
);

final MyColor dividerColor = MyColor(
  getVividValue: () {
    return backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
  },
  lightModeValue: Colors.grey,
  darkModeValue: Colors.grey.shade700,
);

final MyColor selectedItemColor = MyColor(
  getVividValue: () {
    final tmpColor = backgroundSong?.lowerLuminance ?? backgroundCoverArtColor;
    return tmpColor.withAlpha(75);
  },
  lightModeValue: Colors.grey.shade200,
  darkModeValue: Colors.grey.shade700,
);

final MyColor menuColor = MyColor(
  vividModeValue: Colors.white54,
  lightModeValue: Colors.grey.shade50,
  darkModeValue: Colors.grey.shade800,
);

final MyColor seekBarColor = MyColor(
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade400,
);

final MyColor volumeBarColor = MyColor(
  vividModeValue: Colors.black,
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade400,
);

final MyColor lyricsPageBackgroundColor = MyColor(
  vividModeValue: Colors.transparent,
  lightModeValue: Colors.grey.shade200,
  darkModeValue: Color.fromARGB(255, 50, 50, 50),
  pageType: 1,
);

final MyColor lyricsPageForegroundColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular;
  },
  lightModeValue: Colors.grey.shade900,
  darkModeValue: Colors.grey.shade300,
  pageType: 1,
);

final MyColor lyricsPageHighlightTextColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.accent;
  },
  lightModeValue: Colors.black,
  darkModeValue: Colors.grey.shade200,
  pageType: 1,
);

final MyColor lyricsPageButtonColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular.withAlpha(50);
  },
  lightModeValue: Colors.white70,
  darkModeValue: Colors.grey.shade700,
  pageType: 1,
);

final MyColor lyricsPageDividerColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular;
  },
  lightModeValue: Colors.grey,
  darkModeValue: Colors.grey.shade700,
  pageType: 1,
);

final MyColor lyricsPageSelectedItemColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular.withAlpha(50);
  },
  lightModeValue: Colors.white,
  darkModeValue: Colors.grey.shade700,
  pageType: 1,
);

final MyColor lyricsPageMenuColor = MyColor(
  vividModeValue: Colors.white10,
  lightModeValue: Colors.grey.shade50,
  darkModeValue: Colors.grey.shade800,
  pageType: 1,
);

final MyColor miniViewForegroundColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular;
  },
  pageType: 2,
);

final MyColor miniViewHighlightTextColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.accent;
  },

  pageType: 2,
);

final MyColor miniViewButtonColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular.withAlpha(50);
  },
  pageType: 2,
);

final MyColor miniViewDividerColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular;
  },
  pageType: 2,
);

final MyColor miniViewSelectedItemColor = MyColor(
  getVividValue: () {
    return contrastColorTheme.regular.withAlpha(50);
  },

  pageType: 2,
);

final MyColor miniViewMenuColor = MyColor(
  vividModeValue: Colors.white10,
  pageType: 2,
);

class ColorManager {
  late final List<MyColor> myMainPageColors;
  late final List<MyColor> myLyricsPageColors;
  late final List<MyColor> myMiniViewColors;

  ColorManager() {
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

    if (!isMobile) {
      myMiniViewColors = [
        miniViewForegroundColor,
        miniViewHighlightTextColor,
        miniViewDividerColor,
        miniViewButtonColor,
        miniViewSelectedItemColor,
        miniViewMenuColor,
      ];
    }
  }

  void updateMainPageColors() {
    for (final color in myMainPageColors) {
      color.updateColor();
    }
  }

  void updateLyricsPageColors() {
    for (final color in myLyricsPageColors) {
      color.updateColor();
    }
  }

  void updateMiniViewColors() {
    for (final color in myMiniViewColors) {
      color.updateColor();
    }
  }

  void updateColors() {
    updateMainPageColors();
    updateLyricsPageColors();
    if (!isMobile) {
      updateMiniViewColors();
    }
  }

  Color? getSpecificMainPageCoverArtBaseColorForm(MyAudioMetadata? song) {
    return mainPageThemeNotifier.value == .vivid
        ? song == null
              ? Colors.grey
              : song.coverArtColor
        : isMobile
        ? pageBackgroundColor.value
        : panelColor.value;
  }

  Color? getSpecificMainPageSearchFieldColorForm(MyAudioMetadata? song) {
    return mainPageThemeNotifier.value == .vivid
        ? song == null
              ? Colors.grey.withAlpha(75)
              : song.coverArtColor?.withAlpha(75)
        : searchFieldColor.value;
  }

  Color getSpecificMainPageCoverArtBaseColor() {
    return mainPageThemeNotifier.value == .vivid
        ? backgroundCoverArtColor
        : isMobile
        ? pageBackgroundColor.value
        : panelColor.value;
  }

  Color getSpecificLyricsPageCoverArtBaseColor() {
    return lyricsPageThemeNotifier.value == .vivid
        ? currentCoverArtColor
        : lyricsPageBackgroundColor.value;
  }

  Color getSpecificBgBaseColor() {
    return viewModeNotifier.value == .mini || displayLyricsPage
        ? currentCoverArtColor
        : backgroundCoverArtColor;
  }

  Color getSpecificBgColor() {
    return viewModeNotifier.value == .mini
        ? Colors.transparent
        : displayLyricsPage
        ? lyricsPageBackgroundColor.value
        : isMobile
        ? pageBackgroundColor.value
        : panelColor.value;
  }

  Color getSpecificTextColor() {
    return viewModeNotifier.value == .mini
        ? miniViewForegroundColor.value
        : displayLyricsPage
        ? lyricsPageForegroundColor.value
        : textColor.value;
  }

  Color getSpecificHighlightTextColor() {
    return viewModeNotifier.value == .mini
        ? miniViewHighlightTextColor.value
        : displayLyricsPage
        ? lyricsPageHighlightTextColor.value
        : highlightTextColor.value;
  }

  Color getSpecificIconColor() {
    return viewModeNotifier.value == .mini
        ? miniViewForegroundColor.value
        : displayLyricsPage
        ? lyricsPageForegroundColor.value
        : iconColor.value;
  }

  Color getSpecificButtonColor() {
    return viewModeNotifier.value == .mini
        ? miniViewButtonColor.value
        : displayLyricsPage
        ? lyricsPageButtonColor.value
        : buttonColor.value;
  }

  Color getSpecificDividerColor() {
    return viewModeNotifier.value == .mini
        ? miniViewDividerColor.value
        : displayLyricsPage
        ? lyricsPageDividerColor.value
        : dividerColor.value;
  }

  Color getSpecificSelectedItemColor() {
    return viewModeNotifier.value == .mini
        ? miniViewSelectedItemColor.value
        : displayLyricsPage
        ? lyricsPageSelectedItemColor.value
        : selectedItemColor.value;
  }

  Color getSpecificMenuColor() {
    if (viewModeNotifier.value == .mini) {
      return miniViewMenuColor.value;
    }
    return displayLyricsPage ? lyricsPageMenuColor.value : menuColor.value;
  }
}

class MyColor {
  // fixed
  final Color? vividModeValue;
  // dynamic
  final Color Function()? getVividValue;
  final Color lightModeValue;
  final Color darkModeValue;

  // main: 0, lyrics: 1, mini mode: 2
  final int pageType;

  ValueNotifier<Color> valueNotifier = ValueNotifier(Colors.transparent);

  MyColor({
    this.vividModeValue,
    this.getVividValue,
    this.lightModeValue = Colors.transparent,
    this.darkModeValue = Colors.transparent,
    this.pageType = 0,
  });

  void updateColor() {
    if (pageType == 2) {
      valueNotifier.value = vividModeValue ?? getVividValue!.call();
      return;
    }

    final themeType = pageType == 0
        ? mainPageThemeNotifier.value
        : lyricsPageThemeNotifier.value;
    switch (themeType) {
      case .vivid:
        valueNotifier.value = vividModeValue ?? getVividValue!.call();
        break;
      case .light:
        valueNotifier.value = lightModeValue;
        break;
      default:
        valueNotifier.value = darkModeValue;
    }
  }

  Color get value => valueNotifier.value;
}
