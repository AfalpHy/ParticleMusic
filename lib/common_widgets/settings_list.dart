import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:particle_music/common.dart';
import 'package:particle_music/mobile/sleep_timer.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsList extends StatelessWidget {
  const SettingsList({super.key});

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
            child: Divider(thickness: 0.5, height: 1, color: dividerColor),
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
                          applicationVersion: versionNumber,
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
                    panelManager.pushPanel('licenses');
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
                      settingManager.saveSetting();
                    },
                  ),
                );
              },
            ),
          ),

        if (isMobile) sleepTimerListTile(context, l10n, true),

        if (isMobile) pauseAfterCTListTile(context, l10n),

        isMobile ? themeListTile(l10n) : paddingForDesktop(themeListTile(l10n)),

        isMobile
            ? paletteListTile(context, l10n)
            : paddingForDesktop(paletteListTile(context, l10n)),

        if (!isMobile) paddingForDesktop(exitOnClose(l10n)),

        if (Platform.isAndroid) desktopLyricsOnAndroid(l10n),

        if (Platform.isAndroid) orientation(l10n),

        if (Platform.isAndroid) lockAndUnlock(l10n),

        isMobile
            ? checkUpdate(context, l10n)
            : paddingForDesktop(checkUpdate(context, l10n)),

        if (isMobile) SizedBox(height: 100),
      ],
    );
  }

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
          await libraryManager.reload();
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
            final currentFolderList = folderManager.folderList
                .map((e) => e.path)
                .toList();
            final updateNotifier = ValueNotifier(0);
            final buttonStyle = ElevatedButton.styleFrom(
              backgroundColor: Colors.white70,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: EdgeInsets.all(10),
            );
            return Dialog(
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
                        valueListenable: updateNotifier,
                        builder: (_, _, _) {
                          return ListView.builder(
                            itemCount: currentFolderList.length,
                            itemBuilder: (_, index) {
                              return ListTile(
                                title: Text(currentFolderList[index]),
                                contentPadding: EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  5,
                                  0,
                                ),

                                trailing: IconButton(
                                  onPressed: () {
                                    currentFolderList.removeAt(index);
                                    updateNotifier.value++;
                                  },
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: iconColor,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: .start,
                          children: [
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
                                if (currentFolderList.contains(result) &&
                                    context.mounted) {
                                  showCenterMessage(
                                    context,
                                    'The folder already exists',
                                    duration: 2000,
                                  );
                                  return;
                                }
                                currentFolderList.add(result);
                                updateNotifier.value++;
                              },
                              style: buttonStyle,
                              child: Text(l10n.addFolder),
                            ),

                            if (!isMobile) SizedBox(height: 5),

                            ElevatedButton(
                              onPressed: () async {
                                String? result = await FilePicker.platform
                                    .getDirectoryPath();
                                if (result == null) {
                                  return;
                                }

                                if (Platform.isIOS &&
                                    !result.contains(appDocs.path)) {
                                  if (context.mounted) {
                                    showCenterMessage(
                                      context,
                                      'No access permission',
                                      duration: 2000,
                                    );
                                    return;
                                  }
                                }

                                Directory root = Directory(result);

                                List<String> folderList = root
                                    .listSync(recursive: true)
                                    .whereType<Directory>()
                                    .map((d) => d.path)
                                    .toList();

                                folderList.insert(0, result);

                                for (String folder in folderList) {
                                  folder = convertDirectoryPathIfNeed(folder);
                                  if (!currentFolderList.contains(folder)) {
                                    currentFolderList.add(folder);
                                  }
                                }

                                updateNotifier.value++;
                              },
                              style: buttonStyle,
                              child: Text(l10n.addRecursiveFolder),
                            ),
                          ],
                        ),
                        Spacer(),
                        Column(
                          crossAxisAlignment: .end,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                              },
                              style: buttonStyle,
                              child: Text(l10n.cancel),
                            ),

                            if (!isMobile) SizedBox(height: 5),

                            ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                if (await folderManager.updateFolders(
                                  currentFolderList,
                                )) {
                                  libraryManager.reload();
                                }
                              },
                              style: buttonStyle,
                              child: Text(l10n.confirm),
                            ),
                          ],
                        ),
                        SizedBox(width: 20),
                      ],
                    ),

                    SizedBox(height: 15),
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
                              settingManager.saveSetting();
                            },
                            trailing: value == null ? Icon(Icons.check) : null,
                          ),
                          ListTile(
                            title: Text('English'),
                            onTap: () {
                              localeNotifier.value = Locale('en');
                              settingManager.saveSetting();
                            },
                            trailing: value == Locale('en')
                                ? Icon(Icons.check)
                                : null,
                          ),
                          ListTile(
                            title: Text('中文'),
                            onTap: () {
                              localeNotifier.value = Locale('zh');
                              settingManager.saveSetting();
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

  Widget themeListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(
        themeImage,
        color: iconColor,
        size: isMobile ? 30 : null,
      ),

      title: Text(l10n.theme),
      trailing: SizedBox(
        width: 150,
        child: ValueListenableBuilder(
          valueListenable: darkModeNotifier,
          builder: (context, value, child) {
            return Row(
              children: [
                Spacer(),
                Text(value ? l10n.darkMode : l10n.lightMode),
                SizedBox(width: 10),
                MySwitch(
                  value: value,
                  onToggle: (value) async {
                    darkModeNotifier.value = value;
                    settingManager.saveSetting();
                    settingManager.setColor();
                    updateColorNotifier.value++;
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget colorListTile(BuildContext context, AppLocalizations l10n, int type) {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
      builder: (context, value, child) {
        String title;
        Color pikerColor;
        switch (type) {
          case 0:
            title = l10n.backgroundColor;
            pikerColor = customPageBackgroundColor;
            break;
          case 1:
            title = l10n.iconColor;
            pikerColor = customIconColor;
            break;
          case 2:
            title = l10n.textColor;
            pikerColor = customTextColor;
            break;
          case 3:
            title = l10n.highlightTextColor;
            pikerColor = customHighlightTextColor;
            break;
          case 4:
            title = l10n.switchColor;
            pikerColor = customSwitchColor;
            break;
          case 44:
            title = l10n.playBarColor;
            pikerColor = customPlayBarColor;
            break;
          case 5:
            title = l10n.panelColor;
            pikerColor = customPanelColor;
            break;
          case 6:
            title = l10n.sidebarColor;
            pikerColor = customSidebarColor;
            break;
          case 7:
            title = l10n.bottomColor;
            pikerColor = customBottomColor;
            break;
          case 8:
            title = l10n.searchFieldColor;
            pikerColor = customSearchFieldColor;
            break;
          case 9:
            title = l10n.buttonColor;
            pikerColor = customButtonColor;
            break;
          case 10:
            title = l10n.dividerColor;
            pikerColor = customDividerColor;
            break;
          case 11:
            title = l10n.selectedItemColor;
            pikerColor = customSelectedItemColor;
            break;
          case 12:
            title = l10n.seekBarColor;
            pikerColor = customSeekBarColor;
            break;
          case 13:
            title = l10n.volumeBarColor;
            pikerColor = customVolumeBarColor;
            break;
          default:
            title = l10n.lyricsBackgroundColor;
            pikerColor = lyricsBackgroundColor;
            break;
        }
        return ListTile(
          title: Text(title),
          trailing: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
            child: Material(
              color: Colors.transparent,
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
                  Color tmpColor = pikerColor;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(title),
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          color: pikerColor,
                          pickersEnabled: const {
                            ColorPickerType.wheel: true,
                            ColorPickerType.accent: false,
                            ColorPickerType.primary: false,
                          },
                          showColorCode: true,
                          colorCodeHasColor: true,
                          enableOpacity: true,
                          opacityTrackHeight: 15,
                          onColorChanged: (color) {
                            tmpColor = color;
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            l10n.cancel,
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            switch (type) {
                              case 0:
                                customPageBackgroundColor = tmpColor;
                                break;
                              case 1:
                                customIconColor = tmpColor;
                                break;
                              case 2:
                                customTextColor = tmpColor;
                                break;
                              case 3:
                                customHighlightTextColor = tmpColor;
                                break;
                              case 4:
                                customSwitchColor = tmpColor;
                                break;
                              case 44:
                                customPlayBarColor = tmpColor;
                                break;
                              case 5:
                                customPanelColor = tmpColor;
                                break;
                              case 6:
                                customSidebarColor = tmpColor;
                                break;
                              case 7:
                                customBottomColor = tmpColor;
                                break;
                              case 8:
                                customSearchFieldColor = tmpColor;
                                break;
                              case 9:
                                customButtonColor = tmpColor;
                                break;
                              case 10:
                                customDividerColor = tmpColor;
                                break;
                              case 11:
                                customSelectedItemColor = tmpColor;
                                break;
                              case 12:
                                customSeekBarColor = tmpColor;
                                break;
                              case 13:
                                customVolumeBarColor = tmpColor;
                                break;
                              default:
                                lyricsBackgroundColor = tmpColor;
                                break;
                            }
                            settingManager.setColor();
                            updateColorNotifier.value++;
                            settingManager.saveSetting();
                            Navigator.pop(context);
                          },
                          child: Text(
                            l10n.confirm,
                            style: TextStyle(color: textColor),
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
    return ListTile(
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
              shape: SmoothRectangleBorder(
                smoothness: 1,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox(
                height: isMobile ? 350 : 400,
                width: isMobile ? 240 : 350,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: ListView(
                    children: [
                      ListTile(
                        title: Text(l10n.customMode),
                        trailing: SizedBox(
                          width: 45,
                          child: ValueListenableBuilder(
                            valueListenable: enableCustomColorNotifier,
                            builder: (context, enableCustomColor, child) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,

                                child: MySwitch(
                                  value: enableCustomColor,
                                  onToggle: (value) {
                                    enableCustomColorNotifier.value = value;
                                    settingManager.setColor();
                                    updateColorNotifier.value++;
                                    settingManager.saveSetting();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      if (isMobile) colorListTile(context, l10n, 0),
                      colorListTile(context, l10n, 1),
                      colorListTile(context, l10n, 2),
                      colorListTile(context, l10n, 3),
                      colorListTile(context, l10n, 4),
                      if (isMobile) colorListTile(context, l10n, 44),

                      if (!isMobile) colorListTile(context, l10n, 5),
                      if (!isMobile) colorListTile(context, l10n, 6),
                      if (!isMobile) colorListTile(context, l10n, 7),
                      if (!isMobile) colorListTile(context, l10n, 8),
                      if (!isMobile) colorListTile(context, l10n, 9),
                      if (!isMobile) colorListTile(context, l10n, 10),
                      if (!isMobile) colorListTile(context, l10n, 11),
                      if (!isMobile) colorListTile(context, l10n, 12),
                      if (!isMobile) colorListTile(context, l10n, 13),

                      ListTile(
                        title: Text(l10n.lyricsCustomMode),
                        trailing: SizedBox(
                          width: 45,
                          child: ValueListenableBuilder(
                            valueListenable: enableCustomLyricsPageNotifier,
                            builder: (context, enableCustomLyricsPage, child) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,

                                child: MySwitch(
                                  value: enableCustomLyricsPage,
                                  onToggle: (value) {
                                    enableCustomLyricsPageNotifier.value =
                                        value;
                                    settingManager.setColor();
                                    updateColorNotifier.value++;
                                    settingManager.saveSetting();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      colorListTile(context, l10n, 14),

                      ListTile(
                        title: Text(l10n.reset),
                        onTap: () {
                          customPageBackgroundColor = Color.fromARGB(
                            255,
                            245,
                            245,
                            245,
                          );
                          customIconColor = Colors.black;
                          customTextColor = Color.fromARGB(255, 30, 30, 30);
                          customHighlightTextColor = Colors.black;
                          customSwitchColor = Colors.black87;
                          customPlayBarColor = Colors.white70;
                          customPanelColor = Colors.grey.shade100;
                          customSidebarColor = Colors.grey.shade200;
                          customBottomColor = Colors.grey.shade50;
                          customSearchFieldColor = Colors.white;
                          customButtonColor = Colors.white70;
                          customDividerColor = Colors.grey;
                          customSelectedItemColor = Colors.white;
                          customSeekBarColor = Colors.black;
                          customVolumeBarColor = Colors.black;

                          lyricsBackgroundColor = Colors.black;

                          settingManager.setColor();
                          updateColorNotifier.value++;
                          settingManager.saveSetting();
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
    );
  }

  Widget desktopLyricsOnAndroid(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(desktopLyricsImage, color: iconColor, size: 30),
      title: Text(l10n.desktopLyrics),
      trailing: ValueListenableBuilder(
        valueListenable: showDesktopLrcOnAndroidNotifier,
        builder: (context, value, child) {
          return SizedBox(
            width: 50,
            child: MySwitch(
              value: value,
              onToggle: (value) async {
                tryVibrate();
                lockDesktopLrcOnAndroidNotifier.value = false;
                if (!value) {
                  showDesktopLrcOnAndroidNotifier.value = value;
                  await FlutterOverlayWindow.closeOverlay();
                  return;
                }
                if (!await FlutterOverlayWindow.isPermissionGranted()) {
                  final res = await FlutterOverlayWindow.requestPermission();
                  if (res == false) {
                    return;
                  }
                }
                showDesktopLrcOnAndroidNotifier.value = value;
                final vertical = verticalDesktopLrcNotifier.value;
                await FlutterOverlayWindow.showOverlay(
                  enableDrag: true,

                  flag: OverlayFlag.defaultFlag,
                  visibility: NotificationVisibility.visibilityPublic,
                  positionGravity: PositionGravity.none,
                  height: vertical ? 2000 : 200,
                  width: vertical ? 200 : 1200,
                );

                await updateDesktopLyrics();
                await FlutterOverlayWindow.shareData(isPlayingNotifier.value);
              },
            ),
          );
        },
      ),
    );
  }

  Widget orientation(AppLocalizations l10n) {
    return ValueListenableBuilder(
      valueListenable: showDesktopLrcOnAndroidNotifier,
      builder: (context, value, child) {
        if (!value) {
          return SizedBox.shrink();
        }
        return ListTile(
          trailing: SizedBox(
            width: 150,
            child: ValueListenableBuilder(
              valueListenable: verticalDesktopLrcNotifier,
              builder: (context, value, child) {
                return Row(
                  children: [
                    Spacer(),
                    Text(value ? l10n.vertical : l10n.horizontal),
                    SizedBox(width: 10),
                    MySwitch(
                      value: value,
                      onToggle: (value) async {
                        tryVibrate();
                        verticalDesktopLrcNotifier.value = value;
                        await FlutterOverlayWindow.closeOverlay();

                        final vertical = verticalDesktopLrcNotifier.value;

                        await FlutterOverlayWindow.showOverlay(
                          enableDrag: true,

                          flag: lockDesktopLrcOnAndroidNotifier.value
                              ? .clickThrough
                              : .defaultFlag,
                          visibility: NotificationVisibility.visibilityPublic,
                          positionGravity: PositionGravity.none,

                          height: vertical ? 2000 : 200,
                          width: vertical ? 200 : 1200,
                        );

                        await FlutterOverlayWindow.shareData(value ? 1 : 0);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget lockAndUnlock(AppLocalizations l10n) {
    return ValueListenableBuilder(
      valueListenable: showDesktopLrcOnAndroidNotifier,
      builder: (context, value, child) {
        if (!value) {
          return SizedBox.shrink();
        }
        return ListTile(
          trailing: SizedBox(
            width: 150,
            child: ValueListenableBuilder(
              valueListenable: lockDesktopLrcOnAndroidNotifier,
              builder: (context, value, child) {
                return Row(
                  children: [
                    Spacer(),
                    Text(value ? l10n.unlock : l10n.lock),
                    SizedBox(width: 10),
                    MySwitch(
                      value: value,
                      onToggle: (value) async {
                        tryVibrate();
                        lockDesktopLrcOnAndroidNotifier.value = value;
                        final position =
                            await FlutterOverlayWindow.getOverlayPosition();

                        await FlutterOverlayWindow.closeOverlay();
                        final vertical = verticalDesktopLrcNotifier.value;

                        await FlutterOverlayWindow.showOverlay(
                          enableDrag: true,

                          flag: value ? .clickThrough : .defaultFlag,
                          visibility: NotificationVisibility.visibilityPublic,
                          positionGravity: PositionGravity.none,

                          startPosition: position,
                          height: vertical ? 2000 : 200,
                          width: vertical ? 200 : 1200,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget exitOnClose(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(powerOffImage, color: iconColor),

      title: Text(l10n.closeAction),
      trailing: SizedBox(
        width: 150,
        child: ValueListenableBuilder(
          valueListenable: exitOnCloseNotifier,
          builder: (context, value, child) {
            return Row(
              children: [
                Spacer(),
                Text(value ? l10n.exit : l10n.hide),
                SizedBox(width: 10),
                MySwitch(
                  value: value,
                  onToggle: (value) async {
                    exitOnCloseNotifier.value = value;
                    settingManager.saveSetting();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _compareVersion(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();

    final length = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (int i = 0; i < length; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;

      if (aVal != bVal) {
        return aVal.compareTo(bVal);
      }
    }
    return 0;
  }

  Widget checkUpdate(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(
        checkUpdateImage,
        color: iconColor,
        size: isMobile ? 30 : null,
      ),
      title: Text(l10n.checkUpdate),
      onTap: () async {
        final url = Uri.parse(
          'https://api.github.com/repos/AfalpHy/ParticleMusic/releases/latest',
        );

        final response = await http.get(url);

        if (response.statusCode != 200) {
          if (context.mounted) {
            showCenterMessage(context, 'Failed to fetch GitHub release');
          }
        }

        final data = jsonDecode(response.body);
        String latestVersion = (data['tag_name'] as String).replaceFirst(
          'v',
          '',
        );
        if (_compareVersion(latestVersion, versionNumber) > 0) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  content: SizedBox(
                    height: 300,
                    width: 400,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListView(
                        children: [
                          Center(
                            child: Text(
                              data['tag_name'] as String,
                              style: TextStyle(fontSize: 20, fontWeight: .bold),
                            ),
                          ),
                          SizedBox(height: 10),

                          Text(data['body'] as String),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        elevation: 2,
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
                    ElevatedButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          "https://github.com/AfalpHy/ParticleMusic/releases/latest",
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 2,
                        backgroundColor: buttonColor,
                        shadowColor: Colors.black54,
                        foregroundColor: Colors.black,
                        shape: SmoothRectangleBorder(
                          smoothness: 1,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(l10n.go2Download),
                    ),
                  ],
                );
              },
            );
          }
        } else {
          if (context.mounted) {
            showCenterMessage(context, l10n.alreadyLatest, duration: 2000);
          }
        }
      },
    );
  }
}
