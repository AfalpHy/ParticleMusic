import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/system_ui_service.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/utils/format_duration.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/connect_client_widget.dart';
import 'package:sylvakru/base/widgets/equalizer.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/widgets/manage_music_folders.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/layer/premium_layer.dart';
import 'package:sylvakru/portrait_view/sleep_timer.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsList extends StatelessWidget {
  final double? iconSize;
  const SettingsList({super.key, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    bool isLandscape = !isTooNarrow(context);
    return CustomScrollView(
      slivers: [
        if (viewModeNotifier.value == .bigPicture)
          sliverBox(const SizedBox(height: 10)),

        if (isLandscape && viewModeNotifier.value != .bigPicture)
          sliverBox(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: Focus(
                child: ListTile(
                  leading: ImageIcon(settingImage, size: 50),
                  title: Text(
                    l10n.settings,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    l10n.settingCount(
                      Platform.isAndroid
                          ? 15
                          : Platform.isIOS
                          ? 14
                          : 13,
                    ),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

        if (isLandscape && viewModeNotifier.value != .bigPicture)
          sliverBox(
            MyDivider(
              thickness: 0.5,
              height: 0.5,
              indent: 20,
              endIndent: 20,
              color: dividerColor,
            ),
          ),

        if (isLandscape && viewModeNotifier.value != .bigPicture)
          sliverBox(const SizedBox(height: 10)),

        if (Platform.isIOS && viewModeNotifier.value != .bigPicture)
          sliverBox(
            paddingIfNeed(isLandscape, premiumFeaturesListTile(context, l10n)),
          ),

        sliverBox(
          paddingIfNeed(isLandscape, connect2ServerListTile(context, l10n)),
        ),

        sliverBox(
          paddingIfNeed(isLandscape, selectMusicFoldersListTile(context, l10n)),
        ),

        sliverBox(paddingIfNeed(isLandscape, syncListTile(context, l10n))),

        sliverBox(
          paddingIfNeed(isLandscape, cleanCacheListTile(context, l10n)),
        ),

        sliverBox(paddingIfNeed(isLandscape, themeListTile(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, languageListTile(context, l10n))),

        if (viewModeNotifier.value != .bigPicture)
          sliverBox(paddingIfNeed(isLandscape, fontListTile(context, l10n))),

        if (isMobile && !isTV)
          sliverBox(paddingIfNeed(isLandscape, vibrationListTile(l10n))),

        if (isMobile)
          sliverBox(
            paddingIfNeed(
              isLandscape,
              sleepTimerListTile(context, l10n, iconSize: iconSize),
            ),
          ),

        sliverBox(paddingIfNeed(isLandscape, equalizerListTile(context, l10n))),

        if (Platform.isAndroid && !isTV)
          sliverBox(
            paddingIfNeed(isLandscape, immersiveWideLayoutListTile(l10n)),
          ),

        sliverBox(paddingIfNeed(isLandscape, autoPlayOnStartupListTile(l10n))),

        if (!isMobile)
          sliverBox(
            paddingForLandscape(exitOnClose(l10n)),
          ), // always landscape style

        if (!Platform.isIOS)
          sliverBox(paddingIfNeed(isLandscape, checkUpdate(context, l10n))),

        sliverBox(paddingIfNeed(isLandscape, viewLogListTile(context, l10n))),

        if (viewModeNotifier.value != .bigPicture)
          sliverBox(
            paddingIfNeed(
              isLandscape,
              ListTile(
                leading: ImageIcon(infoImage, size: iconSize),
                title: Text(l10n.about),
                onTap: () {
                  layersManager.pushDetail('settings', 'about');
                },
              ),
            ),
          ),

        if (!isLandscape) sliverBox(const SizedBox(height: 100)),

        if (viewModeNotifier.value == .bigPicture)
          sliverBox(const SizedBox(height: 75)),
      ],
    );
  }

  Widget paddingIfNeed(bool isLandscape, Widget child) {
    return isLandscape ? paddingForLandscape(child) : child;
  }

  Widget sliverBox(Widget child) => SliverToBoxAdapter(child: child);

  Widget paddingForLandscape(Widget child) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: viewModeNotifier.value == .bigPicture ? 50 : 30,
      ),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(10),
        child: Material(color: Colors.transparent, child: child),
      ),
    );
  }

  Widget syncListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(reloadImage, size: iconSize),
      title: Text(l10n.syncLibrary),
      onTap: () async {
        final sourceTypes = <SourceType>[];
        if (library.localFolderList.isNotEmpty) {
          sourceTypes.add(.local);
        }
        if (webdavClient != null) {
          sourceTypes.add(.webdav);
        }

        if (subsonicClient != null) {
          sourceTypes.add(.subsonic);
        }

        if (navidromeClient != null) {
          sourceTypes.add(.navidrome);
        }

        if (embyClient != null) {
          sourceTypes.add(.emby);
        }

        if (sourceTypes.isEmpty) {
          return;
        }

        if (sourceTypes.length == 1) {
          if (await showConfirmDialog(context, l10n.syncLibrary)) {
            if (Loader.syncing) {
              if (context.mounted) {
                showCenterMessage(context, l10n.syncingTryLater);
              }
              return;
            }
            await Loader.sync(getSourceTypeBitMask(sourceTypes.first));
          }

          return;
        }

        showAnimationDialog(
          context: context,
          child: SizedBox(
            width: 300,
            height: isMobile ? 300 : 280,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: ListView(
                children: [
                  // get context
                  Builder(
                    builder: (context) {
                      return ListTile(
                        title: Text(l10n.all),
                        onTap: () async {
                          if (await showConfirmDialog(
                            context,
                            l10n.syncLibrary,
                          )) {
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                            if (Loader.syncing) {
                              if (context.mounted) {
                                showCenterMessage(
                                  context,
                                  l10n.syncingTryLater,
                                );
                              }
                              return;
                            }
                            await Loader.sync(15);
                          }
                        },
                      );
                    },
                  ),

                  for (final sourceType in sourceTypes)
                    Builder(
                      builder: (context) {
                        return ListTile(
                          leading: Image(
                            image: getSourceTypeImage(sourceType),
                            width: 30,
                            height: 30,
                          ),
                          title: Text(getSourceTypeName(l10n, sourceType)),
                          onTap: () async {
                            if (await showConfirmDialog(
                              context,
                              l10n.syncLibrary,
                            )) {
                              if (Loader.syncing) {
                                if (context.mounted) {
                                  showCenterMessage(
                                    context,
                                    l10n.syncingTryLater,
                                  );
                                }
                                return;
                              }
                              await Loader.sync(
                                getSourceTypeBitMask(sourceType),
                              );
                            }
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
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

  Widget premiumFeaturesListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(premiumImage, size: iconSize),
      title: Text(l10n.premiumFeatures),
      onTap: () {
        layersManager.pushDetail('settings', 'premium');
      },
      trailing: ValueListenableBuilder(
        valueListenable: trialRemainingMinNotifier,
        builder: (context, value, child) {
          if (value <= 0) {
            return SizedBox.shrink();
          }
          return Row(
            mainAxisSize: .min,
            children: [
              Text(
                "${l10n.trialRemaining}:${formatDuration(Duration(minutes: value), ms: false)}",
              ),
            ],
          );
        },
      ),
    );
  }

  Widget connect2ServerListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(serverImage, size: iconSize),
      title: Text(l10n.connect2Server),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: SizedBox(
            width: 300,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 15,
              ),
              child: Builder(
                builder: (context) {
                  return Column(
                    mainAxisSize: .min,
                    children: [
                      webdavListTile(context, l10n),
                      subsonicListTile(context, l10n),
                      navidromeListTile(context, l10n),
                      embyListTile(context, l10n),
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

  Widget webdavListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Image(
        image: webdavImage,
        width: 30,
        height: 30,
        color: iconColor.value,
      ),

      title: Text(l10n.connect2WebDAV),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: ConnectClientWidget(sourceType: .webdav),
        );
      },
    );
  }

  Widget subsonicListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Image(image: subsonicImage, width: 30, height: 30),
      title: Text(l10n.connect2Subsonic),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: ConnectClientWidget(sourceType: .subsonic),
        );
      },
    );
  }

  Widget navidromeListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Image(image: navidromeImage, width: 30, height: 30),
      title: Text(l10n.connect2Navidrome),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: ConnectClientWidget(sourceType: .navidrome),
        );
      },
    );
  }

  Widget embyListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: Image(image: embyImage, width: 30, height: 30),

      title: Text(l10n.connect2Emby),
      onTap: () {
        showAnimationDialog(
          context: context,
          child: ConnectClientWidget(sourceType: .emby),
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
          for (final sourceType in SourceType.values) {
            await library.clearCache(sourceType);
          }
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
            height: isMobile ? 200 : 180,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
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
                          setting.save();
                        },
                        trailing: value == null ? Icon(Icons.check) : null,
                      ),
                      ListTile(
                        title: Text('English'),
                        onTap: () {
                          localeNotifier.value = Locale('en');
                          setting.save();
                        },
                        trailing: value == Locale('en')
                            ? Icon(Icons.check)
                            : null,
                      ),
                      ListTile(
                        title: Text('中文'),
                        onTap: () {
                          localeNotifier.value = Locale('zh');
                          setting.save();
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
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: vibrationOnNoitifier,
          onToggleCallBack: () {
            setting.save();
          },
        ),
      ),
    );
  }

  void _updateMainPageTheme() {
    setting.save();
    colorManager.updateMainPageColors();
  }

  void _updateLyricsPageTheme() {
    setting.save();
    colorManager.updateLyricsPageColors();
  }

  Widget fontListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(fontImage, size: iconSize),

      title: Text(l10n.fonts),
      onTap: () {
        if (!isPremiumNotifier.value) {
          showPremiumDialog(context);
          return;
        }
        layersManager.pushDetail('settings', 'font_picker');
      },
      trailing: ValueListenableBuilder(
        valueListenable: isPremiumNotifier,
        builder: (context, value, child) {
          if (value) {
            return SizedBox.shrink();
          }
          return Icon(Icons.lock);
        },
      ),
    );
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
              final size = MediaQuery.of(context).size;
              final shortSide = size.shortestSide;

              bool isPhone = shortSide < 600;

              return SizedBox(
                width: 300,
                height: isPhone && orientation == .landscape
                    ? 350
                    : isMobile
                    ? 420
                    : 370,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: CustomScrollView(
                    scrollBehavior: ScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
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
                                  style: .new(fontSize: 18, fontWeight: .bold),
                                ),
                                ListTile(
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    if (!isPremiumNotifier.value) {
                                      showPremiumDialog(context);
                                      return;
                                    }
                                    mainPageThemeNotifier.value = .vivid;
                                    updateHoverFocusColor();
                                  },
                                  trailing: ValueListenableBuilder(
                                    valueListenable: isPremiumNotifier,
                                    builder: (context, isPremium, child) {
                                      if (!isPremium) {
                                        return Icon(Icons.lock);
                                      }
                                      return value == .vivid
                                          ? Icon(Icons.check)
                                          : SizedBox.shrink();
                                    },
                                  ),
                                ),
                                ListTile(
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .light;
                                    updateHoverFocusColor();
                                  },
                                  trailing: value == .light
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    mainPageThemeNotifier.value = .dark;
                                    updateHoverFocusColor();
                                  },
                                  trailing: value == .dark
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
                                  style: .new(fontSize: 18, fontWeight: .bold),
                                ),
                                ListTile(
                                  title: Text(l10n.vividMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .vivid;
                                  },
                                  trailing: value == .vivid
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  title: Text(l10n.lightMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .light;
                                  },
                                  trailing: value == .light
                                      ? Icon(Icons.check)
                                      : null,
                                ),
                                ListTile(
                                  title: Text(l10n.darkMode),
                                  onTap: () {
                                    lyricsPageThemeNotifier.value = .dark;
                                  },
                                  trailing: value == .dark
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

  Widget equalizerListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(equalizerImage, size: iconSize),
      title: Text(l10n.equalizer),
      onTap: () {
        if (!isPremiumNotifier.value) {
          showPremiumDialog(context);
          return;
        }
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
      trailing: ValueListenableBuilder(
        valueListenable: isPremiumNotifier,
        builder: (context, value, child) {
          if (value) {
            return SizedBox.shrink();
          }
          return Icon(Icons.lock);
        },
      ),
    );
  }

  Widget immersiveWideLayoutListTile(AppLocalizations l10n) {
    return ListTile(
      leading: Transform.scale(
        scale: 0.9,
        child: ImageIcon(fullscreenImage, size: iconSize),
      ),

      title: Text(l10n.immersiveWideLayout),
      trailing: SizedBox(
        width: 50,
        child: Builder(
          builder: (context) {
            return MySwitch(
              valueNotifier: immersiveWideLayoutNotifier,
              onToggleCallBack: () {
                if (viewModeNotifier.value == .bigPicture ||
                    !isTooNarrow(context)) {
                  applySystemUiMode(
                    mode: immersiveWideLayoutNotifier.value
                        ? .immersiveSticky
                        : .manual,
                  );
                }
                setting.save();
              },
            );
          },
        ),
      ),
    );
  }

  Widget autoPlayOnStartupListTile(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(playOutlinedImage, size: iconSize),

      title: Text(l10n.autoPlayOnStartup),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: autoPlayOnStartupNotifier,
          onToggleCallBack: () {
            setting.save();
          },
        ),
      ),
    );
  }

  Widget exitOnClose(AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(powerOffImage),

      title: Text(l10n.closeAction),
      trailing: SizedBox(
        width: 150,
        child: Row(
          children: [
            Spacer(),
            MySwitch(
              trueText: l10n.exit,
              falseText: l10n.hide,
              valueNotifier: exitOnCloseNotifier,
              onToggleCallBack: () {
                setting.save();
              },
            ),
          ],
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
          'https://api.github.com/repos/AfalpHy/sylvakru/releases/latest',
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
                        ValueListenableBuilder(
                          valueListenable: buttonColor.valueNotifier,
                          builder: (context, value, child) {
                            return Row(
                              children: [
                                Spacer(),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: value,
                                  ),
                                  child: Text(l10n.cancel),
                                ),
                                SizedBox(width: 20),
                                ElevatedButton(
                                  onPressed: () => launchUrl(
                                    Uri.parse(
                                      "https://github.com/AfalpHy/sylvakru/releases/latest",
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: value,
                                  ),
                                  child: Text(l10n.go2Download),
                                ),
                                Spacer(),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          } else {
            if (context.mounted) {
              showCenterMessage(context, l10n.alreadyLatest);
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

  Widget viewLogListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(exportLogImage, size: iconSize),

      title: Text(l10n.viewLog),
      onTap: () async {
        showAnimationDialog(
          context: context,
          child: Builder(
            builder: (context) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.heightOf(context) * 0.75,
                  maxWidth: isTooNarrow(context) ? 300 : 400,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(logger.logContent),
                        ),
                      ),
                      SizedBox(height: 20),
                      if (isMobile)
                        ValueListenableBuilder(
                          valueListenable: buttonColor.valueNotifier,
                          builder: (context, value, child) {
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor.value,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.all(10),
                              ),
                              onPressed: () async {
                                String? result;
                                if (Platform.isAndroid) {
                                  result = await FilePicker.getDirectoryPath();
                                  if (result == null) {
                                    return;
                                  }
                                  logger.export2Directory(result);
                                  if (context.mounted) {
                                    showCenterMessage(
                                      context,
                                      'Export to $result',
                                    );
                                  }
                                } else {
                                  result = '${appDocsDir.path}/logs';
                                  logger.export2Directory(result);
                                  showCenterMessage(
                                    context,
                                    'Export to Sylvakru/logs',
                                  );
                                }
                              },
                              child: Text(l10n.exportLog),
                            );
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
}
