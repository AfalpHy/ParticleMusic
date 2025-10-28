import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:searchfield/searchfield.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatelessWidget {
  final bool isMainPage;
  final TextEditingController? textController;
  final Function(String)? onChanged;
  const TitleBar({
    super.key,
    this.isMainPage = true,
    this.textController,
    this.onChanged,
  });

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
          if (isMainPage)
            Center(
              child: SizedBox(
                width: 350,
                child: TextField(
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
          if (isMainPage)
            Center(
              child: Row(
                children: [
                  SizedBox(width: 30),
                  IconButton(
                    onPressed: () {
                      planeManager.popPlane();
                    },
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.black54,
                    ),
                  ),
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
