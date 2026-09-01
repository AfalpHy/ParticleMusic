import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/custom_text_field.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/playlist_widgets.dart';
import 'package:sylvakru/base/widgets/selectable_song_list_page.dart';
import 'package:sylvakru/base/widgets/song_info.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_album_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_artist_panel.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/layer/premium_layer.dart';

DateTime? _lastShowTime;

void showCenterMessage(String message, {int duration = 2000}) {
  final now = DateTime.now();
  if (_lastShowTime != null &&
      now.difference(_lastShowTime!) < const Duration(seconds: 5)) {
    return;
  }
  _lastShowTime = now;

  final overlay = globalNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Material(
          color: Colors.black,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              message,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(Duration(milliseconds: duration), () {
    overlayEntry.remove();
  });
}

OverlayEntry? _centerOverlayEntry;

Future<void> showCenterLoading() async {
  final overlay = globalNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _centerOverlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black26),
        Center(child: CircularProgressIndicator(color: iconColor.value)),
      ],
    ),
  );

  overlay.insert(_centerOverlayEntry!);
}

void removeCenterLoading() {
  _centerOverlayEntry?.remove();
  _centerOverlayEntry = null;
}

Future<bool> showConfirmDialog(BuildContext context, String action) async {
  final l10n = AppLocalizations.of(context);

  final result = await showAnimationDialog<bool>(
    context: context,
    child: Builder(
      builder: (context) {
        return SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                buttonColor.valueNotifier,
                lyricsPageForegroundColor.valueNotifier,
                lyricsPageButtonColor.valueNotifier,
                miniViewForegroundColor.valueNotifier,
              ]),
              builder: (context, _) {
                return Column(
                  mainAxisSize: .min,
                  children: [
                    Align(
                      alignment: .centerLeft,
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: .bold,
                          color: colorManager.getSpecificTextColor(),
                          overflow: .ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    Align(
                      alignment: .centerLeft,
                      child: Text(
                        l10n.continueMsg,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorManager.getSpecificTextColor(),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          autofocus: viewModeNotifier.value == .bigPicture,
                          onPressed: () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorManager
                                .getSpecificButtonColor(),
                            foregroundColor: colorManager
                                .getSpecificTextColor(),
                          ),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorManager
                                .getSpecificButtonColor(),
                            foregroundColor: Colors.red,
                          ),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
  return result ?? false;
}

Future<String> getInputTextDialog(
  BuildContext context,
  String title, {
  bool needConfirm = true,
}) async {
  final l10n = AppLocalizations.of(context);

  final controller = TextEditingController();

  final result = await showAnimationDialog<String>(
    context: context,
    child: SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
        child: ValueListenableBuilder(
          valueListenable: lyricsPageForegroundColor.valueNotifier,
          builder: (context, value, child) {
            final specificTextcolor = colorManager.getSpecificTextColor();
            return Column(
              mainAxisSize: .min,
              children: [
                Center(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 25, color: specificTextcolor),
                  ),
                ),
                SizedBox(height: 20),
                CustomTextField(
                  null,
                  controller,
                  compact: false,
                  autoFocus: true,
                ),
                SizedBox(height: 30),
                if (needConfirm)
                  Center(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        buttonColor.valueNotifier,
                        lyricsPageButtonColor.valueNotifier,
                      ]),
                      builder: (context, _) {
                        return ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorManager
                                .getSpecificButtonColor(),
                            foregroundColor: specificTextcolor,
                          ),
                          child: Text(l10n.confirm),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
  if (needConfirm) {
    return result ?? '';
  } else {
    return controller.text;
  }
}

Future<T?> showAnimationDialog<T>({
  required BuildContext context,
  bool barrierDismissible = true,
  required Widget child,
}) async {
  Offset offset = Offset.zero;

  final GlobalKey childKey = GlobalKey();
  double childHeight = 0;
  void measureChild() {
    final renderBox = childKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final newHeight = renderBox.size.height;
      if (newHeight != childHeight) {
        childHeight = newHeight;
      }
    }
  }

  return await showGeneralDialog<T>(
    context: context,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, _) {
      return StatefulBuilder(
        builder: (context, setState) {
          final mediaQuery = MediaQuery.of(context);
          final screenHeight = mediaQuery.size.height;
          final keyboardHeight = mediaQuery.viewInsets.bottom;
          final isKeyboardOpen = keyboardHeight > 0;
          double getMinOffset() {
            if (childHeight == 0) return double.negativeInfinity;
            return screenHeight / 2 - keyboardHeight - childHeight / 2 - 30;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            measureChild();
            if (!isKeyboardOpen && offset != .zero) {
              setState(() {
                offset = .zero;
              });
            }
          });

          return Stack(
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (_, _) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5 * animation.value,
                      sigmaY: 5 * animation.value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: 0.3 * animation.value,
                      ),
                    ),
                  );
                },
              ),

              ModalBarrier(
                dismissible: barrierDismissible,
                color: Colors.transparent,
                onDismiss: () {
                  Navigator.pop(context);
                },
              ),

              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(0, offset.dy, 0),
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (!isKeyboardOpen) return;

                      setState(() {
                        if (offset.dy < getMinOffset() || offset.dy > 0) {
                          offset += Offset(0, details.delta.dy * 0.15);
                        } else {
                          offset += Offset(0, details.delta.dy);
                        }
                      });
                    },

                    onVerticalDragEnd: (_) {
                      if (!isKeyboardOpen) return;

                      final minOffset = getMinOffset();
                      setState(() {
                        if (offset.dy < minOffset) {
                          offset = Offset(0, minOffset);
                        } else if (offset.dy > 0) {
                          offset = .zero;
                        }
                      });
                    },

                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOutCubic,
                            ),
                          ),
                      child: FadeTransition(
                        opacity: animation,
                        child: ListenableBuilder(
                          listenable: Listenable.merge([
                            layersManager.backgroundChangeNotifier,
                            currentSongNotifier,
                            pageBackgroundColor.valueNotifier,
                            panelColor.valueNotifier,
                          ]),
                          builder: (context, _) {
                            return Material(
                              key: childKey,
                              shape: SmoothRectangleBorder(
                                smoothness: 1,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              color: firstLaunch
                                  ? null
                                  : Color.alphaBlend(
                                      colorManager.getSpecificBgColor(),
                                      colorManager.getSpecificBgBaseColor(),
                                    ),
                              clipBehavior: Clip.antiAliasWithSaveLayer,
                              child: MediaQuery.removePadding(
                                context: context,
                                removeLeft: true,
                                removeRight: true,
                                removeTop: true,
                                removeBottom: true,
                                child: child,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

ValueNotifier<bool> vibrationOnNoitifier = ValueNotifier(true);
void tryVibrate() {
  if (vibrationOnNoitifier.value) {
    HapticFeedback.heavyImpact();
  }
}

class MenuItem {
  final IconData? iconData;
  final String? text;
  final void Function()? callback;
  final bool isDivider;

  MenuItem({this.iconData, this.text, this.callback, this.isDivider = false});
}

void showContextMenu(
  BuildContext context,
  List<MenuItem> items,
  Offset globalPosition,
) {
  if (Platform.isIOS) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final Size size = renderBox.size;
      final Offset position = renderBox.localToGlobal(Offset.zero);

      NativeMenu.showForIOS(items, position, size);
    }
    return;
  }

  if (Platform.isMacOS) {
    NativeMenu.show(items);
    return;
  }

  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) {
        bool first = true;

        // stack is important to position, I don't know why
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, _) {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  if (first) {
                    first = false;
                    return;
                  }
                  Navigator.of(context).pop();
                });
                return CustomSingleChildLayout(
                  delegate: MenuPositionDelegate(
                    globalPosition,
                    MediaQuery.of(context).size,
                  ),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      layersManager.backgroundChangeNotifier,
                      currentSongNotifier,
                    ]),
                    builder: (context, value) {
                      return Material(
                        color: Color.alphaBlend(
                          colorManager.getSpecificMenuColor(),
                          colorManager.getSpecificBgBaseColor(),
                        ),
                        elevation: 6.0,
                        shape: SmoothRectangleBorder(
                          smoothness: 1,
                          borderRadius: .circular(8),
                        ),

                        child: IntrinsicWidth(
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: items.map((item) {
                                if (item.isDivider) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    child: MyDivider(
                                      color: dividerColor,
                                      height: 1,
                                    ),
                                  );
                                }
                                return InkWell(
                                  mouseCursor: SystemMouseCursors.click,
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    item.callback?.call();
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: Platform.isAndroid ? 8 : 5,
                                    ),
                                    child: Row(
                                      children: [
                                        if (item.iconData != null) ...[
                                          Icon(
                                            item.iconData,
                                            size: 18,
                                            color: colorManager
                                                .getSpecificIconColor(),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          item.text!,
                                          style: .new(
                                            color: colorManager
                                                .getSpecificTextColor(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

class MenuPositionDelegate extends SingleChildLayoutDelegate {
  final Offset position;
  final Size screenSize;

  MenuPositionDelegate(this.position, this.screenSize);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = position.dx;
    double y = position.dy;

    if (x + childSize.width > screenSize.width) {
      x -= childSize.width;
    }
    if (y + childSize.height > screenSize.height) {
      y -= childSize.height;
    }

    return Offset(x.clamp(0, screenSize.width), y.clamp(0, screenSize.height));
  }

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) => true;
}

class NativeMenu {
  static const _channel = MethodChannel('com.afalphy.menu');

  static final Map<IconData, Uint8List> _iconMap = {};

  static Future<void> init() async {
    await _channel.invokeMethod('initNativeMenu');
  }

  static Future<void> initIcons() async {
    await _iconToPng(Icons.vertical_align_top_rounded);
    await _iconToPng(Icons.play_arrow_rounded);
    await _iconToPng(Icons.navigate_next_rounded);
    await _iconToPng(Icons.playlist_add_rounded);
    await _iconToPng(Icons.add_rounded);
    await _iconToPng(Icons.people);
    await _iconToPng(Icons.album_rounded);
    await _iconToPng(Icons.info_outline_rounded);
    await _iconToPng(Icons.edit_rounded);
    await _iconToPng(Icons.delete_rounded);
    await _iconToPng(Icons.navigate_next_rounded);
    await _iconToPng(Icons.close_rounded);
    await _iconToPng(Icons.reorder_rounded);
    await _iconToPng(Icons.delete);
  }

  static Future<void> _iconToPng(IconData icon) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 96,
          color: Colors.black,
        ),
      ),
    );

    painter.layout();
    painter.paint(canvas, Offset.zero);

    final image = await recorder.endRecording().toImage(
      painter.width.ceil(),
      painter.height.ceil(),
    );

    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    final result = data!.buffer.asUint8List();
    _iconMap[icon] = result;
  }

  static Future<void> show(List<MenuItem> items) async {
    final menuData = items.map((item) {
      return {
        'text': item.text,
        'isDivider': item.isDivider,
        'iconBytes': item.iconData != null ? _iconMap[item.iconData] : null,
      };
    }).toList();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "onMenuItemSelected") {
        final int index = call.arguments;
        items[index].callback?.call();
      }
    });

    await _channel.invokeMethod('showNativeMenu', {'items': menuData});
  }

  static Future<void> showForIOS(
    List<MenuItem> items,
    Offset position,
    Size size,
  ) async {
    final menuData = items.map((item) {
      return {
        'text': item.text,
        'isDivider': item.isDivider,
        'iconBytes': item.iconData != null ? _iconMap[item.iconData] : null,
      };
    }).toList();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "onMenuItemSelected") {
        final int index = call.arguments;
        items[index].callback?.call();
      }
    });

    await _channel.invokeMethod('showNativeMenu', {
      'items': menuData,
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
    });
  }
}

Future<void> showTrialDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  await showAnimationDialog(
    context: context,
    child: Builder(
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.widthOf(context) * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                buttonColor.valueNotifier,
                lyricsPageForegroundColor.valueNotifier,
                lyricsPageButtonColor.valueNotifier,
              ]),
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      l10n.premiumTrialActive,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: .bold,
                        color: colorManager.getSpecificTextColor(),
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      l10n.trialRemainingStatus(
                        trialRemainingMinNotifier.value,
                      ),
                      style: TextStyle(
                        color: colorManager.getSpecificTextColor(),
                      ),
                    ),
                    SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorManager.getSpecificButtonColor(),
                        foregroundColor: colorManager.getSpecificTextColor(),
                      ),
                      child: Text(l10n.gotIt),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

Future<void> showPremiumDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  await showAnimationDialog(
    context: context,
    child: Builder(
      builder: (context) {
        return SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                buttonColor.valueNotifier,
                lyricsPageForegroundColor.valueNotifier,
                lyricsPageButtonColor.valueNotifier,
              ]),
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.premiumFeatures,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: colorManager.getSpecificTextColor(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      l10n.premiumRequiredMessage,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorManager.getSpecificTextColor(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      l10n.premiumUnlockHint,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorManager.getSpecificTextColor(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorManager
                              .getSpecificButtonColor(),
                          foregroundColor: colorManager.getSpecificTextColor(),
                        ),
                        child: Text(l10n.confirm),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

void showSongOptions({
  required BuildContext context,
  required MyAudioMetadata song,
  void Function()? moveToTop,
  bool includeGoToArtist = false,
  String? excludedArtist,
  bool includeGoToAlbum = false,
  Playlist? playlist,
}) {
  final l10n = AppLocalizations.of(context);
  showAnimationDialog(
    context: context,
    child: Builder(
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: max(320, min(MediaQuery.widthOf(context) / 3, 400)),
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 5),

              ListTile(
                leading: CoverArtWidget(
                  size: 50,
                  borderRadius: 5,
                  picture: song.picture,
                ),
                title: Text(getTitle(song), overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  "${getArtist(song)} - ${getAlbum(song)}",
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(height: 5),
              MyDivider(color: dividerColor, thickness: 0.5, height: 1),
              SizedBox(height: 5),

              Flexible(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    if (moveToTop != null)
                      ListTile(
                        leading: Icon(Icons.vertical_align_top_rounded),
                        title: Text(
                          l10n.move2Top,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          moveToTop.call();
                        },
                      ),
                    ListTile(
                      leading: Icon(Icons.play_arrow_rounded),
                      title: Text(
                        l10n.playNow,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      onTap: () {
                        audioHandler.singlePlay(song);
                        Navigator.pop(context);
                        audioHandler.saveAllStates();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.navigate_next_rounded),
                      title: Text(
                        l10n.playNext,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      onTap: () {
                        if (playQueue.isEmpty) {
                          audioHandler.singlePlay(song);
                        } else {
                          audioHandler.insert2Next(song);
                        }
                        Navigator.pop(context);
                        audioHandler.saveAllStates();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.playlist_add_rounded),
                      title: Text(
                        l10n.add2Queue,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      onTap: () {
                        if (playQueue.isEmpty) {
                          audioHandler.singlePlay(song);
                        } else {
                          audioHandler.add2Last(song);
                        }
                        Navigator.pop(context);
                        audioHandler.saveAllStates();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.add_rounded),
                      title: Text(
                        l10n.add2Playlist,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      onTap: () {
                        Navigator.pop(context);

                        showAddPlaylistDialog(context, [song]);
                      },
                    ),

                    if (includeGoToArtist)
                      ListTile(
                        leading: Icon(Icons.people),
                        title: Text(
                          l10n.go2Artist,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          goToArtist(
                            song,
                            context,
                            bigPictureMode: true,
                            excludedArtist: excludedArtist,
                          );
                        },
                      ),

                    if (includeGoToAlbum)
                      ListTile(
                        leading: Icon(Icons.album_rounded),
                        title: Text(
                          l10n.go2Album,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          goToAlbum(
                            song,
                            bigPictureMode: true,
                            context: context,
                          );
                        },
                      ),

                    ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text(
                        l10n.songInfo,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: 0,
                        vertical: -4,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showAnimationDialog(
                          context: context,
                          child: SongInfo(song: song),
                        );
                      },
                    ),

                    if (playlist != null)
                      ListTile(
                        leading: Icon(Icons.delete_rounded),
                        title: Text(
                          l10n.delete,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                        onTap: () async {
                          if (await showConfirmDialog(context, l10n.delete)) {
                            playlist.remove([song]);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),

              SizedBox(height: 10),
            ],
          ),
        );
      },
    ),
  );
}

void showPlayQueueItemOptions(
  BuildContext context,
  MyAudioMetadata song, {
  required void Function() playNextCallback,
  required void Function() removeCallback,
}) {
  final l10n = AppLocalizations.of(context);
  showAnimationDialog(
    context: context,
    child: SizedBox(
      width: 300,
      child: ListenableBuilder(
        listenable: Listenable.merge([lyricsPageForegroundColor.valueNotifier]),
        builder: (context, _) {
          final iconColor = colorManager.getSpecificIconColor();
          final textColor = colorManager.getSpecificTextColor();

          return Column(
            mainAxisSize: .min,
            children: [
              SizedBox(height: 10),

              ListTile(
                leading: Icon(Icons.play_arrow_rounded, color: iconColor),
                title: Text(l10n.playNow, style: .new(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  final index = playQueue.indexOf(song);
                  if (index == audioHandler.currentIndex) {
                    audioHandler.play();
                  } else {
                    audioHandler.currentIndex = index;
                    await audioHandler.load();
                    audioHandler.play();
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.navigate_next_rounded, color: iconColor),
                title: Text(l10n.playNext, style: .new(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  playNextCallback.call();
                },
              ),
              ListTile(
                leading: Icon(Icons.playlist_add_rounded, color: iconColor),
                title: Text(l10n.add2Playlist, style: .new(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  if (context.mounted) {
                    showAddPlaylistDialog(context, [song]);
                  }
                },
              ),

              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: iconColor),
                title: Text(l10n.songInfo, style: .new(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));
                  if (context.mounted) {
                    showAnimationDialog(
                      context: context,
                      child: SongInfo(song: song),
                    );
                  }
                },
              ),

              ListTile(
                leading: Icon(Icons.close_rounded, color: iconColor),
                title: Text(l10n.remove, style: .new(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  removeCallback.call();
                },
              ),
              SizedBox(height: 10),
            ],
          );
        },
      ),
    ),
  );
}

void showSongListOptions(BuildContext context, List<MyAudioMetadata> songList) {
  final l10n = AppLocalizations.of(context);
  showAnimationDialog(
    context: context,
    child: SizedBox(
      width: 300,
      child: Builder(
        builder: (context) {
          return Column(
            mainAxisSize: .min,
            children: [
              SizedBox(height: 10),

              ListTile(
                leading: Icon(Icons.play_arrow_rounded),
                title: Text(l10n.playAll),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  audioHandler.currentIndex = 0;
                  playModeNotifier.value = 0;
                  await audioHandler.setPlayQueue(songList);
                  await audioHandler.load();
                  audioHandler.play();
                },
              ),
              ListTile(
                leading: ImageIcon(shuffleImage),
                title: Text(l10n.shuffle),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  audioHandler.currentIndex = Random().nextInt(songList.length);
                  playModeNotifier.value = 1;
                  await audioHandler.setPlayQueue(songList);
                  await audioHandler.load();
                  audioHandler.play();
                },
              ),

              ListTile(
                leading: ImageIcon(selectImage),
                title: Text(l10n.select),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));
                  if (context.mounted) {
                    Navigator.of(context).push(
                      ZoomPageRoute(
                        builder: (_) => SelectableSongListPage(
                          songList: songList,
                          reorderable: false,
                        ),
                      ),
                    );
                  }
                },
              ),

              SizedBox(height: 10),
            ],
          );
        },
      ),
    ),
  );
}

void showArtistsAlbumsOptions(BuildContext context, bool isArtist) {
  final l10n = AppLocalizations.of(context);
  showAnimationDialog(
    context: context,
    child: SizedBox(
      width: 300,
      child: Builder(
        builder: (context) {
          final isAscending = artistAlbumManager.getIsAscendingNotifier(
            isArtist,
          );
          return Column(
            mainAxisSize: .min,
            children: [
              SizedBox(height: 10),

              ListTile(
                leading: ImageIcon(sequenceImage),
                title: Text(
                  isAscending.value ? l10n.descending : l10n.ascending,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(Duration(milliseconds: 250));

                  isAscending.value = !isAscending.value;
                },
              ),

              SizedBox(height: 10),
            ],
          );
        },
      ),
    ),
  );
}

Future<String?> _selectArtist(
  BuildContext context,
  List<String> artists, {
  String? excludedArtist,
}) async {
  artists.removeWhere((e) => e == excludedArtist);
  if (artists.isEmpty) {
    return null;
  }
  if (artists.length == 1 && excludedArtist == null) {
    return artists.first;
  }

  return showAnimationDialog(
    context: context,
    child: SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: artists.length,
          itemExtent: 60,
          itemBuilder: (context, index) {
            String name = artists[index];

            return Center(
              child: ListTile(
                leading: CoverArtWidget(
                  size: 50,
                  borderRadius: 5,
                  picture: artistAlbumManager.artistMap[name]!.picture,
                ),
                title: Text(name, style: .new(overflow: .ellipsis)),
                onTap: () {
                  Navigator.pop(context, name);
                },
              ),
            );
          },
        ),
      ),
    ),
  );
}

void goToArtist(
  MyAudioMetadata song,
  BuildContext context, {
  bool bigPictureMode = false,
  String? excludedArtist,
}) async {
  Artist? artist;
  if (isNotStreamSource) {
    final artistName = await _selectArtist(
      context,
      getArtists(getArtist(song)),
      excludedArtist: excludedArtist,
    );
    artist = artistAlbumManager.artistMap[artistName];
  } else {
    if (song.artistId == null) {
      showCenterMessage('Can not get this artist');
      return;
    }
    if (artistAlbumManager.artistList.isEmpty) {
      showCenterLoading();
      await artistAlbumManager.loadArtists();
      removeCenterLoading();
    }

    artist = artistAlbumManager.artistMap[song.artist];
  }

  if (artist == null) {
    showCenterMessage('Get artist failed');
    return;
  }

  if (bigPictureMode) {
    if (context.mounted) {
      Navigator.of(context).push(
        ZoomPageRoute(
          builder: (context) {
            return BigSingleArtistPanel(artist: artist!);
          },
        ),
      );
    }
  } else {
    await Future.delayed(Duration(milliseconds: 250));
    layersManager.switchRootLayer('artists');
    layersManager.pushDetailIfNeed(artist);
  }
}

Future<Album?> _loadStreamAlbum(MyAudioMetadata song) async {
  // it probably would not happen
  if (song.albumId == null) {
    showCenterMessage('Can not get this album');
    return null;
  }

  showCenterLoading();
  if (artistAlbumManager.albumList.isEmpty) {
    await artistAlbumManager.loadAlbums();
  }
  if (artistAlbumManager.albumMap[song.albumId] == null) {
    final album = await streamClient!.getAlbum(song.albumId!);
    if (album != null) {
      artistAlbumManager.albumList.add(album);
      artistAlbumManager.sortAlbums();
      artistAlbumManager.updateNotifier.value++;
    }
  }
  removeCenterLoading();

  return artistAlbumManager.albumMap[song.albumId];
}

void goToAlbum(
  MyAudioMetadata song, {
  bool bigPictureMode = false,
  BuildContext? context,
}) async {
  await Future.delayed(Duration(milliseconds: 250));

  Album? album;
  if (isNotStreamSource) {
    album = artistAlbumManager.albumMap[getAlbum(song)];
  } else {
    album = await _loadStreamAlbum(song);
  }
  if (album == null) {
    showCenterMessage('Get album failed');
    return;
  }

  if (bigPictureMode) {
    final baseColor = await computeColor(album.picture);
    if (!context!.mounted) {
      return;
    }
    Navigator.of(context).push(
      ZoomPageRoute(
        builder: (context) {
          return BigSingleAlbumPanel(album: album!, baseColor: baseColor);
        },
      ),
    );
    return;
  }

  layersManager.switchRootLayer('albums');

  if (isNotStreamSource) {
    layersManager.pushDetailIfNeed(artistAlbumManager.albumMap[getAlbum(song)]);
  } else {
    layersManager.pushDetailIfNeed(album);
  }
}
