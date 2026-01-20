import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/bottom_control.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/desktop/sidebar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/my_switch.dart';
import 'package:smooth_corner/smooth_corner.dart';

ValueNotifier<bool> vibrationOnNoitifier = ValueNotifier(true);

ValueNotifier<bool> timedPause = ValueNotifier(false);
ValueNotifier<int> remainTimes = ValueNotifier(0);
ValueNotifier<bool> pauseAfterCompleted = ValueNotifier(false);
bool needPause = false;
Timer? pauseTimer;

final artistsIsListViewNotifier = ValueNotifier(true);
final artistsIsAscendingNotifier = ValueNotifier(true);
final artistsUseLargePictureNotifier = ValueNotifier(false);

final albumsIsAscendingNotifier = ValueNotifier(true);
final albumsUseLargePictureNotifier = ValueNotifier(false);

final playlistsUseLargePictureNotifier = ValueNotifier(true);

final enableCustomColorNotifier = ValueNotifier(false);
final colorChangeNotifier = ValueNotifier(0);

late Setting setting;

class Setting {
  final File file;
  Setting(this.file) {
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
      }),
    );
  }

  void sortArtists() {
    artistMapEntryList.sort((a, b) {
      if (artistsIsAscendingNotifier.value) {
        return compareMixed(a.key, b.key);
      } else {
        return compareMixed(b.key, a.key);
      }
    });
  }

  void sortAlbums() {
    albumMapEntryList.sort((a, b) {
      if (albumsIsAscendingNotifier.value) {
        return compareMixed(a.key, b.key);
      } else {
        return compareMixed(b.key, a.key);
      }
    });
  }
}

void displayTimedPauseSetting(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      Duration currentDuration = Duration();
      final l10n = AppLocalizations.of(context);

      return mySheet(
        height: 350,
        Center(
          child: Column(
            children: [
              Spacer(),
              CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hms, // hours, minutes, seconds
                onTimerDurationChanged: (Duration newDuration) {
                  currentDuration = newDuration;
                },
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      timedPause.value = false;
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      backgroundColor: buttonColor,
                      shadowColor: Colors.black54,
                      foregroundColor: Colors.black,
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                  SizedBox(width: 30),
                  ElevatedButton(
                    onPressed: () {
                      int time = 0;
                      time += currentDuration.inHours * 3600;
                      time += currentDuration.inMinutes % 60 * 60;
                      time += currentDuration.inSeconds % 60;
                      remainTimes.value = time;

                      pauseTimer ??= Timer.periodic(
                        const Duration(seconds: 1),
                        (_) {
                          if (remainTimes.value > 0) {
                            remainTimes.value--;
                          }
                          if (remainTimes.value == 0) {
                            pauseTimer!.cancel();
                            pauseTimer = null;
                            timedPause.value = false;

                            if (pauseAfterCompleted.value) {
                              needPause = true;
                            } else {
                              audioHandler.pause();
                            }
                          }
                        },
                      );

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      backgroundColor: buttonColor,
                      shadowColor: Colors.black54,
                      foregroundColor: Colors.black,
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(l10n.confirm),
                  ),

                  Spacer(),
                ],
              ),
              Spacer(),
            ],
          ),
        ),
      );
    },
  ).then((_) {
    if (remainTimes.value == 0) {
      timedPause.value = false;
    }
  });
}

Widget sleepTimerListTile(
  BuildContext context,
  AppLocalizations l10n,
  bool inSetting,
) {
  return ListTile(
    leading: ImageIcon(
      timerImage,
      color: inSetting ? iconColor : Colors.black,
      size: inSetting ? 30 : null,
    ),

    title: Text(
      l10n.sleepTimer,
      style: TextStyle(fontWeight: inSetting ? null : FontWeight.bold),
    ),
    trailing: SizedBox(
      width: 150,
      child: Row(
        children: [
          Spacer(),
          ValueListenableBuilder(
            valueListenable: remainTimes,
            builder: (context, value, child) {
              final hours = (value ~/ 3600).toString().padLeft(2, '0');
              final minutes = ((value % 3600) ~/ 60).toString().padLeft(2, '0');
              final secs = (value % 60).toString().padLeft(2, '0');
              return ValueListenableBuilder(
                valueListenable: timedPause,
                builder: (context, on, child) {
                  return value > 0 || on
                      ? Text('$hours:$minutes:$secs')
                      : SizedBox();
                },
              );
            },
          ),
          SizedBox(width: 10),
          ValueListenableBuilder(
            valueListenable: timedPause,
            builder: (context, value, child) {
              return MySwitch(
                value: value,
                onToggle: (value) async {
                  tryVibrate();
                  timedPause.value = value;
                  if (value) {
                    displayTimedPauseSetting(context);
                  } else {
                    pauseTimer?.cancel();
                    pauseTimer = null;
                    remainTimes.value = 0;
                  }
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget pauseAfterCTListTile(BuildContext context, AppLocalizations l10n) {
  return ValueListenableBuilder(
    valueListenable: timedPause,
    builder: (_, value, _) {
      return value
          ? ListTile(
              trailing: SizedBox(
                width: 200,
                child: Row(
                  children: [
                    Spacer(),
                    Text(l10n.pauseAfterCurrentTrack),
                    SizedBox(width: 10),
                    ValueListenableBuilder(
                      valueListenable: pauseAfterCompleted,
                      builder: (_, value, _) {
                        return MySwitch(
                          value: value,
                          onToggle: (value) {
                            tryVibrate();
                            pauseAfterCompleted.value = value;
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : SizedBox();
    },
  );
}

class SettingsList extends StatelessWidget {
  const SettingsList({super.key});

  Widget paddingForDesktop(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(10),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }

  Widget reloadListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(
        reloadImage,
        color: iconColor,
        size: isMobile ? 30 : null,
      ),
      title: Text(l10n.reload),
      onTap: () async {
        if (await showConfirmDialog(context, l10n.reload)) {
          await libraryLoader.reload();
        }
      },
    );
  }

  Widget selectMusicFoldersListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: ImageIcon(
        folderImage,
        color: iconColor,
        size: isMobile ? 30 : null,
      ),
      title: Text(l10n.selectMusicFolder),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: commonColor,
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                height: 400,
                width: isMobile ? 300 : 400,

                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Text(
                      l10n.folders,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: foldersChangeNotifier,
                        builder: (_, _, _) {
                          return ListView.builder(
                            itemCount: folderPaths.length,
                            itemBuilder: (_, index) {
                              return ListTile(
                                title: Text(folderPaths[index]),
                                contentPadding: EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  10,
                                  0,
                                ),

                                trailing: IconButton(
                                  onPressed: () {
                                    libraryLoader.removeFolder(
                                      folderPaths[index],
                                    );
                                  },
                                  icon: Icon(Icons.clear_rounded),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            String? result = await FilePicker.platform
                                .getDirectoryPath();
                            if (result == null) {
                              return;
                            }

                            if (Platform.isIOS) {
                              if (result.contains(appDocs.path)) {
                                result = result.substring(
                                  result.indexOf('Documents'),
                                );
                                result = result.replaceFirst(
                                  'Documents',
                                  'Particle Music',
                                );
                              } else if (context.mounted) {
                                showCenterMessage(
                                  context,
                                  'No access permission',
                                  duration: 2000,
                                );
                                return;
                              }
                            }
                            if (folderPaths.contains(result) &&
                                context.mounted) {
                              showCenterMessage(
                                context,
                                'The folder already exists',
                                duration: 2000,
                              );
                              return;
                            }
                            libraryLoader.addFolder(result);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.all(10),
                          ),
                          child: Text(l10n.addFolder),
                        ),
                        SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.all(10),
                          ),
                          child: Text(l10n.complete),
                        ),
                        Spacer(),
                      ],
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget languageListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(
        languageImage,
        color: iconColor,
        size: isMobile ? 30 : null,
      ),
      title: Text(l10n.language),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: commonColor,
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                height: 300,
                width: 100,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ValueListenableBuilder(
                    valueListenable: localeNotifier,
                    builder: (context, value, child) {
                      final l10n = AppLocalizations.of(context);

                      return ListView(
                        children: [
                          ListTile(
                            title: Text(l10n.followSystem),
                            onTap: () {
                              localeNotifier.value = null;
                              setting.saveSetting();
                            },
                            trailing: value == null ? Icon(Icons.check) : null,
                          ),
                          ListTile(
                            title: Text('English'),
                            onTap: () {
                              localeNotifier.value = Locale('en');
                              setting.saveSetting();
                            },
                            trailing: value == Locale('en')
                                ? Icon(Icons.check)
                                : null,
                          ),
                          ListTile(
                            title: Text('中文'),
                            onTap: () {
                              localeNotifier.value = Locale('zh');
                              setting.saveSetting();
                            },
                            trailing: value == Locale('zh')
                                ? Icon(Icons.check)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget colorListTile(BuildContext context, AppLocalizations l10n, int type) {
    return ValueListenableBuilder(
      valueListenable: colorChangeNotifier,
      builder: (context, value, child) {
        String title;
        Color pikerColor;
        switch (type) {
          case 0:
            title = l10n.iconColor;
            pikerColor = customIconColor;
            break;
          case 1:
            title = l10n.textColor;
            pikerColor = customTextColor;
            break;
          case 2:
            title = l10n.switchColor;
            pikerColor = customSwitchColor;
            break;
          case 3:
            title = l10n.panelColor;
            pikerColor = customPanelColor;
            break;
          case 4:
            title = l10n.sidebarColor;
            pikerColor = customSidebarColor;
            break;
          default:
            title = l10n.bottomColor;
            pikerColor = customBottomColor;
            break;
        }
        return ListTile(
          title: Text(title),
          trailing: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
            child: Material(
              elevation: 3,
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: BorderRadius.circular(3),
              ),
              child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: SmoothClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(height: 35, width: 35, color: pikerColor),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AlertDialog(
                      backgroundColor: commonColor,
                      title: Text(title),
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          color: pikerColor,
                          pickersEnabled: const {
                            ColorPickerType.wheel: true, // 色轮
                            ColorPickerType.accent: false,
                            ColorPickerType.primary: false,
                          },
                          showColorCode: true,
                          colorCodeHasColor: true,
                          enableOpacity: true,
                          opacityTrackHeight: 15,
                          onColorChanged: (color) {
                            switch (type) {
                              case 0:
                                customIconColor = color;
                                break;
                              case 1:
                                customTextColor = color;
                                break;
                              case 2:
                                customSwitchColor = color;
                                break;
                              case 3:
                                customPanelColor = color;
                                break;
                              case 4:
                                customSidebarColor = color;
                                break;
                              default:
                                customBottomColor = color;
                            }
                            setting.setColor();
                            colorChangeNotifier.value++;
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setting.saveSetting();
                            Navigator.pop(context);
                          },
                          child: Text(
                            l10n.confirm,
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget paletteListTile(BuildContext context, AppLocalizations l10n) {
    return Theme(
      data: Theme.of(context).copyWith(
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ListTile(
        leading: ImageIcon(
          paletteImage,
          color: iconColor,
          size: isMobile ? 30 : null,
        ),
        title: Text(l10n.palette),
        onTap: () async {
          showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                backgroundColor: commonColor,
                shape: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox(
                  height: isMobile ? 250 : 400,
                  width: 300,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: Column(
                      children: [
                        if (!isMobile)
                          ListTile(
                            title: Text(l10n.customMode),
                            trailing: SizedBox(
                              width: 45,
                              child: ValueListenableBuilder(
                                valueListenable: enableCustomColorNotifier,
                                builder: (context, enableCustomColor, child) {
                                  return MouseRegion(
                                    cursor: SystemMouseCursors.click,

                                    child: ValueListenableBuilder(
                                      valueListenable: colorChangeNotifier,
                                      builder: (context, value, child) {
                                        return MySwitch(
                                          value: enableCustomColor,
                                          onToggle: (value) {
                                            enableCustomColorNotifier.value =
                                                value;
                                            setting.setColor();
                                            colorChangeNotifier.value++;
                                            setting.saveSetting();
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                        colorListTile(context, l10n, 0),
                        colorListTile(context, l10n, 1),
                        colorListTile(context, l10n, 2),
                        if (!isMobile) colorListTile(context, l10n, 3),
                        if (!isMobile) colorListTile(context, l10n, 4),
                        if (!isMobile) colorListTile(context, l10n, 5),

                        ListTile(
                          title: Text(l10n.reset),
                          onTap: () {
                            customIconColor = Colors.black;
                            customTextColor = Colors.black;
                            customSwitchColor = Colors.black87;
                            customPanelColor = Colors.grey.shade100;
                            customSidebarColor = Color.fromARGB(
                              255,
                              240,
                              240,
                              240,
                            );
                            customBottomColor = Colors.grey.shade50;
                            setting.setColor();
                            colorChangeNotifier.value++;
                            setting.saveSetting();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 64,
              child: Center(
                child: ListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    size: 35,
                    color: iconColor,
                  ),
                  title: Text(
                    l10n.settings,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

        if (!isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder(
              valueListenable: colorChangeNotifier,
              builder: (_, _, _) {
                return ValueListenableBuilder(
                  valueListenable: currentSongNotifier,
                  builder: (_, _, _) {
                    return Divider(
                      thickness: 0.5,
                      height: 1,
                      color: enableCustomColorNotifier.value
                          ? dividerColor
                          : coverArtAverageColor,
                    );
                  },
                );
              },
            ),
          ),

        if (!isMobile) SizedBox(height: 10),

        isMobile
            ? ListTile(
                leading: ImageIcon(infoImage, color: iconColor, size: 30),
                title: Text(
                  l10n.openSourceLicense,
                  style: TextStyle(fontSize: 15),
                ),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => Theme(
                        data: ThemeData(
                          colorScheme: ColorScheme.light(
                            surface: Colors
                                .grey
                                .shade50, // <- this is what LicensePage uses
                          ),
                          appBarTheme: const AppBarTheme(
                            scrolledUnderElevation: 0,
                            centerTitle: true,
                          ),
                        ),
                        child: const LicensePage(
                          applicationName: 'Particle Music',
                          applicationVersion: '1.0.6',
                          applicationLegalese: '© 2025-2026 AfalpHy',
                        ),
                      ),
                    ),
                  );
                },
              )
            : paddingForDesktop(
                ListTile(
                  leading: ImageIcon(infoImage, color: iconColor),
                  title: Text(
                    l10n.openSourceLicense,
                    style: TextStyle(fontSize: 15),
                  ),
                  onTap: () {
                    panelManager.pushPanel(-2);
                  },
                ),
              ),

        isMobile
            ? selectMusicFoldersListTile(context, l10n)
            : paddingForDesktop(selectMusicFoldersListTile(context, l10n)),

        isMobile
            ? reloadListTile(context, l10n)
            : paddingForDesktop(reloadListTile(context, l10n)),

        isMobile
            ? languageListTile(context, l10n)
            : paddingForDesktop(languageListTile(context, l10n)),

        if (isMobile)
          ListTile(
            leading: ImageIcon(vibrationImage, color: iconColor, size: 30),
            title: Text(l10n.vibration),
            trailing: ValueListenableBuilder(
              valueListenable: vibrationOnNoitifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 50,
                  child: MySwitch(
                    value: value,
                    onToggle: (value) {
                      tryVibrate();
                      vibrationOnNoitifier.value = value;
                      setting.saveSetting();
                    },
                  ),
                );
              },
            ),
          ),

        if (isMobile) sleepTimerListTile(context, l10n, true),

        if (isMobile) pauseAfterCTListTile(context, l10n),

        isMobile
            ? paletteListTile(context, l10n)
            : paddingForDesktop(paletteListTile(context, l10n)),
      ],
    );
  }
}
