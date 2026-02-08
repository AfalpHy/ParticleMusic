import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/mobile/sleep_timer.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/library_manager.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

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
          barrierDismissible: false,
          builder: (context) {
            final currentFolderList = folderManager.folderList
                .map((e) => e.path)
                .toList();
            final updateNotifier = ValueNotifier(0);
            final buttonStyle = ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: EdgeInsets.all(10),
            );
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

  Widget colorListTile(BuildContext context, AppLocalizations l10n, int type) {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
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
          case 5:
            title = l10n.bottomColor;
            pikerColor = customBottomColor;
            break;
          case 6:
            title = l10n.searchFieldColor;
            pikerColor = searchFieldColor;
            break;
          case 7:
            title = l10n.buttonColor;
            pikerColor = buttonColor;
            break;
          case 8:
            title = l10n.dividerColor;
            pikerColor = dividerColor;
            break;
          case 9:
            title = l10n.selectedItemColor;
            pikerColor = selectedItemColor;
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
                              case 5:
                                customBottomColor = color;
                                break;
                              case 6:
                                searchFieldColor = color;
                                break;
                              case 7:
                                buttonColor = color;
                                break;
                              case 8:
                                dividerColor = color;
                                break;
                              case 9:
                                selectedItemColor = color;
                                break;
                              default:
                                lyricsBackgroundColor = color;
                                break;
                            }
                            settingManager.setColor();
                            updateColorNotifier.value++;
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            settingManager.saveSetting();
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
                  height: isMobile ? 350 : 400,
                  width: isMobile ? 240 : 350,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: ListView(
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

                        colorListTile(context, l10n, 0),
                        colorListTile(context, l10n, 1),
                        colorListTile(context, l10n, 2),
                        if (!isMobile) colorListTile(context, l10n, 3),
                        if (!isMobile) colorListTile(context, l10n, 4),
                        if (!isMobile) colorListTile(context, l10n, 5),
                        if (!isMobile) colorListTile(context, l10n, 6),
                        if (!isMobile) colorListTile(context, l10n, 7),
                        if (!isMobile) colorListTile(context, l10n, 8),
                        if (!isMobile) colorListTile(context, l10n, 9),

                        ListTile(
                          title: Text(l10n.lyricsCustomMode),
                          trailing: SizedBox(
                            width: 45,
                            child: ValueListenableBuilder(
                              valueListenable: enableCustomLyricsPageNotifier,
                              builder:
                                  (context, enableCustomLyricsPage, child) {
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

                        colorListTile(context, l10n, 10),

                        ListTile(
                          title: Text(l10n.reset),
                          onTap: () {
                            customIconColor = Colors.black;
                            customTextColor = Colors.black;
                            customSwitchColor = Colors.black87;
                            customPanelColor = Colors.grey.shade100;
                            customSidebarColor = Colors.grey.shade200;
                            customBottomColor = Colors.grey.shade50;

                            searchFieldColor = Colors.white;
                            buttonColor = Colors.white70;
                            dividerColor = Colors.grey;
                            selectedItemColor = Colors.white;

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
      ),
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
            child: Divider(
              thickness: 0.5,
              height: 1,
              color: enableCustomColorNotifier.value
                  ? dividerColor
                  : backgroundColor,
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
                          applicationVersion: '1.0.10',
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

        isMobile
            ? paletteListTile(context, l10n)
            : paddingForDesktop(paletteListTile(context, l10n)),

        if (!isMobile) paddingForDesktop(exitOnClose(l10n)),

        if (Platform.isAndroid) desktopLyricsOnAndroid(l10n),

        if (Platform.isAndroid) orientation(l10n),

        if (Platform.isAndroid) lockAndUnlock(l10n),

        if (isMobile) SizedBox(height: 100),
      ],
    );
  }
}
