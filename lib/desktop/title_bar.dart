import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/keyboard.dart';
import 'package:particle_music/desktop/lyrics_page.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:searchfield/searchfield.dart';
import 'package:window_manager/window_manager.dart';

ValueNotifier<bool> isMaximizedNotifier = ValueNotifier(false);
ValueNotifier<bool> isFullScreenNotifier = ValueNotifier(false);

class MyWindowListener extends WindowListener {
  @override
  void onWindowMaximize() {
    isMaximizedNotifier.value = true;
  }

  @override
  void onWindowUnmaximize() {
    isMaximizedNotifier.value = false;
  }
}

class TitleBar extends StatelessWidget {
  final bool isMainPage;
  final TextEditingController? textController;
  final Function(String)? onChanged;

  final textFieldFocusNode = FocusNode();

  TitleBar({
    super.key,
    this.isMainPage = true,
    this.textController,
    this.onChanged,
  }) {
    textFieldFocusNode.addListener(() {
      if (!textFieldFocusNode.hasFocus) {
        appFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
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

          if (isMainPage)
            Center(
              child: SizedBox(
                width: 350,
                child: TextField(
                  focusNode: textFieldFocusNode,
                  controller: textController,
                  decoration: SearchInputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),

                    filled: true,
                    fillColor: Color.fromARGB(255, 215, 225, 235),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => onChanged!(value),
                ),
              ),
            ),

          Center(
            child: Row(
              children: [
                SizedBox(width: 30),

                if (isMainPage)
                  IconButton(
                    onPressed: () {
                      planeManager.popPlane();
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.black54,
                    ),
                  )
                else
                  ValueListenableBuilder(
                    valueListenable: isFullScreenNotifier,
                    builder: (context, isFullScreen, child) {
                      return isFullScreen
                          ? SizedBox.shrink()
                          : IconButton(
                              onPressed: () {
                                displayLyricsPageNotifier.value = false;
                              },
                              icon: ImageIcon(
                                arrowDownImage,
                                color: Colors.black54,
                              ),
                            );
                    },
                  ),

                if (!isMainPage)
                  IconButton(
                    onPressed: () async {
                      if (isFullScreenNotifier.value) {
                        await windowManager.setFullScreen(false);
                        isFullScreenNotifier.value = false;
                      } else {
                        if (isMaximizedNotifier.value) {
                          if (context.mounted) {
                            showCenterMessage(
                              context,
                              'enter fullscreen with maximized window will cause bug',
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
                        return isFullScreen
                            ? ImageIcon(
                                fullscreenExitImage,
                                color: Colors.black54,
                              )
                            : ImageIcon(fullscreenImage, color: Colors.black54);
                      },
                    ),
                  ),

                Spacer(),

                ValueListenableBuilder(
                  valueListenable: isFullScreenNotifier,
                  builder: (context, isFullScreen, child) {
                    return isFullScreen
                        ? SizedBox.shrink()
                        : Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  windowManager.minimize();
                                },
                                icon: ImageIcon(
                                  minimizeImage,
                                  color: Colors.black54,
                                ),
                              ),
                              ValueListenableBuilder(
                                valueListenable: isMaximizedNotifier,
                                builder: (context, value, child) {
                                  return IconButton(
                                    onPressed: () async {
                                      isMaximizedNotifier.value
                                          ? windowManager.unmaximize()
                                          : windowManager.maximize();
                                    },
                                    icon: value
                                        ? ImageIcon(
                                            unmaximizeImage,
                                            color: Colors.black54,
                                          )
                                        : ImageIcon(
                                            maximizeImage,
                                            color: Colors.black54,
                                          ),
                                  );
                                },
                              ),
                              IconButton(
                                onPressed: () {
                                  windowManager.close();
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          );
                  },
                ),

                SizedBox(width: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
