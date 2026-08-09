import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/network_error_reporter.dart';
import 'package:sylvakru/base/services/taskbar_service.dart';
import 'package:sylvakru/base/utils/dynamic_lyrics_page_route.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/connect_client_widget.dart';
import 'package:sylvakru/base/widgets/manage_music_folders.dart';
import 'package:sylvakru/big_picture_view/big_picture_view.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/landscape_view.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/layer/premium_layer.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

class ViewEntry extends StatefulWidget {
  const ViewEntry({super.key});

  @override
  State<StatefulWidget> createState() => _ViewEntryState();
}

class _ViewEntryState extends State<ViewEntry> with WidgetsBindingObserver {
  bool systemCanPop = false;
  Timer? _exitTimer;
  int keyValue = 0;
  SystemUiMode? _appliedUiMode;

  // 系统 UI 模式只在目标变化时应用，不能放在 build 里每次重设：全面屏手势
  // 上滑时系统临时显示系统栏 → insets 变化触发重建 → 立刻又把栏藏回去，
  // 返回桌面的手势被打断（平板宽屏沉浸模式下上滑卡住回不了桌面）。
  void _applySystemUiMode(SystemUiMode mode) {
    if (_appliedUiMode == mode) {
      return;
    }
    _appliedUiMode = mode;
    if (mode == SystemUiMode.manual) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(mode);
    }
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
    }

    if (autoPlayOnStartupNotifier.value && currentSongNotifier.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context, rootNavigator: true).push(
          DynamicLyricsPageRoute(pageBuilder: (_, _, _) => LyricsPageLayer()),
        );
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isIOS) {
        if (!firstLaunch) {
          if (trialRemainingMinNotifier.value > 0) {
            showTrialDialog(context);
          }
          await Future.delayed(Duration(milliseconds: 500));
          await NativeMenu.init();
        }
        await NativeMenu.initIcons();
      } else if (Platform.isMacOS) {
        await NativeMenu.initIcons();
      } else if (Platform.isWindows) {
        setupTaskbar();
      }
    });

    networkErrorNotifier.addListener(_onNetworkError);
  }

  // Server clients report failures here since they have no BuildContext of
  // their own; this is the single place that turns that into something the
  // user actually sees, instead of the failure only ever reaching the log.
  void _onNetworkError() {
    final message = lastNetworkErrorMessage;
    if (message != null && mounted) {
      showCenterMessage(context, message, duration: 3000);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    networkErrorNotifier.removeListener(_onNetworkError);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isAndroid) {
      if (state == .resumed) {
        systemCanPop = false;
        _exitTimer?.cancel();
        // 回到前台系统可能已恢复系统栏，重新应用一次当前 UI 模式
        final uiMode = _appliedUiMode;
        if (uiMode != null) {
          _appliedUiMode = null;
          _applySystemUiMode(uiMode);
        }
        // rebuild PopScope to allow it to handle pop
        setState(() {
          keyValue++;
        });
      } else if (isTV && state == .paused) {
        audioHandler.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return view();
    }
    return PopScope(
      canPop: false,
      key: ValueKey(keyValue),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop | isTyping | isTV) {
          return;
        }
        if (portraitKey.currentState?.isDrawerOpen ?? false) {
          portraitKey.currentState?.closeDrawer();
          return;
        }
        if (await layersManager.popDetail(sidebarHighlighLabel.value)) {
          return;
        }

        if (systemCanPop) {
          systemCanPop = false;
          _exitTimer?.cancel();
          SystemNavigator.pop();
        } else {
          systemCanPop = true;
          if (context.mounted) {
            showCenterMessage(context, AppLocalizations.of(context).tapAgain);
          }
          _exitTimer = Timer(const Duration(seconds: 2), () {
            systemCanPop = false;
          });
        }
      },
      child: view(),
    );
  }

  Widget view() {
    if (firstLaunch) {
      return firstLaunchView();
    }
    return ValueListenableBuilder(
      valueListenable: viewModeNotifier,
      builder: (context, viewMode, child) {
        if (viewMode == .mini) {
          return MiniView();
        }
        if (viewMode == .bigPicture) {
          _applySystemUiMode(SystemUiMode.immersiveSticky);
          return BigPictureView();
        }
        if (isTooNarrow(context)) {
          _applySystemUiMode(SystemUiMode.manual);
          return PortraitView();
        }
        // immersiveSticky：上滑临时显示的系统栏是透明浮层、不派发 insets
        // 变化也会自动隐藏，全面屏手势可正常完成；immersive 被唤出后会常驻
        _applySystemUiMode(SystemUiMode.immersiveSticky);
        return LandscapeView();
      },
    );
  }

  Widget firstLaunchView() {
    final l10n = AppLocalizations.of(context);
    return Material(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: .symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 20),
                Expanded(
                  child: ListView(
                    padding: .zero,
                    children: [
                      Card(
                        child: Column(
                          children: [
                            ListTile(
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
                                  child: ConnectClientWidget(
                                    sourceType: .webdav,
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: Image(
                                image: subsonicImage,
                                width: 30,
                                height: 30,
                              ),

                              title: Text(l10n.connect2Subsonic),
                              onTap: () {
                                showAnimationDialog(
                                  context: context,
                                  child: ConnectClientWidget(
                                    sourceType: .subsonic,
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: Image(
                                image: navidromeImage,
                                width: 30,
                                height: 30,
                              ),

                              title: Text(l10n.connect2Navidrome),
                              onTap: () {
                                showAnimationDialog(
                                  context: context,
                                  child: ConnectClientWidget(
                                    sourceType: .navidrome,
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: Image(
                                image: embyImage,
                                width: 30,
                                height: 30,
                              ),

                              title: Text(l10n.connect2Emby),
                              onTap: () {
                                showAnimationDialog(
                                  context: context,
                                  child: ConnectClientWidget(sourceType: .emby),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10),

                      Card(child: ManageMusicFolders(inSetting: false)),
                    ],
                  ),
                ),
                SizedBox(height: 10),

                Card(
                  clipBehavior: .antiAlias,
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () async {
                      setState(() {
                        firstLaunch = false;
                      });
                      if (Platform.isIOS) {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          if (trialRemainingMinNotifier.value > 0) {
                            showTrialDialog(context);
                          }
                          await NativeMenu.init();
                        });
                      }
                      await Loader.sync(3);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18.0,
                        vertical: 12.0,
                      ),
                      child: Text(l10n.getStart),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
