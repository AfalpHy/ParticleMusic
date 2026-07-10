import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/widgets/custom_text_field.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:smooth_corner/smooth_corner.dart';

void showCenterMessage(
  BuildContext context,
  String message, {
  int duration = 2000,
}) {
  final overlay = Overlay.of(context);
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

Future<bool> showConfirmDialog(BuildContext context, String action) async {
  final l10n = AppLocalizations.of(context);

  final result = await showAnimationDialog<bool>(
    context: context,
    child: Builder(
      builder: (context) {
        return SizedBox(
          width: 300,
          height: 180,
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
                  children: [
                    Align(
                      alignment: .centerLeft,
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 25,
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

Future<String> getInputTextDialog(BuildContext context, String title) async {
  final l10n = AppLocalizations.of(context);

  final controller = TextEditingController();
  final specificTextcolor = colorManager.getSpecificTextColor();

  final result = await showAnimationDialog<String>(
    context: context,
    child: SizedBox(
      width: 300,
      height: isMobile ? 220 : 200,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
        child: Column(
          children: [
            Center(
              child: Text(
                title,
                style: TextStyle(fontSize: 25, color: specificTextcolor),
              ),
            ),
            SizedBox(height: 20),
            CustomTextField(null, controller, compact: false, autoFocus: true),
            SizedBox(height: 30),
            Center(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  buttonColor.valueNotifier,
                  lyricsPageButtonColor.valueNotifier,
                ]),
                builder: (context, _) {
                  return ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorManager.getSpecificButtonColor(),
                      foregroundColor: specificTextcolor,
                    ),
                    child: Text(l10n.confirm),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return result ?? '';
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
                              color: Color.alphaBlend(
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
          fontSize: Platform.isMacOS ? 18 : 24,
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
