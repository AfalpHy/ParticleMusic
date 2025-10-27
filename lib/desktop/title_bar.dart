import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

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
            onDoubleTap: () async => await windowManager.isMaximized()
                ? windowManager.unmaximize()
                : windowManager.maximize(),
            child: Container(),
          ),
          Center(
            child: Row(
              children: [
                Spacer(),

                IconButton(
                  onPressed: () {
                    windowManager.minimize();
                  },
                  icon: ImageIcon(minimizeImage, color: Colors.black54),
                ),
                IconButton(
                  onPressed: () async {
                    await windowManager.isMaximized()
                        ? windowManager.unmaximize()
                        : windowManager.maximize();
                  },
                  icon: ImageIcon(maximizeImage, color: Colors.black54),
                ),

                IconButton(
                  onPressed: () {
                    windowManager.close();
                  },
                  icon: Icon(Icons.close_rounded, color: Colors.black54),
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
