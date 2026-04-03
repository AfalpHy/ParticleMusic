import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

ColorManager colorManager = ColorManager();

final Color vividModePageBackgroundColor = Color.fromARGB(100, 245, 245, 245);
final Color vividModeIconColor = Colors.black;
final Color vividModeTextColor = Colors.grey.shade900;
final Color vividModeHighlightTextColor = Colors.black;
final Color vividModeSwitchColor = Colors.black87;
final Color vividModePlayBarColor = Color.fromARGB(100, 245, 245, 245);
final Color vividModePanelColor = Color.fromARGB(100, 245, 245, 245);
final Color vividModeSidebarColor = Color.fromARGB(100, 238, 238, 238);
final Color vividModeBottomColor = Color.fromARGB(100, 250, 250, 250);
final Color vividModeSeekBarColor = Colors.black;
final Color vividModeVolumeBarColor = Colors.black;

final Color lightModePageBackgroundColor = Colors.grey.shade200;
final Color lightModeIconColor = Colors.black;
final Color lightModeTextColor = Colors.grey.shade900;
final Color lightModeHighlightTextColor = Colors.black;
final Color lightModeSwitchColor = Colors.black87;
final Color lightModePlayBarColor = Colors.white70;
final Color lightModePanelColor = Colors.grey.shade100;
final Color lightModeSidebarColor = Colors.grey.shade200;
final Color lightModeBottomColor = Colors.grey.shade50;
final Color lightModeSearchFieldColor = Colors.white;
final Color lightModeButtonColor = Colors.white70;
final Color lightModeDividerColor = Colors.grey;
final Color lightModeSelectedItemColor = Colors.white;
final Color lightModeSeekBarColor = Colors.black;
final Color lightModeVolumeBarColor = Colors.black;
final Color lightModeLyricsPageBackgroundColor = Colors.grey.shade200;
final Color lightModeLyricsPageForegroundColor = Colors.grey.shade900;
final Color lightModeLyricsPageHighlightColor = Colors.black;
final Color lightModelyricsPageButtonColor = Colors.white70;
final Color lightModelyricsPageDividerColor = Colors.grey;
final Color lightModelyricsPageSelectedItemColor = Colors.white;

final Color darkModePageBackgroundColor = Color.fromARGB(255, 50, 50, 50);
final Color darkModeIconColor = Colors.grey.shade400;
final Color darkModeTextColor = Colors.grey.shade400;
final Color darkModeHighlightTextColor = Color.fromARGB(255, 230, 230, 230);
final Color darkModeSwitchColor = Color.fromARGB(221, 0, 0, 0);
final Color darkModePlayerColor = Color.fromARGB(128, 30, 30, 30);
final Color darkModePanelColor = Color.fromARGB(255, 50, 50, 50);
final Color darkModeSidebarColor = Color.fromARGB(255, 55, 55, 55);
final Color darkModeBottomColor = Color.fromARGB(255, 60, 60, 60);
final Color darkModeSearchFieldColor = Colors.grey.shade700;
final Color darkModeButtonColor = Colors.grey.shade700;
final Color darkModeDividerColor = Colors.grey.shade700;
final Color darkModeSelectedItemColor = Colors.grey.shade700;
final Color darkModeSeekBarColor = Colors.grey.shade400;
final Color darkModeVolumeBarColor = Colors.grey.shade400;
final Color darkModeLyricsPageBackgroundColor = Color.fromARGB(255, 50, 50, 50);
final Color darkModeLyricsPageForegroundColor = Colors.grey.shade300;
final Color darkModeLyricsPageHighlightColor = Colors.grey.shade200;
final Color darkModelyricsPageButtonColor = Colors.grey.shade700;
final Color darkModelyricsPageDividerColor = Colors.grey.shade700;
final Color darkModelyricsPageSelectedItemColor = Colors.grey.shade700;

class ColorManager {
  late List<CustomColor> customColors;

  ColorManager() {
    customColors = [
      CustomColor(
        'customPageBackgroundColor',
        lightModePageBackgroundColor,
        type: 1,
      ),
      CustomColor('customIconColor', lightModeIconColor),
      CustomColor('customTextColor', lightModeTextColor),
      CustomColor('customHighlightTextColor', lightModeHighlightTextColor),
      CustomColor('customSwitchColor', lightModeSwitchColor),
      CustomColor('customPlayBarColor', lightModePlayBarColor, type: 1),
      CustomColor('customPanelColor', lightModePanelColor),
      CustomColor('customSidebarColor', lightModeSidebarColor),
      CustomColor('customBottomColor', lightModeBottomColor),
      CustomColor('customSearchFieldColor', lightModeSearchFieldColor),
      CustomColor('customButtonColor', lightModeButtonColor),
      CustomColor('customDividerColor', lightModeDividerColor),
      CustomColor('customSelectedItemColor', lightModeSelectedItemColor),
      CustomColor('customSeekBarColor', lightModeSeekBarColor),
      CustomColor('customVolumeBarColor', lightModeVolumeBarColor, type: 2),
      CustomColor(
        'customLyricsPageBackgroundColor',
        lightModeLyricsPageBackgroundColor,
      ),
      CustomColor(
        'customLyricsPageForegroundColor',
        lightModeLyricsPageForegroundColor,
      ),
      CustomColor(
        'customLyricsPageHighlightColor',
        lightModeLyricsPageHighlightColor,
      ),
      CustomColor(
        'customLyricsPageButtonColor',
        lightModelyricsPageButtonColor,
      ),
      CustomColor(
        'customLyricsPageDividerColor',
        lightModelyricsPageDividerColor,
      ),
      CustomColor(
        'customLyricsPageSelectedItemColor',
        lightModelyricsPageSelectedItemColor,
        type: 2,
      ),
    ];
  }

  Map<String, int> customColorsToMap() {
    return {for (var c in customColors) c.name: c.value.toARGB32()};
  }

  void loadCustomColors(Map<String, dynamic> json) {
    for (var c in customColors) {
      if (json.containsKey(c.name)) {
        c.value = Color(json[c.name]);
      }
    }
  }

  Color getCustomColorByName(String name) {
    late Color value;
    for (final cc in customColors) {
      if (cc.name == name) {
        value = cc.value;
      }
    }
    return value;
  }

  void setColor() {
    if (mainPageThemeNotifier.value == 0) {
      pageBackgroundColor = vividModePageBackgroundColor;
      iconColor = vividModeIconColor;
      textColor = vividModeTextColor;
      highlightTextColor = vividModeHighlightTextColor;
      switchColor = vividModeSwitchColor;
      playBarColor = vividModePlayBarColor;
      panelColor = vividModePanelColor;
      sidebarColor = vividModeSidebarColor;
      bottomColor = vividModeBottomColor;
      searchFieldColor = backgroundBaseColor.withAlpha(75);
      buttonColor = backgroundBaseColor.withAlpha(75);
      dividerColor = backgroundBaseColor;
      selectedItemColor = backgroundBaseColor.withAlpha(75);
      seekBarColor = vividModeSeekBarColor;
      volumeBarColor = vividModeVolumeBarColor;
    } else if (mainPageThemeNotifier.value == 1) {
      pageBackgroundColor = lightModePageBackgroundColor;
      iconColor = lightModeIconColor;
      textColor = lightModeTextColor;
      highlightTextColor = lightModeHighlightTextColor;
      switchColor = lightModeSwitchColor;
      playBarColor = lightModePlayBarColor;
      panelColor = lightModePanelColor;
      sidebarColor = lightModeSidebarColor;
      bottomColor = lightModeBottomColor;
      searchFieldColor = lightModeSearchFieldColor;
      buttonColor = lightModeButtonColor;
      dividerColor = lightModeDividerColor;
      selectedItemColor = lightModeSelectedItemColor;
      seekBarColor = lightModeSeekBarColor;
      volumeBarColor = lightModeVolumeBarColor;
    } else if (mainPageThemeNotifier.value == 2) {
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
      pageBackgroundColor = getCustomColorByName('customPageBackgroundColor');
      iconColor = getCustomColorByName('customIconColor');
      textColor = getCustomColorByName('customTextColor');
      highlightTextColor = getCustomColorByName('customHighlightTextColor');
      switchColor = getCustomColorByName('customSwitchColor');
      playBarColor = getCustomColorByName('customPlayBarColor');
      panelColor = getCustomColorByName('customPanelColor');
      sidebarColor = getCustomColorByName('customSidebarColor');
      bottomColor = getCustomColorByName('customBottomColor');
      searchFieldColor = getCustomColorByName('customSearchFieldColor');
      buttonColor = getCustomColorByName('customButtonColor');
      dividerColor = getCustomColorByName('customDividerColor');
      selectedItemColor = getCustomColorByName('customSelectedItemColor');
      seekBarColor = getCustomColorByName('customSeekBarColor');
      volumeBarColor = getCustomColorByName('customVolumeBarColor');
    }

    if (lyricsPageThemeNotifier.value == 0) {
      lyricsPageBackgroundColor = currentCoverArtColor;
      lyricsPageForegroundColor = Colors.grey.shade50;
      lyricsPageHighlightColor = Colors.white;
      lyricsPageButtonColor = currentCoverArtColor.withAlpha(75);
      lyricsPageDividerColor = currentCoverArtColor.withAlpha(75);
      lyricsPageSelectedItemColor = currentCoverArtColor.withAlpha(75);
    } else if (lyricsPageThemeNotifier.value == 1) {
      lyricsPageBackgroundColor = lightModeLyricsPageBackgroundColor;
      lyricsPageForegroundColor = lightModeLyricsPageForegroundColor;
      lyricsPageHighlightColor = lightModeLyricsPageHighlightColor;
      lyricsPageButtonColor = lightModelyricsPageButtonColor;
      lyricsPageDividerColor = lightModelyricsPageDividerColor;
      lyricsPageSelectedItemColor = lightModelyricsPageSelectedItemColor;
    } else if (lyricsPageThemeNotifier.value == 2) {
      lyricsPageBackgroundColor = darkModeLyricsPageBackgroundColor;
      lyricsPageForegroundColor = darkModeLyricsPageForegroundColor;
      lyricsPageHighlightColor = darkModeLyricsPageHighlightColor;
      lyricsPageButtonColor = darkModelyricsPageButtonColor;
      lyricsPageDividerColor = darkModelyricsPageDividerColor;
      lyricsPageSelectedItemColor = darkModelyricsPageSelectedItemColor;
    } else {
      lyricsPageBackgroundColor = getCustomColorByName(
        'customLyricsPageBackgroundColor',
      );
      lyricsPageForegroundColor = getCustomColorByName(
        'customLyricsPageForegroundColor',
      );
      lyricsPageHighlightColor = getCustomColorByName(
        'customLyricsPageHighlightColor',
      );
      lyricsPageButtonColor = getCustomColorByName(
        'customLyricsPageButtonColor',
      );
      lyricsPageDividerColor = getCustomColorByName(
        'customLyricsPageDividerColor',
      );
      lyricsPageSelectedItemColor = getCustomColorByName(
        'customLyricsPageSelectedItemColor',
      );
    }
  }

  Map<String, String> getNameMap(AppLocalizations l10n) {
    return {
      'customPageBackgroundColor': l10n.backgroundColor,
      'customIconColor': l10n.iconColor,
      'customTextColor': l10n.textColor,
      'customHighlightTextColor': l10n.highlightTextColor,
      'customSwitchColor': l10n.switchColor,
      'customPlayBarColor': l10n.playBarColor,
      'customPanelColor': l10n.panelColor,
      'customSidebarColor': l10n.sidebarColor,
      'customBottomColor': l10n.bottomColor,
      'customSearchFieldColor': l10n.searchFieldColor,
      'customButtonColor': l10n.buttonColor,
      'customDividerColor': l10n.dividerColor,
      'customSelectedItemColor': l10n.selectedItemColor,
      'customSeekBarColor': l10n.seekBarColor,
      'customVolumeBarColor': l10n.volumeBarColor,
      'customLyricsPageBackgroundColor': l10n.lyricsPageBackgroundColor,
      'customLyricsPageForegroundColor': l10n.lyricsPageForegroundColor,
      'customLyricsPageHighlightColor': l10n.lyricsPageHighlightColor,
      'customLyricsPageButtonColor': l10n.lyricsPageButtonColor,
      'customLyricsPageDividerColor': l10n.lyricsPageDividerColor,
      'customLyricsPageSelectedItemColor': l10n.lyricsPageSelectedItemColor,
    };
  }
}

class CustomColor {
  final String name;
  Color defaultValue;
  late Color value;
  // 0 common, 1 mobile only, 2 desktop only
  int type;

  CustomColor(this.name, this.defaultValue, {this.type = 0}) {
    value = defaultValue;
  }

  void reset() {
    value = defaultValue;
  }
}
