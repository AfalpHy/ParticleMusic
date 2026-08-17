import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/utils/media_query.dart';

Widget myNavigator({
  required Key key,
  required ValueNotifier visibleNotifier,
  required Widget Function() pageViewBuilder,
  required Widget Function() panelViewBuilder,
}) {
  return Navigator(
    key: key,
    observers: [HeroController()],
    pages: [
      if (Platform.isAndroid) MaterialPage(child: SizedBox.shrink()),
      MaterialPage(
        child: Builder(
          builder: (context) {
            return isTooNarrow(context)
                ? pageViewBuilder()
                : ValueListenableBuilder(
                    valueListenable: visibleNotifier,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value ? 1 : 0,
                        child: panelViewBuilder(),
                      );
                    },
                  );
          },
        ),
      ),
    ],
    onDidRemovePage: (page) {},
  );
}
