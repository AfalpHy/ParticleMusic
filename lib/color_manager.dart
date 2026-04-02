import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

ColorManager colorManager = ColorManager();

const Color lightModePageBackgroundColor = Color.fromARGB(100, 245, 245, 245);
const Color lightModeIconColor = Colors.black;
const Color lightModeTextColor = Color.fromARGB(255, 30, 30, 30);
const Color lightModeHighlightTextColor = Colors.black;
const Color lightModeSwitchColor = Colors.black87;
const Color lightModePlayBarColor = Color.fromARGB(100, 245, 245, 245);
const Color lightModePanelColor = Color.fromARGB(100, 245, 245, 245);
const Color lightModeSidebarColor = Color.fromARGB(100, 238, 238, 238);
const Color lightModeBottomColor = Color.fromARGB(100, 250, 250, 250);
const Color lightModeSeekBarColor = Colors.black;
const Color lightModeVolumeBarColor = Colors.black;

const Color darkModePageBackgroundColor = Color.fromARGB(255, 50, 50, 50);
const Color darkModeCommonColor = Color.fromARGB(255, 97, 97, 97);
const Color darkModeIconColor = Color.fromARGB(255, 195, 195, 195);
const Color darkModeTextColor = Color.fromARGB(255, 195, 195, 195);
const Color darkModeHighlightTextColor = Color.fromARGB(255, 230, 230, 230);
const Color darkModeSwitchColor = Color.fromARGB(221, 0, 0, 0);
const Color darkModePlayerColor = Color.fromARGB(128, 30, 30, 30);
const Color darkModePanelColor = Color.fromARGB(255, 50, 50, 50);
const Color darkModeSidebarColor = Color.fromARGB(255, 55, 55, 55);
const Color darkModeBottomColor = Color.fromARGB(255, 60, 60, 60);
const Color darkModeSearchFieldColor = darkModeCommonColor;
const Color darkModeButtonColor = darkModeCommonColor;
const Color darkModeDividerColor = darkModeCommonColor;
const Color darkModeSelectedItemColor = darkModeCommonColor;
const Color darkModeSeekBarColor = Color.fromARGB(255, 195, 195, 195);
const Color darkModeVolumeBarColor = Color.fromARGB(255, 195, 195, 195);

class ColorManager {
  late List<CustomColor> customColors;

  ColorManager() {
    customColors = [
      CustomColor(
        'customPageBackgroundColor',
        const Color.fromARGB(255, 245, 245, 245),
        type: 1,
      ),
      CustomColor('customIconColor', Colors.black),
      CustomColor('customTextColor', const Color.fromARGB(255, 30, 30, 30)),
      CustomColor('customHighlightTextColor', Colors.black),
      CustomColor('customSwitchColor', Colors.black87),
      CustomColor('customPlayBarColor', Colors.white70, type: 1),
      CustomColor('customPanelColor', Colors.grey.shade100),
      CustomColor('customSidebarColor', Colors.grey.shade200),
      CustomColor('customBottomColor', Colors.grey.shade50),
      CustomColor('customSearchFieldColor', Colors.white),
      CustomColor('customButtonColor', Colors.white70),
      CustomColor('customDividerColor', Colors.grey),
      CustomColor('customSelectedItemColor', Colors.white),
      CustomColor('customSeekBarColor', Colors.black),
      CustomColor('customVolumeBarColor', Colors.black, type: 2),
      CustomColor('lyricsBackgroundColor', Colors.black),
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
    if (enableCustomColorNotifier.value) {
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
      searchFieldColor = backgroundBaseColor.withAlpha(75);
      buttonColor = backgroundBaseColor.withAlpha(75);
      dividerColor = backgroundBaseColor;
      selectedItemColor = backgroundBaseColor.withAlpha(75);
      seekBarColor = lightModeSeekBarColor;
      volumeBarColor = lightModeVolumeBarColor;
    }

    lyricsBackgroundColor = getCustomColorByName('lyricsBackgroundColor');
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
      'lyricsBackgroundColor': l10n.lyricsBackgroundColor,
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
