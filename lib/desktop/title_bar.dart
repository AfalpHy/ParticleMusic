import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/utils.dart';
import 'package:searchfield/searchfield.dart';
import 'package:window_manager/window_manager.dart';

Widget titleSearchField(
  String hintText, {
  TextEditingController? textController,
  Function(String)? onChanged,
}) {
  final displayCancelNotifier = ValueNotifier(false);
  if (textController != null) {
    textController.addListener(() {
      if (textController.text != '') {
        displayCancelNotifier.value = true;
      } else {
        displayCancelNotifier.value = false;
      }
    });
  }
  return Center(
    child: SizedBox(
      width: 260,
      height: 40,
      child: ValueListenableBuilder(
        valueListenable: updateColorNotifier,
        builder: (_, _, _) {
          return TextSelectionTheme(
            data: TextSelectionThemeData(
              selectionColor: textColor.withAlpha(50),
              cursorColor: textColor,
            ),
            child: TextField(
              controller: textController,
              style: TextStyle(fontSize: 14, color: textColor),

              decoration: SearchInputDecoration(
                hint: Text(
                  hintText,
                  style: TextStyle(fontSize: 14, color: textColor),
                ),

                contentPadding: EdgeInsets.all(0),
                prefixIcon: Icon(Icons.search, color: iconColor),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: displayCancelNotifier,
                  builder: (context, value, child) {
                    return value
                        ? IconButton(
                            onPressed: () {
                              textController!.clear();
                              onChanged!('');
                            },
                            icon: Icon(Icons.close, size: 20, color: iconColor),
                          )
                        : SizedBox.shrink();
                  },
                ),
                filled: true,
                fillColor: searchFieldColor,
                hoverColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: onChanged,
            ),
          );
        },
      ),
    ),
  );
}

class TitleBar extends StatelessWidget {
  final bool isMainPage;

  final Widget? searchField;
  final displayCancelNotifier = ValueNotifier(false);

  TitleBar({super.key, this.isMainPage = true, this.searchField});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
      builder: (_, _, _) {
        return SizedBox(
          height: 75,
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) => windowManager.startDragging(),
                onDoubleTap: () async {
                  if (isFullScreenNotifier.value) {
                    return;
                  }
                  isMaximizedNotifier.value
                      ? windowManager.unmaximize()
                      : windowManager.maximize();
                },
                child: Container(),
              ),

              Center(
                child: Row(
                  children: [
                    SizedBox(width: 30),

                    if (isMainPage)
                      IconButton(
                        color: iconColor,
                        onPressed: () {
                          panelManager.popPanel();
                        },
                        icon: Icon(Icons.arrow_back_ios_rounded, size: 20),
                      )
                    else
                      ValueListenableBuilder(
                        valueListenable: isFullScreenNotifier,
                        builder: (context, isFullScreen, child) {
                          return isFullScreen
                              ? SizedBox.shrink()
                              : IconButton(
                                  color: Colors.grey.shade50,
                                  onPressed: () {
                                    displayLyricsPageNotifier.value = false;
                                  },
                                  icon: ImageIcon(arrowDownImage),
                                );
                        },
                      ),
                    if (isMainPage) SizedBox(width: 10),
                    if (isMainPage) SizedBox(child: searchField),

                    if (!isMainPage)
                      IconButton(
                        color: Colors.grey.shade50,
                        onPressed: () async {
                          if (isFullScreenNotifier.value) {
                            await windowManager.setFullScreen(false);
                            isFullScreenNotifier.value = false;
                          } else {
                            if (isMaximizedNotifier.value) {
                              if (context.mounted) {
                                showCenterMessage(
                                  context,
                                  'Enter fullscreen with maximized window will cause bug',
                                  duration: 3000,
                                );
                              }
                              return;
                            }
                            await windowManager.setFullScreen(true);
                            isFullScreenNotifier.value = true;
                          }
                        },
                        icon: ValueListenableBuilder(
                          valueListenable: isFullScreenNotifier,
                          builder: (context, isFullScreen, child) {
                            return ImageIcon(
                              isFullScreen
                                  ? fullscreenExitImage
                                  : fullscreenImage,
                            );
                          },
                        ),
                      ),

                    Spacer(),

                    if (isMainPage)
                      IconButton(
                        color: iconColor,
                        onPressed: () {
                          panelManager.pushPanel('settings');
                        },
                        icon: Icon(Icons.settings_outlined, size: 20),
                      ),

                    windowControls(),

                    SizedBox(width: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget windowControls() {
    return ValueListenableBuilder(
      valueListenable: isFullScreenNotifier,
      builder: (context, isFullScreen, child) {
        return isFullScreen
            ? SizedBox.shrink()
            : Row(
                children: [
                  IconButton(
                    color: isMainPage ? iconColor : Colors.grey.shade50,
                    onPressed: () async {
                      await windowManager.hide();
                      miniModeNotifier.value = true;

                      await Future.delayed(Duration(milliseconds: 200));

                      if (Platform.isWindows) {
                        await windowManager.setMinimumSize(
                          Size(325 + 16, 150 + 9),
                        );
                        await windowManager.setMaximumSize(
                          Size(600 + 16, 950 + 9),
                        );
                        await windowManager.setSize(Size(325 + 16, 325 + 9));
                      } else {
                        await windowManager.setMinimumSize(Size(325, 150));
                        await windowManager.setMaximumSize(Size(600, 950));
                        await windowManager.setSize(Size(325, 325));
                      }
                      await windowManager.show();
                    },
                    icon: ImageIcon(miniModeImage),
                  ),
                  IconButton(
                    color: isMainPage ? iconColor : Colors.grey.shade50,
                    onPressed: () {
                      windowManager.minimize();
                    },
                    icon: ImageIcon(minimizeImage),
                  ),
                  ValueListenableBuilder(
                    valueListenable: isMaximizedNotifier,
                    builder: (context, value, child) {
                      return IconButton(
                        color: isMainPage ? iconColor : Colors.grey.shade50,
                        onPressed: () async {
                          isMaximizedNotifier.value
                              ? windowManager.unmaximize()
                              : windowManager.maximize();
                        },
                        icon: ImageIcon(
                          value ? unmaximizeImage : maximizeImage,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    color: isMainPage ? iconColor : Colors.grey.shade50,
                    onPressed: () {
                      windowManager.close();
                    },
                    icon: ImageIcon(closeImage),
                  ),
                ],
              );
      },
    );
  }
}
