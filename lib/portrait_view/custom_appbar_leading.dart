import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

Widget customAppBarLeading(BuildContext context, {String label = ''}) {
  return ValueListenableBuilder(
    valueListenable: endDrawerNotifier,
    builder: (context, value, child) {
      return IconButton(
        icon: Icon(
          label.isEmpty ? Icons.menu_rounded : Icons.arrow_back_ios_new_rounded,
        ),
        onPressed: () => label.isEmpty
            ? value
                  ? portraitKey.currentState?.openEndDrawer()
                  : portraitKey.currentState?.openDrawer()
            : layersManager.popDetail(label),
      );
    },
  );
}
