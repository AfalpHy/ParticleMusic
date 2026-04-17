import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/equalizer.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/common_widgets/manage_music_folders.dart';
import 'package:particle_music/loader.dart';
import 'package:particle_music/portrait_view/sleep_timer.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/navidrome_client.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webdav_client/webdav_client.dart';

class SettingsList extends StatelessWidget {
  final double? iconSize;
  const SettingsList({super.key, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    bool isLandscape = MediaQuery.of(context).orientation == .landscape;
    return CustomScrollView(
      slivers: [
        if (isLandscape)
          sliverBox(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: ListTile(
                leading: ImageIcon(settingImage, size: 50),
                title: Text(
                  l10n.settings,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  l10n.settingCount(
                    Platform.isAndroid
                        ? 16
                        : Platform.isIOS
                        ? 14
                        : 13,
                  ),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),

        if (isLandscape)
          sliverBox(
            ValueListenableBuilder(
              valueListenable: updateColorNotifier,
              builder: (context, value, child) {
                return Divider(
                  thickness: 0.5,
                  height: 0.5,
                  indent: 20,
                  endIndent: 20,
                  color: dividerColor,
                );
              },
            ),
          ),

        if (isLandscape) sliverBox(const SizedBox(height: 10)),

        sliverBox(
          paddingIfNeed(
            isLandscape,
            ListTile(
              leading: ImageIcon(
                infoImage,
                size: isLandscape ? null : iconSize,
              ),
              title: Text(l10n.openSourceLicense),
              onTap: () {
                layersManager.pushLayer('licenses');
              },
            ),
          ),
        ),

        sliverBox(
          paddingIfNeed(isLandscape, selectMusicFoldersListTile(context, l10n)),
        ),
        sliverBox(paddingIfNeed(isLandscape, navidromeListTile(context, l10n))),
        sliverBox(paddingIfNeed(isLandscape, webdavListTile(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, reloadListTile(context, l10n))),

        sliverBox(
          paddingIfNeed(isLandscape, cleanCacheListTile(context, l10n)),
        ),

        sliverBox(paddingIfNeed(isLandscape, languageListTile(context, l10n))),

        if (isMobile)
          sliverBox(paddingIfNeed(isLandscape, vibrationListTile(l10n))),

        if (isMobile)
          sliverBox(
            paddingIfNeed(
              isLandscape,
              sleepTimerListTile(context, l10n, true, iconSize: iconSize),
            ),
          ),

        if (isMobile)
          sliverBox(
            paddingIfNeed(isLandscape, pauseAfterCTListTile(context, l10n)),
          ),

        sliverBox(paddingIfNeed(isLandscape, themeListTile(context, l10n))),
        sliverBox(paddingIfNeed(isLandscape, paletteListTile(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, equalizerListTile(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, autoPlayOnStartupListTile(l10n))),

        if (!isMobile)
          sliverBox(
            paddingForLandscape(exitOnClose(l10n)),
          ), // always landscape style

        if (Platform.isAndroid)
          sliverBox(paddingIfNeed(isLandscape, desktopLyricsOnAndroid(l10n))),

        if (Platform.isAndroid)
          sliverBox(paddingIfNeed(isLandscape, lockAndUnlock(l10n))),

        sliverBox(paddingIfNeed(isLandscape, checkUpdate(context, l10n))),

        if (Platform.isAndroid)
          sliverBox(
            paddingIfNeed(isLandscape, exportLogListTile(context, l10n)),
          ),

        if (!isLandscape) sliverBox(const SizedBox(height: 100)),
      ],
    );
  }

  Widget paddingIfNeed(bool isLandscape, Widget child) {
    return isLandscape ? paddingForLandscape(child) : child;
  }

  Widget sliverBox(Widget child) => SliverToBoxAdapter(child: child);

  Widget paddingForLandscape(Widget child) {
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
      leading: ImageIcon(reloadImage, size: iconSize),
      title: Text(l10n.reload),
      onTap: () async {
        if (await showConfirmDialog(context, l10n.reload)) {
          await Loader.reload();
        }
      },
    );
  }

  Widget selectMusicFoldersListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: ImageIcon(folderImage, size: iconSize),
      title: Text(l10n.manageMusicFolder),
      onTap: () {
        showAnimationDialog(context: context, child: ManageMusicFolders());
      },
    );
  }

  Widget navidromeListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(navidromeImage, size: iconSize),
      title: Text(l10n.connect2Navidrome),
      onTap: () {
        final usernameTmp = TextEditingController(text: username);
        final passwordTmp = TextEditingController(text: password);
        final baseUrlTmp = TextEditingController(text: baseUrl);

        showAnimationDialog(
          context: context,
          child: SizedBox(
            height: 300,
            width: 300,
            child: Padding(
              padding: .fromLTRB(20, 15, 20, 15),
              child: Column(
                children: [
                  Spacer(),
                  SizedBox(
                    child: Text(
                      'Navidrome',
                      style: .new(fontWeight: .bold, fontSize: 18),
                    ),
                  ),

                  SizedBox(height: 10),

                  adaptiveTextField(context, l10n.username, usernameTmp),

                  SizedBox(height: 10),

                  adaptiveTextField(context, l10n.password, passwordTmp),

                  SizedBox(height: 10),
                  adaptiveTextField(context, 'Url', baseUrlTmp),

                  SizedBox(height: isMobile ? 10 : 20),
                  Builder(
                    builder: (context) {
                      return Row(
                        children: [
                          Spacer(),
                          ElevatedButton(
                            onPressed: () async {
                              if (!await showConfirmDialog(
                                context,
                                l10n.clear,
                              )) {
                                return;
                              }
                              username = '';
                              password = '';
                              baseUrl = '';
                              settingManager.saveSetting();
                              navidromeClient = NavidromeClient(
                                username: username,
                                password: password,
                                baseUrl: baseUrl,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              Loader.reload();
                            },
                            child: Text(l10n.clear),
                          ),
                          SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: () async {
                              final tmp = navidromeClient;
                              try {
                                navidromeClient = NavidromeClient(
                                  username: usernameTmp.text,
                                  password: passwordTmp.text,
                                  baseUrl: baseUrlTmp.text,
                                );
                              } catch (e) {
                                navidromeClient = tmp;
                                showCenterMessage(
                                  context,
                                  e.toString(),
                                  duration: 5000,
                                );
                                return;
                              }
                              if (await navidromeClient.ping()) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                username = usernameTmp.text;
                                password = passwordTmp.text;
                                baseUrl = baseUrlTmp.text;
                                settingManager.saveSetting();

                                await Loader.reload();
                              } else {
                                navidromeClient = tmp;
                                if (context.mounted) {
                                  showCenterMessage(
                                    context,
                                    "Failed to connect to Navidrome",
                                    duration: 2000,
                                  );
                                }
                              }
                            },
                            child: Text(l10n.confirm),
                          ),
                          Spacer(),
                        ],
                      );
                    },
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget webdavListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(navidromeImage, size: iconSize),
      title: Text(l10n.connect2WebDAV),
      onTap: () {
        final usernameTmp = TextEditingController(text: webdavUsername);
        final passwordTmp = TextEditingController(text: webdavPassword);
        final baseUrlTmp = TextEditingController(text: webdavBaseUrl);

        showAnimationDialog(
          context: context,

          child: SizedBox(
            height: 300,
            width: 300,
            child: Padding(
              padding: .fromLTRB(20, 15, 20, 15),
              child: Column(
                children: [
                  Spacer(),
                  SizedBox(
                    child: Text(
                      'WebDAV',
                      style: .new(fontWeight: .bold, fontSize: 18),
                    ),
                  ),

                  SizedBox(height: 10),

                  adaptiveTextField(context, l10n.username, usernameTmp),

                  SizedBox(height: 10),

                  adaptiveTextField(context, l10n.password, passwordTmp),

                  SizedBox(height: 10),
                  adaptiveTextField(context, 'Url', baseUrlTmp),

                  SizedBox(height: isMobile ? 10 : 20),
                  Builder(
                    builder: (context) {
                      return Row(
                        children: [
                          Spacer(),
                          ElevatedButton(
                            onPressed: () async {
                              if (!await showConfirmDialog(
                                context,
                                l10n.clear,
                              )) {
                                return;
                              }
                              webdavUsername = '';
                              webdavPassword = '';
                              webdavBaseUrl = '';
                              settingManager.saveSetting();
                              webdavClient = null;
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              Loader.reload();
                            },
                            child: Text(l10n.clear),
                          ),
                          SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                await newClient(
                                  baseUrlTmp.text,
                                  user: usernameTmp.text,
                                  password: passwordTmp.text,
                                ).ping();
                                webdavClient = newClient(
                                  baseUrlTmp.text,
                                  user: usernameTmp.text,
                                  password: passwordTmp.text,
                                );
                                webdavUsername = usernameTmp.text;
                                webdavPassword = passwordTmp.text;
                                webdavBaseUrl = baseUrlTmp.text;
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  showCenterMessage(
                                    context,
                                    'Successfully connect to WebDAV',
                                    duration: 2000,
                                  );
                                }
                                settingManager.saveSetting();
                              } catch (e) {
                                if (context.mounted) {
                                  showCenterMessage(
                                    context,
                                    'Can not connect to WebDAV',
                                    duration: 2000,
                                  );
                                }
                              }
                            },
                            child: Text(l10n.confirm),
                          ),
                          Spacer(),
                        ],
                      );
                    },
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget cleanCacheListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(cacheImage, size: iconSize),
      title: Text(l10n.clearCache),
      onTap: () async {
        if (await showConfirmDialog(context, l10n.clear)) {
          library.clearCache();
        }
      },
      trailing: ValueListenableBuilder(
        valueListenable: library.cacheSizeNotifier,
        builder: (context, value, child) {
          // use blank as placeholders
          return Text("${value.toStringAsFixed(1)}MB  ");
        },
      ),
    );
  }

  Widget languageListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(languageImage, size: iconSize),
      title: Text(l10n.language),
      onTap: () {
        showAnimationDialog(
          context: context,

          child: SizedBox(
            width: 300,
            height: 300,
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
  }

  Widget vibrationListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(vibrationImage, size: iconSize),
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
    );
  }

  void _updateMainPageTheme() {
    settingManager.saveSetting();
    colorManager.setMainPageColors();
    updateColorNotifier.value++;
  }

  void _updateLyricsPageTheme() {
    settingManager.saveSetting();
    colorManager.setLyricsPageColors();
    updateColorNotifier.value++;
  }

  Widget themeListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(themeImage, size: iconSize),
      title: Text(l10n.theme),
      onTap: () async {
        mainPageThemeNotifier.addListener(_updateMainPageTheme);
        lyricsPageThemeNotifier.addListener(_updateLyricsPageTheme);
        await showAnimationDialog(
          context: context,

          child: OrientationBuilder(
            builder: (context, orientation) {
              final appHeight = MediaQuery.heightOf(context);

              late double height;
              if (isMobile && orientation == Orientation.portrait) {
                height = 460;
              } else {
                if (isMobile) {
                  height = appHeight > 600 ? 460 : 350;
                } else {
                  height = 400;
                }
              }
              return SizedBox(
                width: 300,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: CustomScrollView(
                    slivers: [
                      sliverBox(
                        ValueListenableBuilder(
                          valueListenable: mainPageThemeNotifier,
                          builder: (context, value, child) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  l10n.mainPageTheme,
                                  style: .new(fontSize: 16),
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = 0;
                                  },
                                  trailing: value == 0
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = 1;
                                  },
                                  trailing: value == 1
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = 2;
                                  },
                                  trailing: value == 2
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.customMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = 3;
                                  },
                                  trailing: value == 3
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      sliverBox(
                        ValueListenableBuilder(
                          valueListenable: lyricsPageThemeNotifier,
                          builder: (context, value, child) {
                            final l10n = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  l10n.lyricsPageTheme,
                                  style: .new(fontSize: 16),
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = 0;
                                  },
                                  trailing: value == 0
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = 1;
                                  },
                                  trailing: value == 1
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = 2;
                                  },
                                  trailing: value == 2
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  dense: true,
                                  title: Text(l10n.customMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = 3;
                                  },
                                  trailing: value == 3
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
        mainPageThemeNotifier.removeListener(_updateMainPageTheme);
        lyricsPageThemeNotifier.removeListener(_updateLyricsPageTheme);
      },
    );
  }

  Widget colorListTile(
    BuildContext context,
    String title,
    AppLocalizations l10n,
    CustomColor customColor,
  ) {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
      builder: (context, value, child) {
        Color pikerColor = customColor.value;
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
                mouseCursor: SystemMouseCursors.click,
                child: SmoothClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(height: 35, width: 35, color: pikerColor),
                ),
                onTap: () {
                  final colorNotifier = ValueNotifier(pikerColor);
                  showAnimationDialog(
                    context: context,

                    child: SizedBox(
                      height: isMobile ? 380 : 430,
                      width: isMobile ? 320 : 400,
                      child: Column(
                        children: [
                          Spacer(),
                          ColorPicker(
                            color: pikerColor,
                            padding: .zero,
                            pickersEnabled: const {
                              ColorPickerType.wheel: true,
                              ColorPickerType.accent: false,
                              ColorPickerType.primary: false,
                            },
                            width: isMobile ? 25 : 30,
                            height: isMobile ? 25 : 30,
                            enableOpacity: true,
                            opacityTrackHeight: 10,
                            opacityThumbRadius: 12,
                            opacityTrackWidth: isMobile ? 310 : 360,
                            wheelDiameter: isMobile ? 160 : 200,
                            onColorChanged: (color) {
                              colorNotifier.value = color;
                            },
                          ),

                          ValueListenableBuilder(
                            valueListenable: colorNotifier,
                            builder: (context, value, child) {
                              return Text(
                                '$title: 0x${value.value32bit.toRadixString(16).toUpperCase().padLeft(8, '0')}',
                              );
                            },
                          ),
                          SizedBox(height: 15),
                          Row(
                            children: [
                              Spacer(),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },

                                child: Text(l10n.cancel),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: () {
                                  customColor.value = colorNotifier.value;
                                  colorManager.setColors();
                                  updateColorNotifier.value++;
                                  settingManager.saveSetting();
                                  Navigator.pop(context);
                                },
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget paletteListTile(BuildContext context, AppLocalizations l10n) {
    final nameMap = colorManager.getNameMap(l10n);
    return ListTile(
      leading: ImageIcon(paletteImage, size: iconSize),
      title: Text(l10n.palette),
      onTap: () async {
        showAnimationDialog(
          context: context,

          child: OrientationBuilder(
            builder: (context, orientation) {
              final size = MediaQuery.of(context).size;
              final shortSide = size.shortestSide;

              bool isPhone = shortSide < 600;
              return SizedBox(
                height: max(350, size.height * 0.7),
                width: isPhone ? 300 : 400,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: ListView(
                    children: [
                      for (final customColor in colorManager.customColors)
                        if (customColor.type == 0 ||
                            (customColor.type == 1 && isMobile) ||
                            (customColor.type == 2 && !isMobile))
                          colorListTile(
                            context,
                            nameMap[customColor.name]!,
                            l10n,
                            customColor,
                          ),

                      ListTile(
                        title: Text(l10n.reset),
                        onTap: () {
                          for (final customColor in colorManager.customColors) {
                            customColor.reset();
                          }
                          colorManager.setColors();
                          updateColorNotifier.value++;
                          settingManager.saveSetting();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget equalizerListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(equalizerImage, size: iconSize),
      title: Text(l10n.equalizer),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: OrientationBuilder(
            builder: (context, orientation) {
              final size = MediaQuery.of(context).size;
              final shortSide = size.shortestSide;

              bool isPhone = shortSide < 600;
              if (isMobile && orientation == .portrait) {
                return SizedBox(
                  height: 500,
                  width: isPhone ? 300 : 400,
                  child: EqualizerWidget(),
                );
              } else {
                return SizedBox(
                  height: isPhone ? 350 : 400,
                  width: 540,
                  child: EqualizerWidget(),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget autoPlayOnStartupListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(playOutlinedImage, size: iconSize),

      title: Text(l10n.autoPlayOnStartup),
      trailing: SizedBox(
        width: 50,
        child: ValueListenableBuilder(
          valueListenable: autoPlayOnStartupNotifier,
          builder: (context, value, child) {
            return MySwitch(
              value: value,
              onToggle: (value) async {
                autoPlayOnStartupNotifier.value = value;
                settingManager.saveSetting();
              },
            );
          },
        ),
      ),
    );
  }

  Widget desktopLyricsOnAndroid(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(desktopLyricsImage, size: iconSize),
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
      leading: ImageIcon(powerOffImage),

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
      leading: ImageIcon(checkUpdateImage, size: iconSize),
      title: Text(l10n.checkUpdate),
      onTap: () async {
        final url = Uri.parse(
          'https://api.github.com/repos/AfalpHy/ParticleMusic/releases/latest',
        );

        try {
          final response = await http
              .get(url)
              .timeout(const Duration(seconds: 3));
          if (response.statusCode != 200) {
            if (context.mounted) {
              showCenterMessage(
                context,
                'Failed to fetch GitHub release:${response.statusCode}',
                duration: 2000,
              );
            }
            return;
          }
          final data = jsonDecode(response.body);
          String latestVersion = (data['tag_name'] as String).replaceFirst(
            'v',
            '',
          );
          if (_compareVersion(latestVersion, versionNumber) > 0) {
            if (context.mounted) {
              showAnimationDialog(
                context: context,

                child: SizedBox(
                  height: isMobile ? 350 : 400,
                  width: isMobile ? 320 : 400,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: ListView(
                              children: [
                                Center(
                                  child: Text(
                                    data['tag_name'] as String,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: .bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),

                                Text(data['body'] as String),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Spacer(),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(l10n.cancel),
                            ),
                            SizedBox(width: 20),
                            ElevatedButton(
                              onPressed: () => launchUrl(
                                Uri.parse(
                                  "https://github.com/AfalpHy/ParticleMusic/releases/latest",
                                ),
                              ),
                              child: Text(l10n.go2Download),
                            ),
                            Spacer(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          } else {
            if (context.mounted) {
              showCenterMessage(context, l10n.alreadyLatest, duration: 2000);
            }
          }
        } catch (e) {
          if (context.mounted) {
            showCenterMessage(
              context,
              'Failed to fetch GitHub release:$e',
              duration: 5000,
            );
          }
        }
      },
    );
  }

  Widget exportLogListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(exportLogImage, size: iconSize),

      title: Text(l10n.exportLog),
      onTap: () async {
        String? result = await FilePicker.platform.getDirectoryPath();
        if (result == null) {
          return;
        }
        logger.export2Directory(result);
      },
    );
  }
}
