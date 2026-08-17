import 'package:material_ui/material_ui.dart';

bool isTooNarrow(BuildContext context) {
  return MediaQuery.widthOf(context) < 800;
}

double getTopOffset(BuildContext context) {
  final topPadding = MediaQuery.of(context).padding.top;
  if (topPadding >= 20) {
    return topPadding - 20;
  }
  return 0;
}
