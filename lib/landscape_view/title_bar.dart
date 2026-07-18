import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatefulWidget {
  final bool isMainPage;

  final String? hintText;
  final TextEditingController? textController;

  final Function()? backToRoot;
  final Function()? scrollToTop;
  final Function()? findLocation;

  const TitleBar({
    super.key,
    this.isMainPage = true,
    this.hintText,
    this.textController,
    this.backToRoot,
    this.scrollToTop,
    this.findLocation,
  });

  @override
  State<StatefulWidget> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> {
  final displayCancelNotifier = ValueNotifier(false);

  final searchFieldNode = FocusNode();

  void displayCancelOrNot() {
    if (widget.textController!.text != '') {
      displayCancelNotifier.value = true;
    } else {
      displayCancelNotifier.value = false;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.textController?.addListener(displayCancelOrNot);
    searchFieldNode.addListener(() {
      isTyping = searchFieldNode.hasFocus;
    });
  }

  @override
  void dispose() {
    displayCancelNotifier.dispose();
    widget.textController?.removeListener(displayCancelOrNot);

    searchFieldNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 75,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (details) {
              if (isMobile) {
                return;
              }
              windowManager.startDragging();
            },
            // prevent system alert sounds on desktop when clicking non-interactive areas
            onTap: () {},
            onDoubleTap: () async {
              if (isMobile) {
                return;
              }
              if (isFullScreenNotifier.value) {
                return;
              }
              isMaximizedNotifier.value
                  ? windowManager.unmaximize()
                  : windowManager.maximize();
            },
            child: Container(),
          ),

          Center(child: content()),
        ],
      ),
    );
  }

  Widget content() {
    return Row(
      children: [
        SizedBox(width: 30),

        if (widget.isMainPage)
          IgnorePointer(
            ignoring: widget.backToRoot == null,
            child: Opacity(
              opacity: widget.backToRoot != null ? 1 : 0,
              child: IconButton(
                onPressed: () {
                  widget.backToRoot?.call();
                },
                icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
              ),
            ),
          ),

        if (!widget.isMainPage)
          ValueListenableBuilder(
            valueListenable: isFullScreenNotifier,
            builder: (context, isFullScreen, child) {
              return isFullScreen | isMobile
                  ? SizedBox.shrink()
                  : ValueListenableBuilder(
                      valueListenable: lyricsPageForegroundColor.valueNotifier,
                      builder: (context, value, child) {
                        return IconButton(
                          color: value,
                          onPressed: () {
                            displayLyricsPage = false;
                            Navigator.pop(context);
                          },
                          icon: ImageIcon(arrowDownImage),
                        );
                      },
                    );
            },
          ),
        if (widget.isMainPage) SizedBox(width: 10),

        if (widget.hintText != null) SizedBox(child: searchField()),

        if (!widget.isMainPage && !isMobile && !isMaximizedNotifier.value)
          ValueListenableBuilder(
            valueListenable: lyricsPageForegroundColor.valueNotifier,
            builder: (context, value, child) {
              return IconButton(
                color: value,
                onPressed: () async {
                  if (isFullScreenNotifier.value) {
                    await windowManager.setFullScreen(false);
                    isFullScreenNotifier.value = false;
                  } else {
                    await windowManager.setFullScreen(true);
                    isFullScreenNotifier.value = true;
                  }
                },
                icon: ValueListenableBuilder(
                  valueListenable: isFullScreenNotifier,
                  builder: (context, isFullScreen, child) {
                    return ImageIcon(
                      isFullScreen ? fullscreenExitImage : fullscreenImage,
                    );
                  },
                ),
              );
            },
          ),

        Spacer(),

        if (widget.scrollToTop != null)
          IconButton(
            onPressed: widget.scrollToTop,
            icon: ImageIcon(topArrowImage),
          ),

        if (widget.findLocation != null)
          IconButton(
            onPressed: widget.findLocation,
            icon: ImageIcon(locationImage),
          ),

        if (widget.isMainPage)
          IconButton(
            onPressed: () {
              layersManager.switchRootLayer('settings');
            },
            icon: ImageIcon(settingImage),
          ),

        if (!isMobile) windowControls(),

        SizedBox(width: isMobile ? 10 : 30),
      ],
    );
  }

  Widget searchField() {
    return SizedBox(
      width: 260,
      height: 40,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          iconColor.valueNotifier,
          textColor.valueNotifier,
          searchFieldColor.valueNotifier,
        ]),
        builder: (context, _) {
          return Material(
            color: Colors.transparent,
            shape: SmoothRectangleBorder(
              smoothness: 1,
              borderRadius: .circular(10),
            ),
            clipBehavior: .antiAlias,
            child: Container(
              color: searchFieldColor.value,
              child: TextField(
                focusNode: searchFieldNode,
                controller: widget.textController,
                style: TextStyle(fontSize: 14, color: textColor.value),
                onTapOutside: (event) {
                  searchFieldNode.unfocus();
                },
                decoration: InputDecoration(
                  hint: Text(
                    widget.hintText!,
                    style: TextStyle(fontSize: 14, color: textColor.value),
                  ),
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Icon(Icons.search, color: iconColor.value),
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: displayCancelNotifier,
                    builder: (context, value, child) {
                      return value
                          ? IconButton(
                              onPressed: () {
                                widget.textController!.clear();
                              },
                              icon: Icon(
                                Icons.close,
                                size: 20,
                                color: iconColor.value,
                              ),
                            )
                          : SizedBox.shrink();
                    },
                  ),
                  hoverColor: Colors.transparent,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget windowControls() {
    return ValueListenableBuilder(
      valueListenable: isFullScreenNotifier,
      builder: (context, isFullScreen, child) {
        if (isFullScreen) {
          return SizedBox.shrink();
        }
        return ListenableBuilder(
          listenable: Listenable.merge([
            iconColor.valueNotifier,
            lyricsPageForegroundColor.valueNotifier,
          ]),
          builder: (context, _) {
            return Row(
              children: [
                if (widget.isMainPage)
                  IconButton(
                    color: iconColor.value,
                    onPressed: () async {
                      if (!await showConfirmDialog(
                        context,
                        'Enter big picture mode',
                      )) {
                        return;
                      }
                      await Future.delayed(Duration(milliseconds: 250));
                      viewModeNotifier.value = .bigPicture;

                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        layersManager.popDetail('artists');
                        layersManager.popDetail('albums');
                        layersManager.popDetail('folders');
                        layersManager.popDetail('playlists');
                        while (await layersManager.popDetail('settings')) {}
                      });
                    },
                    icon: ImageIcon(bigPictueModeImage),
                  ),
                if (widget.isMainPage && !isMaximizedNotifier.value)
                  IconButton(
                    color: iconColor.value,
                    onPressed: () async {
                      await windowManager.hide();
                      miniModeSwitching = true;
                      viewModeNotifier.value = .mini;

                      await Future.delayed(Duration(milliseconds: 200));

                      miniModeSwitching = false;

                      if (Platform.isWindows) {
                        await windowManager.setMinimumSize(
                          Size(325 + 16, 150 + 9),
                        );
                        await windowManager.setMaximumSize(
                          Size(600 + 16, 950 + 9),
                        );
                      } else {
                        await windowManager.setMinimumSize(Size(325, 150));
                        await windowManager.setMaximumSize(Size(600, 950));
                      }

                      await windowManager.setSize(miniSize);

                      if (miniPosition != null) {
                        await windowManager.setPosition(miniPosition!);
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          await Future.delayed(Duration(milliseconds: 250));
                          miniPosition = await windowManager.getPosition();
                        });
                      }
                      await windowManager.show();
                      await windowManager.setAlwaysOnTop(true);

                      layersManager.popDetail('artists');
                      layersManager.popDetail('albums');
                      layersManager.popDetail('folders');
                      layersManager.popDetail('playlists');
                      while (await layersManager.popDetail('settings')) {}
                    },
                    icon: ImageIcon(miniModeImage),
                  ),
                IconButton(
                  color: widget.isMainPage
                      ? iconColor.value
                      : lyricsPageForegroundColor.value,
                  onPressed: () {
                    windowManager.minimize();
                  },
                  icon: ImageIcon(minimizeImage),
                ),
                ValueListenableBuilder(
                  valueListenable: isMaximizedNotifier,
                  builder: (context, value, child) {
                    return IconButton(
                      color: widget.isMainPage
                          ? iconColor.value
                          : lyricsPageForegroundColor.value,
                      onPressed: () async {
                        isMaximizedNotifier.value
                            ? windowManager.unmaximize()
                            : windowManager.maximize();
                      },
                      icon: ImageIcon(value ? unmaximizeImage : maximizeImage),
                    );
                  },
                ),
                IconButton(
                  color: widget.isMainPage
                      ? iconColor.value
                      : lyricsPageForegroundColor.value,
                  onPressed: () {
                    windowManager.close();
                  },
                  icon: ImageIcon(closeImage),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
